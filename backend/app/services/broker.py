import asyncio
from typing import Any
from neo_api_client import NeoAPI
from neo_api_client.websocket.feed import WsToken
from app.core.config import settings
from app.services.market_pipeline import candles
from app.services.lifecycle import signal_lifecycle
from app.services.execution import execution_engine
from app.services.risk import risk_engine
from app.services.positions import position_manager
from app.services.journal import journal
from app.services.signal_engine import signal_engine

class BrokerService:
    def __init__(self) -> None:
        self.client: NeoAPI | None = None
        self.authenticated = False
        self.market_ws = None
        self.market_task: asyncio.Task | None = None
        self.order_task: asyncio.Task | None = None
        self.latest_ticks: dict[str, dict[str, Any]] = {}
        self.subscriptions: dict[str, tuple[str, str, str]] = {}
        self.listeners: set[asyncio.Queue] = set()
        self.last_market_message_at: float | None = None
        self.last_order_message_at: float | None = None
        self._lock = asyncio.Lock()
        self.symbol_aliases: dict[str, str] = {}
        self.signal_scan_keys: set[str] = set()
        self.core_signal_keys: set[str] = {"nse_cm|Nifty 50", "nse_cm|Nifty Bank", "bse_cm|Sensex"}
        self._last_ui_market_emit: dict[str, float] = {}
        self._last_option_retry: dict[str, float] = {}
        # Stable signal key -> tradable broker contract metadata. Populated by scanner resolution.
        self.signal_trade_meta: dict[str, dict[str, str]] = {}

    def _ensure_client(self) -> NeoAPI:
        if not settings.kotak_consumer_key:
            raise RuntimeError("KOTAK_CONSUMER_KEY is not configured")
        if self.client is None:
            self.client = NeoAPI(consumer_key=settings.kotak_consumer_key, environment="prod")
        return self.client

    async def login(self, totp: str) -> dict[str, Any]:
        client = self._ensure_client()
        login = await asyncio.to_thread(client.totp_login, settings.kotak_mobile_number, settings.kotak_ucc, totp)
        if "error" in login or "Error" in login:
            return {"ok": False, "step": "totp_login", "response": login}
        validate = await asyncio.to_thread(client.totp_validate, settings.kotak_mpin)
        if "error" in validate or "Error" in validate:
            return {"ok": False, "step": "totp_validate", "response": validate}
        self.authenticated = True
        journal.add("auth", "login", {"ok": True})
        return {"ok": True, "step": "authenticated"}


    async def logout(self):
        self.authenticated = False
        for task in (self.market_task, self.order_task):
            if task and not task.done(): task.cancel()
        self.market_task = None; self.order_task = None; self.market_ws = None
        try:
            if self.client is not None and hasattr(self.client, "logout"):
                result = await asyncio.to_thread(self.client.logout)
            else:
                result = {"ok": True}
        except Exception as exc:
            result = {"ok": False, "error": str(exc)}
        journal.add("auth", "logout", result)
        return {"ok": True, "broker": result}

    async def start_streams(self) -> None:
        if not self.authenticated or self.client is None:
            raise RuntimeError("Kotak session is not authenticated")
        async with self._lock:
            if not self.market_task or self.market_task.done():
                self.market_task = asyncio.create_task(self._market_loop(), name="kotak-market-feed")
            if not self.order_task or self.order_task.done():
                self.order_task = asyncio.create_task(self._order_loop(), name="kotak-order-feed")

    async def _market_loop(self) -> None:
        assert self.client is not None
        import time
        while self.authenticated:
            try:
                async with self.client.create_websocket(
                    reconnect_delay=2,
                    max_reconnect_attempts=20,
                    max_connect_retries=5,
                    ping_interval=20,
                ) as ws:
                    self.market_ws = ws
                    await self._resubscribe_all(ws)
                    async for msg in ws:
                        self.last_market_message_at = time.time()
                        payload = msg.model_dump() if hasattr(msg, "model_dump") else {"value": str(msg)}
                        token = payload.get("instrument_token")
                        segment = payload.get("exchange_segment")

                        if payload.get("type") == "index" and payload.get("name"):
                            index_name = str(payload.get("name"))
                            index_alias = {
                                "Nifty 50": "Nifty 50",
                                "Nifty Bank": "Nifty Bank",
                                "SENSEX": "Sensex",
                            }.get(index_name, index_name)
                            key = f"{segment}|{index_alias}"
                        else:
                            raw_key = f"{segment}|{token}" if token is not None else f"market|{payload.get('type','event')}"
                            key = self.symbol_aliases.get(raw_key, raw_key)
                        self.latest_ticks[key] = payload
                        ltp = payload.get("last_traded_price")
                        event_ts = payload.get("last_trade_time") or payload.get("last_update_time") or int(time.time())
                        day_volume = payload.get("volume_traded_today")
                        if token is not None and ltp is not None and event_ts:
                            try:
                                price = float(ltp)
                                changed_positions = position_manager.on_tick(str(segment), str(token), price)
                                for pos in changed_positions:
                                    await self._broadcast({"channel": "positions", "event": "mtm", "data": pos})
                                    exit_events = await position_manager.evaluate_exit_plans(pos["key"], price, submitter=self.place_order_protected)
                                    for evt in exit_events:
                                        await self._broadcast({"channel": "exit_plan", "event": evt.get("state", "updated"), "data": evt})
                                closed = candles.ingest(key, price, int(event_ts), int(day_volume) if day_volume is not None else None)
                                for candle in closed:
                                    await self._broadcast({"channel": "candle", "data": candle.to_dict()})

                                    # Auto-evaluate strict strategy on each CLOSED 5M candle.
                                    # Core indices are always eligible; stocks only when their selected 45-stock group is active.
                                    if candle.timeframe_sec == 300 and (key in self.core_signal_keys or key in self.signal_scan_keys):
                                        rows = candles.get_history(key, 300, 100)

                                        # get_history includes the newly forming candle. Remove it.
                                        if rows:
                                            rows = rows[:-1]

                                        result = signal_engine.evaluate_strongest(
                                            key, rows,
                                            rows_1m=candles.get_history(key, 60, 100)[:-1],
                                            rows_15m=candles.get_history(key, 900, 100)[:-1],
                                            rows_4h=candles.get_history(key, 14400, 30)[:-1],
                                            rows_1d=candles.get_history(key, 86400, 15)[:-1],
                                        )

                                        await self._broadcast({
                                            "channel": "signal_scan",
                                            "symbol_key": key,
                                            "data": result,
                                        })

                                        if result.get("status") == "SIGNAL":
                                            signal = result["signal"]
                                            # Cooldown avoids repeating essentially the same setup every 5 minutes.
                                            if not signal_lifecycle.has_recent(key, str(signal.get("side")), 900):
                                                trade_meta = dict(self.signal_trade_meta.get(key, {}))
                                                option_meta: dict[str, Any] = {}
                                                is_index = key in self.core_signal_keys
                                                if is_index:
                                                    # Index analysis is not tradable until a real option contract is resolved.
                                                    # Resolve from the broker, quote it live and enforce OI/Greeks/liquidity quality.
                                                    try:
                                                        from app.services.instruments import instruments
                                                        opt = await instruments.auto_select_index_option(
                                                            symbol_key=key, side=str(signal["side"]), underlying_ltp=price
                                                        )
                                                        selected = opt.get("selected") if isinstance(opt, dict) else None
                                                        if opt.get("status") == "READY" and isinstance(selected, dict):
                                                            trade_meta = {
                                                                "trading_symbol": selected.get("trading_symbol"),
                                                                "exchange_segment": selected.get("exchange_segment"),
                                                                "instrument_token": selected.get("instrument_token"),
                                                            }
                                                            option_meta = {
                                                                "trade_ready": True,
                                                                "option_status": "READY",
                                                                "requires_tradable_contract": True,
                                                                "underlying_symbol": opt.get("underlying"),
                                                                "option_type": selected.get("option_type"),
                                                                "strike": selected.get("strike"),
                                                                "expiry": selected.get("expiry") or opt.get("expiry"),
                                                                "option_ltp": selected.get("ltp"),
                                                                "option_bid": selected.get("bid"),
                                                                "option_ask": selected.get("ask"),
                                                                "option_volume": selected.get("volume"),
                                                                "option_oi": selected.get("oi"),
                                                                "option_oi_change": selected.get("oi_change"),
                                                                "option_iv": selected.get("iv"),
                                                                "option_delta": selected.get("delta"),
                                                                "option_gamma": selected.get("gamma"),
                                                                "option_theta": selected.get("theta"),
                                                                "option_vega": selected.get("vega"),
                                                                "option_quality_score": selected.get("score"),
                                                                "option_lot_size": selected.get("lot_size"),
                                                            }
                                                            # Subscribe the exact selected option so live quote state can recover after reconnect.
                                                            try:
                                                                await self.subscribe(str(trade_meta["exchange_segment"]), str(trade_meta["instrument_token"]), "scrip")
                                                            except Exception:
                                                                pass
                                                        else:
                                                            option_meta = {
                                                                "trade_ready": False,
                                                                "option_status": str(opt.get("reason") or "OPTION_DATA_UNAVAILABLE"),
                                                                "requires_tradable_contract": True,
                                                                "underlying_symbol": opt.get("underlying"),
                                                                "option_type": opt.get("option_type"),
                                                                "expiry": opt.get("expiry"),
                                                            }
                                                            trade_meta = {}
                                                    except Exception as exc:
                                                        option_meta = {
                                                            "trade_ready": False,
                                                            "option_status": f"OPTION_RESOLVE_ERROR: {exc}",
                                                            "requires_tradable_contract": True,
                                                        }
                                                        trade_meta = {}
                                                else:
                                                    option_meta = {"trade_ready": bool(trade_meta.get("trading_symbol"))}

                                                tracked = signal_lifecycle.create(
                                                    symbol_key=key,
                                                    side=str(signal["side"]),
                                                    entry=float(signal["entry"]),
                                                    stop=float(signal["stop"]),
                                                    target1=float(signal["target1"]),
                                                    target2=float(signal["target2"]),
                                                    target3=float(signal.get("target3")) if signal.get("target3") is not None else None,
                                                    score=int(signal.get("score") or 0),
                                                    rr=float(signal.get("rr") or 0),
                                                    reason=str(signal.get("reason") or ""),
                                                    timeframe_sec=int(signal.get("timeframe_sec") or 300),
                                                    rsi14=float(signal.get("rsi14")) if signal.get("rsi14") is not None else None,
                                                    williams_r14=float(signal.get("williams_r14")) if signal.get("williams_r14") is not None else None,
                                                    trading_symbol=trade_meta.get("trading_symbol"),
                                                    exchange_segment=trade_meta.get("exchange_segment"),
                                                    instrument_token=trade_meta.get("instrument_token"),
                                                    generated_candle_at=float(getattr(candle, "start_ts", 0) or 0) or None,
                                                    **option_meta,
                                                )
                                                await self._broadcast({
                                                    "channel": "signal",
                                                    "event": "new",
                                                    "data": tracked,
                                                })
                                for tracked in list(signal_lifecycle.items.values()):
                                    if tracked.symbol_key == key:
                                        before = tracked.state.value
                                        updated = signal_lifecycle.update_price(tracked.id, price)
                                        if updated["state"] != before:
                                            await self._broadcast({"channel": "signal_lifecycle", "event": "state_changed", "data": updated})

                                        # A transient broker-search/quote failure must not leave an index
                                        # signal stuck in OPTION WAIT for its entire life. Retry unresolved
                                        # NIFTY/BANKNIFTY/SENSEX contracts at a controlled cadence.
                                        if key in self.core_signal_keys and not tracked.trade_ready and tracked.state.value in {"WATCHING","ACTIVE","ENTRY","T1"}:
                                            retry_now=time.time()
                                            if retry_now-self._last_option_retry.get(tracked.id,0.0) >= 30.0:
                                                self._last_option_retry[tracked.id]=retry_now
                                                try:
                                                    from app.services.instruments import instruments
                                                    opt=await instruments.auto_select_index_option(symbol_key=key,side=tracked.side,underlying_ltp=price)
                                                    selected=opt.get("selected") if isinstance(opt,dict) else None
                                                    if opt.get("status")=="READY" and isinstance(selected,dict):
                                                        tracked.trading_symbol=selected.get("trading_symbol")
                                                        tracked.exchange_segment=selected.get("exchange_segment")
                                                        tracked.instrument_token=selected.get("instrument_token")
                                                        tracked.trade_ready=True; tracked.option_status="READY"
                                                        tracked.underlying_symbol=opt.get("underlying"); tracked.option_type=selected.get("option_type")
                                                        tracked.strike=selected.get("strike"); tracked.expiry=selected.get("expiry") or opt.get("expiry")
                                                        tracked.option_ltp=selected.get("ltp"); tracked.option_bid=selected.get("bid"); tracked.option_ask=selected.get("ask")
                                                        tracked.option_volume=selected.get("volume"); tracked.option_oi=selected.get("oi"); tracked.option_oi_change=selected.get("oi_change")
                                                        tracked.option_iv=selected.get("iv"); tracked.option_delta=selected.get("delta"); tracked.option_gamma=selected.get("gamma")
                                                        tracked.option_theta=selected.get("theta"); tracked.option_vega=selected.get("vega")
                                                        tracked.option_quality_score=selected.get("score"); tracked.option_lot_size=selected.get("lot_size")
                                                        tracked.updated_at=retry_now; signal_lifecycle._save(tracked)
                                                        try:
                                                            await self.subscribe(str(tracked.exchange_segment),str(tracked.instrument_token),"scrip")
                                                        except Exception:
                                                            pass
                                                        await self._broadcast({"channel":"signal","event":"option_ready","data":tracked.to_dict()})
                                                    else:
                                                        tracked.option_status=str(opt.get("reason") or "OPTION_DATA_UNAVAILABLE")
                                                        tracked.updated_at=retry_now; signal_lifecycle._save(tracked)
                                                except Exception as exc:
                                                    tracked.option_status=f"OPTION_RETRY_ERROR: {exc}"
                                                    tracked.updated_at=retry_now; signal_lifecycle._save(tracked)
                            except (TypeError, ValueError):
                                pass
                        # Scanner feeds can produce hundreds of UI messages per second. The backend still
                        # processes every tick, but the phone only needs the three index pulses. Throttle
                        # those to keep the app websocket stable on mobile networks.
                        if key in self.core_signal_keys:
                            now_ui = time.time()
                            if now_ui - self._last_ui_market_emit.get(key, 0.0) >= 0.50:
                                self._last_ui_market_emit[key] = now_ui
                                await self._broadcast({"channel": "market", "symbol_key": key, "data": payload})
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                await self._broadcast({"channel": "system", "event": "market_feed_error", "error": str(exc)})
                await asyncio.sleep(2)

    async def _order_loop(self) -> None:
        assert self.client is not None
        import time
        while self.authenticated:
            try:
                async with self.client.create_order_feed(
                    reconnect_delay=2,
                    max_reconnect_attempts=20,
                    max_connect_retries=5,
                    ping_interval=20,
                ) as feed:
                    async for msg in feed:
                        self.last_order_message_at = time.time()
                        payload = msg.model_dump() if hasattr(msg, "model_dump") else {"value": str(msg)}
                        reconciled = execution_engine.on_order_update(payload)
                        position_update = position_manager.on_position_update(payload) if payload.get("type") == "position" else None
                        journal.add("broker", "order_update", payload, str(payload.get("order_id") or payload.get("nOrdNo") or "") or None)
                        await self._broadcast({"channel": "orders", "data": payload})
                        if position_update is not None:
                            await self._broadcast({"channel": "positions", "event": "position_update", "data": position_update})
                        if reconciled is not None:
                            await self._broadcast({"channel": "execution", "event": "state_changed", "data": reconciled})
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                await self._broadcast({"channel": "system", "event": "order_feed_error", "error": str(exc)})
                await asyncio.sleep(2)


    async def recycle_market_stream(self) -> None:
        """Reconnect only the market websocket so removed scanner subscriptions truly stop consuming feed data."""
        async with self._lock:
            task = self.market_task
            if task and not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
                except Exception:
                    pass
            self.market_task = None
            self.market_ws = None
            if self.authenticated:
                self.market_task = asyncio.create_task(self._market_loop(), name="kotak-market-feed")

    async def subscribe(self, exchange_segment: str, instrument_token: str, mode: str = "scrip") -> None:
        key = f"{exchange_segment}|{instrument_token}|{mode}"
        self.subscriptions[key] = (exchange_segment, instrument_token, mode)
        if self.market_ws and self.market_ws.is_connected:
            await self._apply_subscription(self.market_ws, exchange_segment, instrument_token, mode)

    async def _resubscribe_all(self, ws) -> None:
        for segment, token, mode in list(self.subscriptions.values()):
            await self._apply_subscription(ws, segment, token, mode)

    @staticmethod
    async def _apply_subscription(ws, segment: str, token: str, mode: str) -> None:
        tokens = [WsToken(segment, token)]
        fn = {
            "scrip": ws.subscribe_scrips,
            "lite": ws.subscribe_scrips_lite,
            "depth": ws.subscribe_depth,
            "full_depth": ws.subscribe_full_depth,
            "index": ws.subscribe_index,
        }[mode]
        await fn(tokens)

    async def _broadcast(self, payload: dict[str, Any]) -> None:
        dead = []
        for q in self.listeners:
            try:
                if q.full():
                    _ = q.get_nowait()  # drop oldest UI update; never block broker feed
                q.put_nowait(payload)
            except Exception:
                dead.append(q)
        for q in dead:
            self.listeners.discard(q)

    def new_listener(self) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue(maxsize=250)
        self.listeners.add(q)
        return q

    def remove_listener(self, q: asyncio.Queue) -> None:
        self.listeners.discard(q)


    def _guard_session_response(self, payload: Any) -> Any:
        """Normalize broker invalid-session replies into one predictable failure path."""
        try:
            text=str(payload).lower()
        except Exception:
            text=''
        if 'invalid session token' in text or 'neo-login-check-api' in text or "'code': 401" in text or '"code": 401' in text:
            self.authenticated=False
            raise RuntimeError('KOTAK_SESSION_EXPIRED')
        return payload

    async def quote(self, exchange_segment: str, instrument_token: str, quote_type: str = "all"):
        client = self._ensure_client()
        return self._guard_session_response(await asyncio.to_thread(client.quotes, [{"instrument_token": instrument_token, "exchange_segment": exchange_segment}], quote_type))

    async def search(self, exchange_segment: str, symbol: str):
        client = self._ensure_client()
        return await asyncio.to_thread(client.search_scrip, exchange_segment, symbol)

    async def positions(self):
        return self._guard_session_response(await asyncio.to_thread(self._ensure_client().positions))

    async def holdings(self):
        return self._guard_session_response(await asyncio.to_thread(self._ensure_client().holdings))

    async def holdings_enriched(self):
        """Return production-safe holdings with live LTP where the broker exposes a token.

        Missing quote data remains null; it is never converted into a fake zero/-100% portfolio loss.
        """
        raw = await self.holdings()

        def walk(x):
            out=[]
            if isinstance(x, dict):
                keys={str(k) for k in x}
                if any(k in keys for k in ('trading_symbol','tradingSymbol','symbol','pTrdSymbol','displayName')) and any(k in keys for k in ('quantity','qty','net_quantity','netQty','holdingQty')):
                    out.append(x)
                for v in x.values(): out.extend(walk(v))
            elif isinstance(x, list):
                for v in x: out.extend(walk(v))
            return out

        def pick(d, *names):
            for n in names:
                if n in d and d[n] not in (None, ''): return d[n]
            return None

        def num(v):
            try: return float(v) if v not in (None, '') else None
            except Exception: return None

        rows=[]
        for rec in walk(raw):
            symbol=str(pick(rec,'trading_symbol','tradingSymbol','symbol','pTrdSymbol','displayName') or '--')
            qty=num(pick(rec,'quantity','qty','net_quantity','netQty','holdingQty')) or 0.0
            avg=num(pick(rec,'average_price','averagePrice','avgPrice','buy_avg','buyAvg'))
            token=pick(rec,'instrument_token','instrumentToken','token','pSymbol','p_symbol')
            segment=str(pick(rec,'exchange_segment','exchangeSegment','segment','pExchSeg') or 'nse_cm')
            segkey=segment.strip().lower().replace('-','_')
            segment={'nse':'nse_cm','nsecm':'nse_cm','nse_cm':'nse_cm','bse':'bse_cm','bsecm':'bse_cm','bse_cm':'bse_cm'}.get(segkey,segment)
            ltp=num(pick(rec,'ltp','last_traded_price','lastPrice','closing_price','closePrice'))
            quote_error=None
            quote_source='HOLDING' if ltp is not None and ltp > 0 else None
            # Holdings responses are not consistent across Neo SDK versions. If token is absent,
            # resolve the exact cash instrument by trading symbol before giving up.
            if (ltp is None or ltp <= 0) and not token and symbol and symbol != '--':
                try:
                    search_payload=await self.search(segment, symbol)
                    from app.services.options import flatten_records
                    search_rows=flatten_records(search_payload)
                    exact=None
                    target=symbol.upper().replace(' ','')
                    for sr in search_rows:
                        sr_sym=str(pick(sr,'trading_symbol','tradingSymbol','symbol','pTrdSymbol','p_trd_symbol') or '').upper().replace(' ','')
                        if sr_sym == target or sr_sym.startswith(target):
                            exact=sr; break
                    if exact is None and search_rows: exact=search_rows[0]
                    if exact:
                        token=pick(exact,'instrument_token','instrumentToken','token','pSymbol','p_symbol') or token
                        segment=str(pick(exact,'exchange_segment','exchangeSegment','segment','pExchSeg') or segment)
                except Exception as exc:
                    quote_error=f'search: {exc}'
            if (ltp is None or ltp <= 0) and token:
                try:
                    q=await self.quote(segment,str(token),'all')
                    from app.services.options import flatten_records
                    qr=flatten_records(q)
                    if qr:
                        q0=qr[0]
                        ltp=num(pick(q0,'last_traded_price','ltp','lastPrice','last_price','lp','lastTradedPrice','pLTP','pLastTradedPrice','close_price'))
                        if ltp is not None and ltp > 0: quote_source='LIVE_QUOTE'
                except Exception as exc:
                    quote_error=(quote_error+'; ' if quote_error else '')+str(exc)
            # Last-resort display value: broker-provided close is marked explicitly, never called LIVE.
            if ltp is None or ltp <= 0:
                close=num(pick(rec,'closing_price','closePrice','close_price','previous_close','previousClose'))
                if close is not None and close > 0:
                    ltp=close; quote_source='PREV_CLOSE' 
            invested=(qty*avg) if avg is not None and qty else None
            current=(qty*ltp) if ltp is not None and ltp>0 and qty else None
            pnl=(current-invested) if current is not None and invested is not None else None
            pnl_pct=(pnl/invested*100.0) if pnl is not None and invested not in (None,0) else None
            rows.append({
                'symbol':symbol,'quantity':qty,'average_price':avg,'ltp':ltp if ltp and ltp>0 else None,
                'invested_value':invested,'current_value':current,'pnl':pnl,'pnl_pct':pnl_pct,
                'exchange_segment':segment,'instrument_token':str(token) if token is not None else None,
                'quote_status':('LIVE' if quote_source in ('LIVE_QUOTE','HOLDING') else ('PREV_CLOSE' if quote_source=='PREV_CLOSE' else 'PRICE_UNAVAILABLE')),'quote_source':quote_source,'quote_error':quote_error,
            })
        valid=[r for r in rows if r['current_value'] is not None and r['invested_value'] is not None]
        total_invested=sum(r['invested_value'] for r in valid) if valid else None
        total_current=sum(r['current_value'] for r in valid) if valid else None
        total_pnl=(total_current-total_invested) if total_current is not None and total_invested is not None else None
        total_pct=(total_pnl/total_invested*100.0) if total_pnl is not None and total_invested else None
        return {
            'holdings':rows,
            'summary':{'count':len(rows),'priced_count':len(valid),'unpriced_count':len(rows)-len(valid),
                       'total_invested':total_invested,'total_current':total_current,'total_pnl':total_pnl,'total_pnl_pct':total_pct},
        }

    async def limits(self):
        return self._guard_session_response(await asyncio.to_thread(self._ensure_client().limits))

    async def orders(self):
        return self._guard_session_response(await asyncio.to_thread(self._ensure_client().order_report))

    async def order_by_id(self, order_id: str):
        return await asyncio.to_thread(self._ensure_client().order_report, order_id)

    async def cancel_order(self, order_id: str, amo: str = "NO"):
        return await asyncio.to_thread(self._ensure_client().cancel_order, order_id, amo)

    async def modify_order(self, **kwargs):
        return await asyncio.to_thread(self._ensure_client().modify_order, **kwargs)

    async def place_order(self, **kwargs):
        if not settings.live_orders_unlocked:
            raise RuntimeError("LIVE_ORDER_SUBMISSION_LOCKED")
        return await asyncio.to_thread(self._ensure_client().place_order, **kwargs)

    async def place_order_protected(self, **kwargs):
        """Used by automatic exits; unlike a confirmed intent there is no UI token at trigger time."""
        if not risk_engine.config.trading_enabled:
            raise RuntimeError("TRADING_DISABLED")
        if not execution_engine.armed:
            raise RuntimeError("EXECUTION_NOT_ARMED")
        return await self.place_order(**kwargs)

broker = BrokerService()
