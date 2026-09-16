from __future__ import annotations

import asyncio
import json
import time
import urllib.parse
import urllib.request
from typing import Any

from app.core.config import settings


def _num(v: Any) -> float | None:
    try:
        if v is None or v == "":
            return None
        return float(v)
    except (TypeError, ValueError):
        return None


def _fmt(v: Any, digits: int = 2) -> str:
    n = _num(v)
    return "--" if n is None else f"{n:,.{digits}f}"


class TelegramAlerts:
    """Small dependency-free Telegram bot/alert bridge.

    Supported incoming commands (private configured chat only):
      option chain
      option chain nifty
      option chain banknifty
      option chain sensex
      /optionchain [index]
      /signals
      /status

    Outgoing alerts:
      - every normal strategy signal created by the lifecycle engine
      - lifecycle state changes (ENTRY/T1/T2/T3/SL/EXPIRED where available)
      - Explosion Detector TRIGGERED / EXPLOSION / RE-EXPLOSION
    """

    def __init__(self) -> None:
        self.task: asyncio.Task | None = None
        self.offset = 0
        self._last_explosion: dict[str, str] = {}
        self._last_lifecycle_state: dict[str, str] = {}

    @property
    def configured(self) -> bool:
        return bool(settings.telegram_enabled and settings.telegram_bot_token and settings.telegram_chat_id)

    def status(self) -> dict[str, Any]:
        return {
            "configured": self.configured,
            "enabled": bool(settings.telegram_enabled),
            "polling": bool(self.task and not self.task.done()),
            "chat_configured": bool(settings.telegram_chat_id),
        }

    async def _http_json(self, method: str, payload: dict[str, Any] | None = None) -> Any:
        token = settings.telegram_bot_token.strip()
        if not token:
            return None
        url = f"https://api.telegram.org/bot{token}/{method}"

        def call():
            data = None
            headers = {"User-Agent": "LION-BRO/1.0"}
            if payload is not None:
                data = urllib.parse.urlencode(payload).encode("utf-8")
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
            with urllib.request.urlopen(req, timeout=35) as r:
                return json.loads(r.read().decode("utf-8"))

        return await asyncio.to_thread(call)

    async def send(self, text: str) -> bool:
        if not self.configured:
            return False
        try:
            r = await self._http_json("sendMessage", {
                "chat_id": settings.telegram_chat_id,
                "text": text[:4000],
                "disable_web_page_preview": "true",
            })
            return bool(isinstance(r, dict) and r.get("ok"))
        except Exception:
            return False

    async def notify_signal(self, item: Any) -> None:
        d = item.to_dict() if hasattr(item, "to_dict") else dict(item or {})
        sym = d.get("trading_symbol") or d.get("symbol_key") or "--"
        option_line = ""
        if d.get("option_ltp") is not None:
            option_line = f"\nOption premium: ₹{_fmt(d.get('option_ltp'))} | OI: {d.get('option_oi') or '--'}"
        text = (
            "🦁 LION BRO SIGNAL\n"
            f"{str(d.get('side') or '--').upper()} • {sym}\n"
            f"Entry: {_fmt(d.get('entry'))}\n"
            f"SL: {_fmt(d.get('stop'))}\n"
            f"T1: {_fmt(d.get('target1'))} | T2: {_fmt(d.get('target2'))}"
            + (f" | T3: {_fmt(d.get('target3'))}" if d.get('target3') is not None else "")
            + f"\nScore: {d.get('score') or '--'} | RR: {d.get('rr') or '--'}"
            + option_line
            + f"\nStatus: {d.get('option_status') or d.get('state') or 'ACTIVE'}"
        )
        await self.send(text)

    async def notify_lifecycle(self, d: dict[str, Any]) -> None:
        sid = str(d.get("id") or "")
        state = str(d.get("state") or "")
        if not sid or not state or self._last_lifecycle_state.get(sid) == state:
            return
        self._last_lifecycle_state[sid] = state
        await self.send(
            "📌 LION BRO SIGNAL UPDATE\n"
            f"{d.get('trading_symbol') or d.get('symbol_key') or '--'}\n"
            f"State: {state}\nLast: {_fmt(d.get('last_price'))}"
        )

    async def notify_explosion(self, d: dict[str, Any]) -> None:
        state = str(d.get("state") or "").upper()
        if state not in {"TRIGGERED", "EXPLOSION", "RE-EXPLOSION"}:
            return
        sym = str(d.get("symbol_key") or d.get("underlying") or "--")
        if self._last_explosion.get(sym) == state:
            return
        self._last_explosion[sym] = state
        opt = d.get("option") if isinstance(d.get("option"), dict) else {}
        selected = opt.get("selected") if isinstance(opt.get("selected"), dict) else opt
        await self.send(
            "⚡ LION BRO EXPLOSION DETECTOR\n"
            f"{sym} • {state}\n"
            f"Side: {d.get('side') or '--'} | Score: {d.get('score') or '--'}/100\n"
            f"Option: {selected.get('trading_symbol') or '--'}\n"
            f"Premium: ₹{_fmt(selected.get('premium') if selected.get('premium') is not None else selected.get('ltp'))} | OI: {selected.get('oi') or '--'}"
        )

    async def _option_chain_text(self, requested: str) -> str:
        from app.services.instruments import instruments
        from app.services.broker import broker

        if not broker.authenticated:
            return "LION BRO: Kotak login required before option-chain data can be fetched."
        q = requested.upper().replace(" ", "")
        if "BANK" in q:
            pairs = [("BANKNIFTY", "nse_cm|Nifty Bank")]
        elif "SENSEX" in q:
            pairs = [("SENSEX", "bse_cm|Sensex")]
        elif "NIFTY" in q:
            pairs = [("NIFTY", "nse_cm|Nifty 50")]
        else:
            pairs = [
                ("NIFTY", "nse_cm|Nifty 50"),
                ("BANKNIFTY", "nse_cm|Nifty Bank"),
                ("SENSEX", "bse_cm|Sensex"),
            ]

        sections: list[str] = []
        for label, key in pairs:
            try:
                chain = await instruments.index_option_chain(symbol_key=key, strikes_each_side=3)
            except Exception as exc:
                sections.append(f"{label}: ERROR {exc}")
                continue
            if chain.get("status") != "READY":
                sections.append(f"{label}: {chain.get('reason') or 'UNAVAILABLE'}")
                continue
            grouped: dict[float, dict[str, dict[str, Any]]] = {}
            for row in chain.get("rows") or []:
                try:
                    strike = float(row.get("strike"))
                except Exception:
                    continue
                grouped.setdefault(strike, {})[str(row.get("option_type") or "").upper()] = row
            lines = [
                f"📊 {label} OPTION CHAIN",
                f"Spot: {_fmt(chain.get('underlying_ltp'))} | Exp: {chain.get('expiry') or '--'}",
                "CE LTP | CE OI | STRIKE | PE OI | PE LTP",
            ]
            for strike in sorted(grouped):
                ce, pe = grouped[strike].get("CE", {}), grouped[strike].get("PE", {})
                lines.append(
                    f"{_fmt(ce.get('ltp'))} | {ce.get('oi') or '--'} | {strike:.0f} | {pe.get('oi') or '--'} | {_fmt(pe.get('ltp'))}"
                )
            sections.append("\n".join(lines))
        return "\n\n".join(sections)

    async def _handle_message(self, message: dict[str, Any]) -> None:
        chat = message.get("chat") or {}
        if str(chat.get("id")) != str(settings.telegram_chat_id):
            return
        text = str(message.get("text") or "").strip()
        low = text.lower().replace("_", " ")
        if low.startswith("/optionchain") or low.startswith("/option chain") or low.startswith("option chain") or low.startswith("optionchain"):
            requested = low.replace("/optionchain", "").replace("/option chain", "").replace("option chain", "").replace("optionchain", "").strip()
            await self.send(await self._option_chain_text(requested))
        elif low.startswith("/signals"):
            from app.services.lifecycle import signal_lifecycle
            rows = signal_lifecycle.list(5)
            if not rows:
                await self.send("LION BRO: No live signals yet.")
            else:
                out = ["🦁 LION BRO • RECENT SIGNALS"]
                for d in rows:
                    out.append(f"{d.get('side','--')} {d.get('trading_symbol') or d.get('symbol_key','--')} | {d.get('state','--')} | Entry {_fmt(d.get('entry'))}")
                await self.send("\n".join(out))
        elif low.startswith("/status") or low == "status":
            from app.services.broker import broker
            age = None if broker.last_market_message_at is None else max(0, time.time()-broker.last_market_message_at)
            live = bool(broker.authenticated and broker.market_task and not broker.market_task.done() and age is not None and age <= 15)
            await self.send(f"LION BRO STATUS\nKotak: {'AUTHENTICATED' if broker.authenticated else 'LOGIN REQUIRED'}\nMarket: {'LIVE' if live else 'WAITING/OFFLINE'}\nFeed age: {('--' if age is None else f'{age:.1f}s')}")

    async def _poll_loop(self) -> None:
        while self.configured:
            try:
                r = await self._http_json("getUpdates", {
                    "timeout": 20,
                    "offset": self.offset,
                    "allowed_updates": json.dumps(["message"]),
                })
                if isinstance(r, dict) and r.get("ok"):
                    for upd in r.get("result") or []:
                        uid = int(upd.get("update_id") or 0)
                        self.offset = max(self.offset, uid + 1)
                        msg = upd.get("message")
                        if isinstance(msg, dict):
                            await self._handle_message(msg)
            except asyncio.CancelledError:
                raise
            except Exception:
                await asyncio.sleep(3)

    async def _prepare_polling(self) -> None:
        # getUpdates and webhooks are mutually exclusive in Telegram. This bot is
        # intentionally used in polling mode by LION BRO.
        try:
            await self._http_json("deleteWebhook", {"drop_pending_updates": "false"})
        except Exception:
            pass
        await self._poll_loop()

    def start(self) -> None:
        if self.configured and (self.task is None or self.task.done()):
            self.task = asyncio.create_task(self._prepare_polling(), name="lion-bro-telegram")

    async def stop(self) -> None:
        if self.task and not self.task.done():
            self.task.cancel()
            try:
                await self.task
            except asyncio.CancelledError:
                pass
        self.task = None


telegram_alerts = TelegramAlerts()
