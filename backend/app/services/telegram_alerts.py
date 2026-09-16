from __future__ import annotations

import asyncio
import json
import re
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
    """LION BRO Telegram control + alert bridge.

    Private configured chat only.

    Commands:
      /start, /menu, /status, /signals
      /login <current TOTP>
      /optionchain [nifty|banknifty|sensex]
      option chain [nifty|banknifty|sensex]
      /premium [nifty|banknifty|sensex]
      /scana, /scanb, /scanstop
      /gammaon, /gammaoff
    """

    def __init__(self) -> None:
        self.task: asyncio.Task | None = None
        self.offset = 0
        self._last_explosion: dict[str, str] = {}
        self._last_lifecycle_state: dict[str, str] = {}
        self._command_tasks: set[asyncio.Task] = set()
        self._broker_command_lock = asyncio.Lock()

    @property
    def configured(self) -> bool:
        return bool(
            settings.telegram_enabled
            and settings.telegram_bot_token
            and settings.telegram_chat_id
        )

    def status(self) -> dict[str, Any]:
        return {
            "configured": self.configured,
            "enabled": bool(settings.telegram_enabled),
            "polling": bool(self.task and not self.task.done()),
            "chat_configured": bool(settings.telegram_chat_id),
            "active_commands": len(self._command_tasks),
        }

    async def _http_json(
        self, method: str, payload: dict[str, Any] | None = None
    ) -> Any:
        token = settings.telegram_bot_token.strip()
        if not token:
            return None
        url = f"https://api.telegram.org/bot{token}/{method}"

        def call():
            data = None
            headers = {"User-Agent": "LION-BRO/1.1"}
            if payload is not None:
                data = urllib.parse.urlencode(payload).encode("utf-8")
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            req = urllib.request.Request(
                url,
                data=data,
                headers=headers,
                method="POST" if data else "GET",
            )
            with urllib.request.urlopen(req, timeout=35) as r:
                return json.loads(r.read().decode("utf-8"))

        return await asyncio.to_thread(call)

    def _menu_markup(self) -> dict[str, Any]:
        return {
            "keyboard": [
                ["📊 NIFTY", "📊 BANKNIFTY", "📊 SENSEX"],
                ["💰 PREMIUM", "🟢 STATUS", "📈 SIGNALS"],
                ["🔍 SCAN A", "🔍 SCAN B", "⛔ STOP SCAN"],
                ["⚡ GAMMA ON", "⚡ GAMMA OFF"],
                ["🔐 LOGIN HELP"],
            ],
            "resize_keyboard": True,
            "is_persistent": True,
            "input_field_placeholder": "LION BRO command",
        }

    async def send(
        self, text: str, *, reply_markup: dict[str, Any] | None = None
    ) -> bool:
        if not self.configured:
            return False
        try:
            payload: dict[str, Any] = {
                "chat_id": settings.telegram_chat_id,
                "text": text[:4000],
                "disable_web_page_preview": "true",
            }
            if reply_markup is not None:
                payload["reply_markup"] = json.dumps(reply_markup)
            r = await self._http_json("sendMessage", payload)
            return bool(isinstance(r, dict) and r.get("ok"))
        except Exception:
            return False

    async def _delete_message(self, message_id: Any) -> None:
        if not message_id:
            return
        try:
            await self._http_json(
                "deleteMessage",
                {
                    "chat_id": settings.telegram_chat_id,
                    "message_id": str(message_id),
                },
            )
        except Exception:
            pass

    def _track_task(self, coro: Any) -> None:
        task = asyncio.create_task(coro)
        self._command_tasks.add(task)
        task.add_done_callback(self._command_tasks.discard)

    async def _send_menu(self) -> None:
        await self.send(
            "🦁 LION BRO CONTROL\n"
            "Option chain, premium check, stock scanner and Gamma/Explosion controls are ready.\n\n"
            "Login: /login <CURRENT_TOTP>\n"
            "Example: /login 123456\n"
            "For security, the bot will try to delete the TOTP message immediately.",
            reply_markup=self._menu_markup(),
        )

    async def notify_signal(self, item: Any) -> None:
        d = item.to_dict() if hasattr(item, "to_dict") else dict(item or {})
        sym = d.get("trading_symbol") or d.get("symbol_key") or "--"
        option_line = ""
        if d.get("option_ltp") is not None:
            option_line = (
                f"\nOption premium: ₹{_fmt(d.get('option_ltp'))}"
                f" | OI: {d.get('option_oi') or '--'}"
            )
        text = (
            "🦁 LION BRO SIGNAL\n"
            f"{str(d.get('side') or '--').upper()} • {sym}\n"
            f"Entry: {_fmt(d.get('entry'))}\n"
            f"SL: {_fmt(d.get('stop'))}\n"
            f"T1: {_fmt(d.get('target1'))} | T2: {_fmt(d.get('target2'))}"
            + (f" | T3: {_fmt(d.get('target3'))}" if d.get("target3") is not None else "")
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
            f"Premium: ₹{_fmt(selected.get('premium') if selected.get('premium') is not None else selected.get('ltp'))}"
            f" | OI: {selected.get('oi') or '--'}"
        )

    @staticmethod
    def _pairs(requested: str) -> list[tuple[str, str]]:
        q = requested.upper().replace(" ", "")
        if "BANK" in q:
            return [("BANKNIFTY", "nse_cm|Nifty Bank")]
        if "SENSEX" in q:
            return [("SENSEX", "bse_cm|Sensex")]
        if "NIFTY" in q:
            return [("NIFTY", "nse_cm|Nifty 50")]
        return [
            ("NIFTY", "nse_cm|Nifty 50"),
            ("BANKNIFTY", "nse_cm|Nifty Bank"),
            ("SENSEX", "bse_cm|Sensex"),
        ]

    async def _option_chain_text(self, requested: str) -> str:
        from app.services.broker import broker
        from app.services.instruments import instruments

        if not broker.authenticated:
            return "LION BRO: Kotak login required before option-chain data can be fetched."

        sections: list[str] = []
        for label, key in self._pairs(requested):
            try:
                chain = await asyncio.wait_for(
                    instruments.index_option_chain(
                        symbol_key=key,
                        strikes_each_side=3,
                    ),
                    timeout=20.0,
                )
            except asyncio.TimeoutError:
                sections.append(f"{label}: TIMEOUT • Kotak option data did not reply in 20s.")
                continue
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
                grouped.setdefault(strike, {})[
                    str(row.get("option_type") or "").upper()
                ] = row

            lines = [
                f"📊 {label} OPTION CHAIN",
                f"Spot: {_fmt(chain.get('underlying_ltp'))} | Exp: {chain.get('expiry') or '--'}",
                "CE LTP | CE OI | STRIKE | PE OI | PE LTP",
            ]
            for strike in sorted(grouped):
                ce = grouped[strike].get("CE", {})
                pe = grouped[strike].get("PE", {})
                lines.append(
                    f"{_fmt(ce.get('ltp'))} | {ce.get('oi') or '--'} | "
                    f"{strike:.0f} | {pe.get('oi') or '--'} | {_fmt(pe.get('ltp'))}"
                )
            sections.append("\n".join(lines))
        return "\n\n".join(sections)

    async def _option_chain_reply(self, requested: str) -> None:
        label = requested.upper() if requested else "NIFTY/BANKNIFTY/SENSEX"
        await self.send(f"⏳ Fetching {label} option chain…")
        async with self._broker_command_lock:
            text = await self._option_chain_text(requested)
        await self.send(text)

    async def _premium_text(self, requested: str) -> str:
        from app.services.broker import broker
        from app.services.instruments import instruments

        if not broker.authenticated:
            return "LION BRO: Kotak login required before premium fetch."

        label, key = self._pairs(requested or "nifty")[0]
        try:
            chain = await asyncio.wait_for(
                instruments.index_option_chain(
                    symbol_key=key,
                    strikes_each_side=1,
                ),
                timeout=20.0,
            )
        except asyncio.TimeoutError:
            return f"💰 {label} PREMIUM CHECK\nTIMEOUT • Kotak premium data did not reply."
        except Exception as exc:
            return f"💰 {label} PREMIUM CHECK\nERROR: {exc}"

        if chain.get("status") != "READY":
            return f"💰 {label} PREMIUM CHECK\n{chain.get('reason') or 'UNAVAILABLE'}"

        spot = _num(chain.get("underlying_ltp"))
        rows = [x for x in (chain.get("rows") or []) if isinstance(x, dict)]
        strikes = sorted(
            {
                float(x["strike"])
                for x in rows
                if x.get("strike") not in (None, "")
            }
        )
        if not strikes:
            return f"💰 {label} PREMIUM CHECK\nNo strike data."

        atm = min(strikes, key=lambda x: abs(x - spot)) if spot is not None else strikes[len(strikes) // 2]
        ce = next(
            (
                x
                for x in rows
                if _num(x.get("strike")) == atm
                and str(x.get("option_type") or "").upper() == "CE"
            ),
            {},
        )
        pe = next(
            (
                x
                for x in rows
                if _num(x.get("strike")) == atm
                and str(x.get("option_type") or "").upper() == "PE"
            ),
            {},
        )
        return (
            f"💰 {label} PREMIUM CHECK\n"
            f"Spot: {_fmt(chain.get('underlying_ltp'))}\n"
            f"Expiry: {chain.get('expiry') or '--'}\n"
            f"ATM: {atm:.0f}\n"
            f"CE: ₹{_fmt(ce.get('ltp'))} | OI: {ce.get('oi') or '--'}\n"
            f"PE: ₹{_fmt(pe.get('ltp'))} | OI: {pe.get('oi') or '--'}"
        )

    async def _premium_reply(self, requested: str) -> None:
        label = requested.upper() if requested else "NIFTY"
        await self.send(f"⏳ Checking {label} ATM premium…")
        async with self._broker_command_lock:
            text = await self._premium_text(requested)
        await self.send(text)

    async def _status_text(self) -> str:
        from app.services.broker import broker
        from app.services.explosion_detector import explosion_detector
        from app.services.scanner import scanner_controller

        age = (
            None
            if broker.last_market_message_at is None
            else max(0.0, time.time() - broker.last_market_message_at)
        )
        live = bool(
            broker.authenticated
            and broker.market_task
            and not broker.market_task.done()
            and age is not None
            and age <= 15
        )
        scan = scanner_controller.status()
        return (
            "🦁 LION BRO STATUS\n"
            f"Kotak: {'AUTHENTICATED' if broker.authenticated else 'LOGIN REQUIRED'}\n"
            f"Market: {'LIVE' if live else 'WAITING/OFFLINE'}\n"
            f"Feed age: {('--' if age is None else f'{age:.1f}s')}\n"
            f"Scanner: {('GROUP ' + str(scan.get('group'))) if scan.get('active') else 'OFF'}\n"
            f"Gamma: {'ON' if explosion_detector.enabled else 'OFF'}"
        )

    async def _login(self, code: str, message_id: Any) -> None:
        from app.services.broker import broker
        from app.services.instruments import instruments

        # Best-effort deletion keeps the TOTP from remaining visible in the chat.
        await self._delete_message(message_id)

        if not re.fullmatch(r"\d{6,8}", code):
            await self.send(
                "🔐 LOGIN HELP\nSend: /login <CURRENT_TOTP>\nExample: /login 123456"
            )
            return

        if broker.authenticated:
            await self.send("✅ Kotak is already authenticated.")
            return

        await self.send("🔐 Kotak login in progress…")
        async with self._broker_command_lock:
            try:
                result = await asyncio.wait_for(broker.login(code), timeout=45.0)
                if not result.get("ok"):
                    await self.send(
                        f"❌ Kotak login failed: {result.get('message') or result.get('detail') or 'Unknown response'}"
                    )
                    return
                await broker.start_streams()
                restored = await asyncio.wait_for(
                    instruments.restore_core_subscriptions(),
                    timeout=35.0,
                )
            except asyncio.TimeoutError:
                await self.send("❌ Kotak login/recovery timed out. Get a fresh TOTP and retry.")
                return
            except Exception as exc:
                await self.send(f"❌ Kotak login failed: {exc}")
                return

        await self.send(
            "✅ KOTAK LOGIN SUCCESS\n"
            f"Core subscriptions restored: {len(restored.get('restored') or [])}"
        )

    async def _scanner(self, action: str) -> None:
        from app.services.broker import broker
        from app.services.scanner import scanner_controller

        if action in {"A", "B"} and not broker.authenticated:
            await self.send("LION BRO: Kotak login required before stock scanner can start.")
            return

        if action == "STOP":
            await self.send("⏳ Stopping stock scanner…")
            async with self._broker_command_lock:
                try:
                    status = await asyncio.wait_for(
                        scanner_controller.stop(),
                        timeout=45.0,
                    )
                except asyncio.TimeoutError:
                    await self.send("⚠️ Scanner stop timed out.")
                    return
            await self.send(
                f"⛔ STOCK SCANNER OFF\nResolved: {status.get('resolved_count', 0)}"
            )
            return

        await self.send(f"⏳ Starting STOCK SCANNER {action}…")
        async with self._broker_command_lock:
            try:
                status = await asyncio.wait_for(
                    scanner_controller.start(action),
                    timeout=100.0,
                )
            except asyncio.TimeoutError:
                await self.send(
                    f"⚠️ STOCK SCANNER {action} start timed out. Use STATUS before retrying."
                )
                return
            except Exception as exc:
                await self.send(f"❌ STOCK SCANNER {action} failed: {exc}")
                return

        await self.send(
            f"🔍 STOCK SCANNER {action} ON\n"
            f"Resolved: {status.get('resolved_count', 0)}/{status.get('configured_count', 0)}\n"
            f"Ready: {status.get('ready_count', 0)} | Warming: {status.get('warming_count', 0)}"
        )

    async def _gamma(self, enabled: bool) -> None:
        from app.services.broker import broker
        from app.services.explosion_detector import explosion_detector
        from app.services.instruments import instruments

        status = explosion_detector.set_enabled(enabled)
        sync_note = ""
        if enabled and broker.authenticated:
            async with self._broker_command_lock:
                try:
                    result = await asyncio.wait_for(
                        instruments.sync_core_indices(),
                        timeout=35.0,
                    )
                    sync_note = f"\nCore indices: {'READY' if result.get('ok') else 'PARTIAL'}"
                except asyncio.TimeoutError:
                    sync_note = "\nCore indices: sync timeout"
                except Exception:
                    sync_note = "\nCore indices: sync error"

        await self.send(
            f"⚡ GAMMA / EXPLOSION DETECTOR: {'ON' if status.get('enabled') else 'OFF'}"
            f"\nMode: ALERT ONLY{sync_note}"
        )

    async def _signals(self) -> None:
        from app.services.lifecycle import signal_lifecycle

        rows = signal_lifecycle.list(5)
        if not rows:
            await self.send("LION BRO: No live signals yet.")
            return
        out = ["🦁 LION BRO • RECENT SIGNALS"]
        for d in rows:
            out.append(
                f"{d.get('side', '--')} "
                f"{d.get('trading_symbol') or d.get('symbol_key', '--')} | "
                f"{d.get('state', '--')} | Entry {_fmt(d.get('entry'))}"
            )
        await self.send("\n".join(out))

    async def _handle_message(self, message: dict[str, Any]) -> None:
        chat = message.get("chat") or {}
        if str(chat.get("id")) != str(settings.telegram_chat_id):
            return

        text = str(message.get("text") or "").strip()
        if not text:
            return
        low = text.lower().replace("_", " ")
        message_id = message.get("message_id")

        if low in {"/start", "/menu", "/help", "menu"}:
            await self._send_menu()
            return

        if low.startswith("/login"):
            code = text.partition(" ")[2].strip()
            await self._login(code, message_id)
            return

        if low in {"🔐 login help", "login help"}:
            await self.send(
                "🔐 LOGIN HELP\n"
                "Send: /login <CURRENT_TOTP>\n"
                "Example: /login 123456\n"
                "The bot will try to delete the TOTP message immediately.\n"
                "App login remains the safer option."
            )
            return

        if low in {"📊 nifty", "nifty option chain"}:
            await self._option_chain_reply("nifty")
            return
        if low in {"📊 banknifty", "banknifty option chain"}:
            await self._option_chain_reply("banknifty")
            return
        if low in {"📊 sensex", "sensex option chain"}:
            await self._option_chain_reply("sensex")
            return

        if (
            low.startswith("/optionchain")
            or low.startswith("/option chain")
            or low.startswith("option chain")
            or low.startswith("optionchain")
        ):
            requested = (
                low.replace("/optionchain", "")
                .replace("/option chain", "")
                .replace("option chain", "")
                .replace("optionchain", "")
                .strip()
            )
            await self._option_chain_reply(requested)
            return

        if low == "💰 premium":
            await self._premium_reply("nifty")
            return
        if low.startswith("/premium") or low.startswith("premium "):
            requested = (
                low.replace("/premium", "", 1)
                .replace("premium", "", 1)
                .strip()
            )
            await self._premium_reply(requested or "nifty")
            return

        if low in {"/scana", "scan a", "🔍 scan a"}:
            await self._scanner("A")
            return
        if low in {"/scanb", "scan b", "🔍 scan b"}:
            await self._scanner("B")
            return
        if low in {"/scanstop", "scan stop", "stop scan", "⛔ stop scan"}:
            await self._scanner("STOP")
            return

        if low in {"/gammaon", "gamma on", "⚡ gamma on"}:
            await self._gamma(True)
            return
        if low in {"/gammaoff", "gamma off", "⚡ gamma off"}:
            await self._gamma(False)
            return

        if low.startswith("/signals") or low in {"signals", "📈 signals"}:
            await self._signals()
            return

        if low.startswith("/status") or low in {"status", "🟢 status"}:
            await self.send(await self._status_text())
            return

    async def _poll_loop(self) -> None:
        while self.configured:
            try:
                r = await self._http_json(
                    "getUpdates",
                    {
                        "timeout": 20,
                        "offset": self.offset,
                        "allowed_updates": json.dumps(["message"]),
                    },
                )
                if isinstance(r, dict) and r.get("ok"):
                    for upd in r.get("result") or []:
                        uid = int(upd.get("update_id") or 0)
                        self.offset = max(self.offset, uid + 1)
                        msg = upd.get("message")
                        if isinstance(msg, dict):
                            self._track_task(self._handle_message(msg))
            except asyncio.CancelledError:
                raise
            except Exception:
                await asyncio.sleep(3)

    async def _prepare_polling(self) -> None:
        try:
            await self._http_json(
                "deleteWebhook",
                {"drop_pending_updates": "true"},
            )
        except Exception:
            pass
        await self._poll_loop()

    def start(self) -> None:
        if self.configured and (self.task is None or self.task.done()):
            self.task = asyncio.create_task(
                self._prepare_polling(),
                name="lion-bro-telegram",
            )

    async def stop(self) -> None:
        if self.task and not self.task.done():
            self.task.cancel()
            try:
                await self.task
            except asyncio.CancelledError:
                pass
        self.task = None

        tasks = list(self._command_tasks)
        for task in tasks:
            task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._command_tasks.clear()


telegram_alerts = TelegramAlerts()
