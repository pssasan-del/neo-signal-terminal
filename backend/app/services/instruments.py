from __future__ import annotations
import asyncio, time
from typing import Any
from app.services.broker import broker
from app.services.recovery import recovery_store


class InstrumentResolver:
    def __init__(self, ttl_sec: int = 900) -> None:
        self.ttl_sec = ttl_sec
        self.cache: dict[str, tuple[float, Any]] = {}
        self.core_indices: list[dict[str, Any]] = recovery_store.snapshot().get("core_indices", [])

    async def search(self, exchange_segment: str, symbol: str, expiry: str | None = None,
                     option_type: str | None = None, strike_price: str | None = None,
                     ignore_50multiple: bool = False) -> Any:
        key = "|".join(str(x or "") for x in (exchange_segment, symbol.upper(), expiry, option_type, strike_price, ignore_50multiple))
        item = self.cache.get(key)
        if item and time.time() - item[0] < self.ttl_sec:
            return {"cached": True, "data": item[1]}
        client = broker._ensure_client()
        data = await asyncio.to_thread(client.search_scrip, exchange_segment, symbol, expiry, option_type, strike_price, ignore_50multiple)
        self.cache[key] = (time.time(), data)
        try:
            from app.services.options import flatten_records
            for row in flatten_records(data):
                if isinstance(row, dict):
                    token = row.get("instrument_token") or row.get("instrumentToken") or row.get("token") or row.get("pSymbol") or row.get("p_symbol")
                    if token:
                        recovery_store.remember_instrument(f"{exchange_segment}|{token}", row)
        except Exception:
            pass
        return {"cached": False, "data": data}

    async def resolve_option(self, underlying: str, expiry: str, option_type: str, strike_price: float,
                             exchange_segment: str = "NSEFO") -> Any:
        return await self.search(exchange_segment, underlying, expiry, option_type.upper(), str(strike_price), False)

    async def scan_option_candidates(self, *, underlying: str, expiry: str, option_type: str,
                                     underlying_ltp: float, strike_step: float,
                                     strikes_each_side: int = 2, exchange_segment: str = "NSEFO") -> dict[str, Any]:
        """Search strikes around ATM, enrich with broker quotes, then rank quality."""
        from app.services.options import flatten_records, option_selector
        if underlying_ltp <= 0 or strike_step <= 0:
            return {"status": "REJECTED", "reason": "INVALID_PRICE_OR_STRIKE_STEP"}
        atm = round(underlying_ltp / strike_step) * strike_step
        strikes = [atm + i * strike_step for i in range(-max(0, strikes_each_side), max(0, strikes_each_side) + 1)]
        enriched: list[dict[str, Any]] = []
        for strike in strikes:
            sr = await self.resolve_option(underlying, expiry, option_type, strike, exchange_segment)
            records = flatten_records(sr.get("data", sr))
            for rec in records:
                token = rec.get("instrument_token") or rec.get("instrumentToken") or rec.get("token") or rec.get("pSymbol") or rec.get("p_symbol")
                if not token:
                    continue
                try:
                    quote = await broker.quote(exchange_segment, str(token), "all")
                    quote_records = flatten_records(quote)
                    qmatch = next((q for q in quote_records if str(q.get("instrument_token") or q.get("instrumentToken") or q.get("token") or q.get("pSymbol") or q.get("p_symbol") or "") == str(token)), None)
                    merged = dict(rec)
                    if qmatch:
                        merged.update(qmatch)
                    enriched.append(merged)
                except Exception:
                    enriched.append(dict(rec))
        ranked = option_selector.rank(enriched, underlying_ltp=underlying_ltp, option_type=option_type, fallback_segment=exchange_segment)
        accepted = [x for x in ranked if x["accepted"]]
        return {"status": "READY" if accepted else "REJECTED", "atm": atm, "strikes_checked": strikes,
                "selected": accepted[0] if accepted else None, "candidates": ranked[:20],
                "reason": None if accepted else "NO_QUALITY_OPTION"}



    async def auto_select_index_option(self, *, symbol_key: str, side: str, underlying_ltp: float) -> dict[str, Any]:
        """Resolve a live, tradable index option without requiring the UI to know expiry/token.

        Discovery is broker-driven: search the derivatives segment, identify the nearest non-expired
        expiry, quote the closest strikes, then apply the OI/Greeks/liquidity quality filter.
        No fabricated symbol or premium is returned.
        """
        from datetime import datetime, timezone
        from app.services.options import flatten_records, option_selector, _expiry_years

        key = symbol_key.upper().replace(' ', '')
        if 'BANK' in key:
            underlying, segment, strike_step = 'BANKNIFTY', 'NSEFO', 100.0
        elif 'SENSEX' in key:
            underlying, segment, strike_step = 'SENSEX', 'BSEFO', 100.0
        elif 'NIFTY' in key:
            underlying, segment, strike_step = 'NIFTY', 'NSEFO', 50.0
        else:
            return {'status':'REJECTED','reason':'NOT_INDEX_SIGNAL'}
        option_type = 'CE' if str(side).upper() == 'BUY' else 'PE'
        if underlying_ltp <= 0:
            return {'status':'REJECTED','reason':'INVALID_UNDERLYING_LTP'}

        # First request a broad broker search. Different Neo SDK releases expose expiry fields
        # under different keys; OptionSelector.normalize handles those aliases.
        try:
            raw = await self.search(segment, underlying)
        except Exception as exc:
            return {'status':'REJECTED','reason':'OPTION_DISCOVERY_FAILED','detail':str(exc)}
        records = flatten_records(raw.get('data', raw))
        candidates = []
        for rec in records:
            c = option_selector.normalize(rec, fallback_segment=segment, fallback_type=option_type)
            if c is None:
                continue
            typ = (c.option_type or '').upper()
            if typ and typ != option_type:
                continue
            if not c.expiry or _expiry_years(c.expiry) is None:
                continue
            candidates.append((c, rec))
        if not candidates:
            return {'status':'REJECTED','reason':'NO_OPTION_INSTRUMENTS_FROM_BROKER','underlying':underlying,'segment':segment}

        # _expiry_years is monotonic enough for selecting the nearest future expiry.
        candidates.sort(key=lambda t: (_expiry_years(t[0].expiry) or 999.0, abs(t[0].strike-underlying_ltp)))
        nearest_expiry = candidates[0][0].expiry
        expiry_rows = [(c,r) for c,r in candidates if c.expiry == nearest_expiry]
        atm = round(underlying_ltp / strike_step) * strike_step
        expiry_rows.sort(key=lambda t: abs(t[0].strike-atm))
        expiry_rows = expiry_rows[:8]

        enriched=[]
        for c, rec in expiry_rows:
            merged=dict(rec)
            try:
                q=await broker.quote(c.exchange_segment or segment, c.instrument_token, 'all')
                qr=flatten_records(q)
                match=next((x for x in qr if str(x.get('instrument_token') or x.get('instrumentToken') or x.get('token') or x.get('pSymbol') or x.get('p_symbol') or '')==str(c.instrument_token)), None)
                if match: merged.update(match)
            except Exception as exc:
                merged['_quote_error']=str(exc)
            enriched.append(merged)
        ranked=option_selector.rank(enriched, underlying_ltp=underlying_ltp, option_type=option_type, fallback_segment=segment)
        accepted=[x for x in ranked if x.get('accepted')]
        selected=accepted[0] if accepted else None
        return {
            'status':'READY' if selected else 'REJECTED',
            'reason':None if selected else 'NO_QUALITY_OPTION',
            'underlying':underlying,'underlying_ltp':underlying_ltp,'option_type':option_type,
            'exchange_segment':segment,'expiry':nearest_expiry,'atm':atm,'selected':selected,'candidates':ranked[:8],
        }

    async def sync_core_indices(self) -> dict[str, Any]:
        """Discover core index contracts through the broker search API and subscribe to verified tokens."""
        wanted = [
            ("nse_cm", "NIFTY", "Nifty 50"),
            ("nse_cm", "BANKNIFTY", "Nifty Bank"),
            ("bse_cm", "SENSEX", "Sensex"),
        ]
        discovered=[]
        from app.services.options import flatten_records
        for segment, symbol, index_name in wanted:
            try:
                result = await self.search(segment, symbol)
                rows = flatten_records(result.get('data', result))
                row = rows[0] if rows else None
                if not row:
                    discovered.append({'label': symbol, 'ok': False, 'reason': 'NOT_FOUND'}); continue
                token = row.get('instrument_token') or row.get('instrumentToken') or row.get('token') or row.get('pSymbol') or row.get('p_symbol')
                actual_segment = row.get('exchange_segment') or row.get('exchangeSegment') or segment
                if not token:
                    discovered.append({'label': symbol, 'ok': False, 'reason': 'NO_TOKEN'}); continue
                await broker.subscribe(str(actual_segment), str(index_name), 'index')
                discovered.append({
                    'label': symbol,
                    'ok': True,
                    'exchange_segment': str(actual_segment),
                    'instrument_token': str(index_name),
                    'record': row
                })
            except Exception as exc:
                discovered.append({'label': symbol, 'ok': False, 'reason': str(exc)})
        self.core_indices = discovered
        recovery_store.set_core_indices(discovered)
        return {'ok': any(x.get('ok') for x in discovered), 'indices': discovered}

    def index_snapshot(self) -> list[dict[str, Any]]:
        out=[]
        for item in getattr(self, 'core_indices', []):
            row=dict(item)
            if item.get('ok'):
                key=f"{item['exchange_segment']}|{item['instrument_token']}"
                row['tick']=broker.latest_ticks.get(key)
            out.append(row)
        return out

    async def restore_core_subscriptions(self) -> dict[str, Any]:
        restored=[]
        if not broker.authenticated:
            return {"ok": False, "reason": "LOGIN_REQUIRED", "restored": restored}
        for item in self.core_indices:
            if not item.get("ok"):
                continue
            try:
                await broker.subscribe(str(item["exchange_segment"]), str(item["instrument_token"]), "index")
                restored.append({"label": item.get("label"), "ok": True})
            except Exception as exc:
                restored.append({"label": item.get("label"), "ok": False, "reason": str(exc)})
        return {"ok": all(x.get("ok") for x in restored) if restored else True, "restored": restored}

    def registry_snapshot(self) -> dict[str, Any]:
        snap = recovery_store.snapshot()
        return {"verified_count": len(snap.get("verified_instruments", {})), **snap}


instruments = InstrumentResolver()
