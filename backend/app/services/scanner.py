from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass, asdict
from typing import Any

from app.services.broker import broker
from app.services.options import flatten_records
from app.services.journal import journal
from app.services.market_pipeline import candles

# Two manually-selected groups. Only one group is signal-scanned at a time.
GROUP_A = [
    "RELIANCE","HDFCBANK","ICICIBANK","SBIN","AXISBANK","KOTAKBANK","INDUSINDBK","BAJFINANCE","BAJAJFINSV",
    "HDFCLIFE","SBILIFE","INFY","TCS","HCLTECH","WIPRO","TECHM","LTIM","BHARTIARTL","ITC","HINDUNILVR",
    "NESTLEIND","BRITANNIA","TATACONSUM","ASIANPAINT","TITAN","MARUTI","M&M","TATAMOTORS","EICHERMOT",
    "BAJAJ-AUTO","HEROMOTOCO","TVSMOTOR","LT","ULTRACEMCO","GRASIM","ADANIENT","ADANIPORTS","NTPC",
    "POWERGRID","ONGC","COALINDIA","BPCL","IOC","TATASTEEL","JSWSTEEL",
]

GROUP_B = [
    "HINDALCO","SUNPHARMA","DRREDDY","CIPLA","DIVISLAB","APOLLOHOSP","BEL","HAL","TRENT","DLF","JIOFIN",
    "SHRIRAMFIN","PFC","RECLTD","VEDL","ETERNAL","DMART","IRCTC","IRFC","ABB","SIEMENS","CUMMINSIND",
    "BOSCHLTD","PIDILITIND","HAVELLS","DABUR","MARICO","GODREJCP","COLPAL","UNITDSPR","INDIGO","NAUKRI",
    "LODHA","AMBUJACEM","ACC","SHREECEM","SRF","PIIND","UPL","BANKBARODA","CANBK","PNB","FEDERALBNK",
    "IDFCFIRSTB","AUBANK",
]

assert len(GROUP_A) == 45 and len(GROUP_B) == 45


def _norm(value: Any) -> str:
    return re.sub(r"[^A-Z0-9]", "", str(value or "").upper())


def _token(row: dict[str, Any]) -> str | None:
    value = (row.get("instrument_token") or row.get("instrumentToken") or row.get("token")
             or row.get("pSymbol") or row.get("p_symbol"))
    return None if value in (None, "") else str(value)


def _segment(row: dict[str, Any], default: str = "nse_cm") -> str:
    return str(row.get("exchange_segment") or row.get("exchangeSegment") or row.get("segment") or default)


def _row_score(row: dict[str, Any], symbol: str) -> int:
    want = _norm(symbol)
    score = 0
    for key in ("trading_symbol", "tradingSymbol", "pTrdSymbol", "symbol", "name", "display_name"):
        value = _norm(row.get(key))
        if not value:
            continue
        if value == want or value == want + "EQ":
            score = max(score, 100)
        elif value.startswith(want):
            score = max(score, 80)
        elif want in value:
            score = max(score, 50)
    instrument_type = _norm(row.get("instrument_type") or row.get("instrumentType") or row.get("type"))
    if instrument_type in {"EQ", "EQUITY", "STOCK"}:
        score += 5
    return score


@dataclass(slots=True)
class ScannerInstrument:
    symbol: str
    exchange_segment: str
    instrument_token: str
    symbol_key: str
    trading_symbol: str


class ScannerController:
    def __init__(self) -> None:
        self.active_group: str | None = None
        self.resolved: list[ScannerInstrument] = []
        self.failed: list[dict[str, str]] = []
        self._scanner_subscription_ids: set[str] = set()
        self._lock = asyncio.Lock()

    @staticmethod
    def universe(group: str) -> list[str]:
        group = group.upper()
        if group == "A": return list(GROUP_A)
        if group == "B": return list(GROUP_B)
        raise ValueError("group must be A or B")

    async def _resolve_one(self, symbol: str) -> ScannerInstrument | None:
        # Kotak search is inconsistent for punctuation-heavy symbols (notably M&M / BAJAJ-AUTO).
        # Try a small deterministic set of aliases, but only accept a positively-matched row.
        variants = [symbol, f"{symbol}-EQ"]
        compact = re.sub(r"[^A-Z0-9]", "", symbol.upper())
        spaced = re.sub(r"[^A-Z0-9]+", " ", symbol.upper()).strip()
        for q in (compact, spaced):
            if q and q not in variants:
                variants.append(q)
        special = {
            "M&M": ["M&M", "M AND M", "MANDM", "M&M-EQ"],
            "BAJAJ-AUTO": ["BAJAJ-AUTO", "BAJAJ AUTO", "BAJAJAUTO", "BAJAJ-AUTO-EQ"],
        }
        for q in special.get(symbol.upper(), []):
            if q not in variants:
                variants.append(q)

        best_row = None
        best_score = -1
        for query in variants:
            raw = None
            last_exc = None
            for attempt in range(3):
                try:
                    raw = await broker.search("nse_cm", query)
                    break
                except Exception as exc:
                    last_exc = exc
                    await asyncio.sleep(0.20 * (attempt + 1))
            if raw is None:
                continue
            rows = [x for x in flatten_records(raw) if isinstance(x, dict) and _token(x)]
            for row in rows:
                score = _row_score(row, symbol)
                if score > best_score:
                    best_row, best_score = row, score
            if best_score >= 100:
                break

        if best_row is None or best_score <= 0:
            return None
        token = _token(best_row)
        if not token:
            return None
        segment = _segment(best_row)
        # Stable readable key ensures persisted candles survive token changes/restarts.
        symbol_key = f"{segment}|{symbol}"
        trading_symbol = str(best_row.get('trading_symbol') or best_row.get('tradingSymbol') or best_row.get('pTrdSymbol') or best_row.get('p_trd_symbol') or best_row.get('symbol') or symbol)
        return ScannerInstrument(symbol, segment, token, symbol_key, trading_symbol)

    async def _resolve_group(self, names: list[str]) -> tuple[list[ScannerInstrument], list[dict[str,str]]]:
        sem = asyncio.Semaphore(6)
        async def one(name: str):
            async with sem:
                try:
                    return name, await self._resolve_one(name), None
                except Exception as exc:
                    return name, None, str(exc)
        results = await asyncio.gather(*(one(name) for name in names))
        good: list[ScannerInstrument] = []
        failed: list[dict[str,str]] = []
        for name, item, err in results:
            if item is not None:
                good.append(item)
            else:
                failed.append({"symbol": name, "reason": err or "NOT_FOUND"})
        return good, failed

    async def _clear_previous(self) -> None:
        for subscription_id in list(self._scanner_subscription_ids):
            broker.subscriptions.pop(subscription_id, None)
        self._scanner_subscription_ids.clear()
        for item in self.resolved:
            broker.symbol_aliases.pop(f"{item.exchange_segment}|{item.instrument_token}", None)
            broker.signal_trade_meta.pop(item.symbol_key, None)
        broker.signal_scan_keys.clear()
        self.resolved = []
        self.failed = []

    async def start(self, group: str) -> dict[str, Any]:
        if not broker.authenticated:
            raise RuntimeError("LOGIN_REQUIRED")
        group = group.upper()
        names = self.universe(group)
        async with self._lock:
            await self._clear_previous()
            good, failed = await self._resolve_group(names)
            for item in good:
                raw_key = f"{item.exchange_segment}|{item.instrument_token}"
                broker.symbol_aliases[raw_key] = item.symbol_key
                broker.signal_scan_keys.add(item.symbol_key)
                # Cash-market scanner symbols are directly tradable from a signal card.
                broker.signal_trade_meta[item.symbol_key] = {
                    "trading_symbol": item.trading_symbol,
                    "exchange_segment": item.exchange_segment,
                    "instrument_token": item.instrument_token,
                }
                sub_id = f"{item.exchange_segment}|{item.instrument_token}|scrip"
                broker.subscriptions[sub_id] = (item.exchange_segment, item.instrument_token, "scrip")
                self._scanner_subscription_ids.add(sub_id)
            self.active_group = group
            self.resolved = good
            self.failed = failed
            await broker.recycle_market_stream()
            result = self.status()
            journal.add("scanner", "start", result)
            return result

    async def stop(self) -> dict[str, Any]:
        async with self._lock:
            await self._clear_previous()
            self.active_group = None
            if broker.authenticated:
                await broker.recycle_market_stream()
            result = self.status()
            journal.add("scanner", "stop", result)
            return result

    def status(self) -> dict[str, Any]:
        names = self.universe(self.active_group) if self.active_group else []
        minimum_history = 24
        history = []
        for item in self.resolved:
            rows = candles.get_history(item.symbol_key, 300, 100)
            closed_count = max(0, len(rows) - (1 if (item.symbol_key, 300) in candles.current else 0))
            history.append({"symbol": item.symbol, "symbol_key": item.symbol_key, "closed_5m": closed_count, "ready": closed_count >= minimum_history})
        ready_count = sum(1 for row in history if row["ready"])
        tick_live = [item.symbol for item in self.resolved if item.symbol_key in broker.latest_ticks]
        tick_missing = [item.symbol for item in self.resolved if item.symbol_key not in broker.latest_ticks]
        return {
            "active": self.active_group is not None,
            "group": self.active_group,
            "configured_count": len(names),
            "resolved_count": len(self.resolved),
            "failed_count": len(self.failed),
            "ready_count": ready_count,
            "warming_count": max(0, len(history) - ready_count),
            "tick_live_count": len(tick_live),
            "tick_missing_count": len(tick_missing),
            "tick_live_symbols": tick_live,
            "tick_missing_symbols": tick_missing,
            "minimum_history": minimum_history,
            "history": history,
            "resolved": [asdict(x) for x in self.resolved],
            "failed": list(self.failed),
            "failed_symbols": [x.get("symbol") for x in self.failed],
            "signal_scan_keys": sorted(broker.signal_scan_keys),
        }

    def groups(self) -> dict[str, Any]:
        return {"A": GROUP_A, "B": GROUP_B, "count_each": 45, "total": 90}

scanner_controller = ScannerController()
