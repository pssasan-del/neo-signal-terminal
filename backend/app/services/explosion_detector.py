from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from statistics import fmean
from typing import Any
import json
import sqlite3
import time


def _num(v: Any) -> float | None:
    try:
        if v is None or v == "":
            return None
        return float(v)
    except (TypeError, ValueError):
        return None


def _clean(rows: list[dict[str, Any]]) -> list[dict[str, float]]:
    out: list[dict[str, float]] = []
    for row in rows:
        try:
            out.append({
                "open": float(row["open"]),
                "high": float(row["high"]),
                "low": float(row["low"]),
                "close": float(row["close"]),
                "volume": float(row.get("volume") or 0.0),
            })
        except Exception:
            continue
    return out


def _ema(values: list[float], period: int) -> float | None:
    if len(values) < period:
        return None
    value = fmean(values[:period])
    k = 2.0 / (period + 1.0)
    for x in values[period:]:
        value = ((x - value) * k) + value
    return value


def _trend(rows: list[dict[str, Any]], fast: int = 5, slow: int = 13) -> str | None:
    clean = _clean(rows)
    if len(clean) < slow:
        return None
    closes = [x["close"] for x in clean]
    ef, es = _ema(closes, fast), _ema(closes, slow)
    if ef is None or es is None:
        return None
    if ef > es and closes[-1] >= ef:
        return "BUY"
    if ef < es and closes[-1] <= ef:
        return "SELL"
    return "NEUTRAL"


def _rsi(values: list[float], period: int = 14) -> float | None:
    if len(values) < period + 1:
        return None
    changes = [values[i] - values[i - 1] for i in range(1, len(values))][-period:]
    gains = [max(0.0, x) for x in changes]
    losses = [max(0.0, -x) for x in changes]
    avg_gain = fmean(gains)
    avg_loss = fmean(losses)
    if avg_loss <= 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100.0 - 100.0 / (1.0 + rs)


def _williams(highs: list[float], lows: list[float], closes: list[float], period: int = 14) -> float | None:
    if len(closes) < period:
        return None
    hh, ll = max(highs[-period:]), min(lows[-period:])
    if hh <= ll:
        return None
    return -100.0 * ((hh - closes[-1]) / (hh - ll))


def _atr(rows: list[dict[str, float]], period: int = 14) -> float | None:
    if len(rows) < period + 1:
        return None
    trs: list[float] = []
    prev: float | None = None
    for row in rows:
        h, l, c = row["high"], row["low"], row["close"]
        tr = h - l if prev is None else max(h - l, abs(h - prev), abs(l - prev))
        trs.append(max(0.0, tr))
        prev = c
    vals = trs[-period:]
    return fmean(vals) if vals else None


@dataclass(slots=True)
class DetectorMemory:
    last_premium: float | None = None
    last_volume: float | None = None
    last_oi: float | None = None
    peak_premium: float | None = None
    had_explosion_at: float | None = None
    cooled_after_explosion: bool = False
    last_state: str = "WATCH"


class ExplosionDetector:
    """Independent, alert-only gamma/momentum detector.

    It never places an order. It scores closed underlying candles first and only asks the
    broker layer for a real option contract when the underlying is sufficiently armed.
    Every finalized evaluation is persisted for replay/backtesting.
    """

    def __init__(self, db_path: Path | None = None) -> None:
        root = Path(__file__).resolve().parents[2]
        self.db_path = db_path or (root / "explosion_history.db")
        self.enabled = False
        self.latest: dict[str, dict[str, Any]] = {}
        self.memory: dict[str, DetectorMemory] = {}
        self._last_vix: float | None = None
        self._init_db()
        self._load_state()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_path)

    def _init_db(self) -> None:
        with self._connect() as con:
            con.execute(
                """
                CREATE TABLE IF NOT EXISTS detector_config (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                )
                """
            )
            con.execute(
                """
                CREATE TABLE IF NOT EXISTS explosion_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts REAL NOT NULL,
                    symbol_key TEXT NOT NULL,
                    state TEXT NOT NULL,
                    score INTEGER NOT NULL,
                    side TEXT,
                    underlying REAL,
                    option_symbol TEXT,
                    premium REAL,
                    oi REAL,
                    oi_change REAL,
                    volume REAL,
                    iv REAL,
                    delta REAL,
                    gamma REAL,
                    vix REAL,
                    payload_json TEXT NOT NULL
                )
                """
            )
            con.execute("CREATE INDEX IF NOT EXISTS idx_explosion_symbol_ts ON explosion_snapshots(symbol_key, ts DESC)")
            con.commit()

    def _load_state(self) -> None:
        with self._connect() as con:
            row = con.execute("SELECT value FROM detector_config WHERE key='enabled'").fetchone()
            if row:
                self.enabled = row[0] == "1"
            rows = con.execute(
                "SELECT symbol_key, payload_json FROM explosion_snapshots ORDER BY ts DESC LIMIT 50"
            ).fetchall()
        for symbol_key, payload in rows:
            if symbol_key in self.latest:
                continue
            try:
                self.latest[symbol_key] = json.loads(payload)
            except Exception:
                pass

    def set_enabled(self, enabled: bool) -> dict[str, Any]:
        self.enabled = bool(enabled)
        with self._connect() as con:
            con.execute(
                "INSERT INTO detector_config(key,value) VALUES('enabled',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                ("1" if self.enabled else "0",),
            )
            con.commit()
        return self.status()

    def status(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "mode": "ALERT_ONLY",
            "auto_execution": False,
            "latest": list(self.latest.values()),
            "db_path": str(self.db_path),
        }

    def history(self, limit: int = 100, symbol_key: str | None = None) -> list[dict[str, Any]]:
        limit = max(1, min(int(limit), 500))
        with self._connect() as con:
            if symbol_key:
                rows = con.execute(
                    "SELECT payload_json FROM explosion_snapshots WHERE symbol_key=? ORDER BY ts DESC LIMIT ?",
                    (symbol_key, limit),
                ).fetchall()
            else:
                rows = con.execute(
                    "SELECT payload_json FROM explosion_snapshots ORDER BY ts DESC LIMIT ?", (limit,)
                ).fetchall()
        out: list[dict[str, Any]] = []
        for (payload,) in rows:
            try:
                out.append(json.loads(payload))
            except Exception:
                continue
        return out

    def evaluate_underlying(
        self,
        symbol_key: str,
        rows_1m: list[dict[str, Any]],
        rows_5m: list[dict[str, Any]],
        rows_15m: list[dict[str, Any]],
        *,
        vix: float | None = None,
    ) -> dict[str, Any]:
        now = time.time()
        if not self.enabled:
            return {
                "symbol_key": symbol_key,
                "timestamp": now,
                "state": "OFF",
                "score": 0,
                "reason": ["DETECTOR_OFF"],
                "trade_ready": False,
                "alert_only": True,
            }

        one = _clean(rows_1m)
        five = _clean(rows_5m)
        fifteen = _clean(rows_15m)
        if len(one) < 22 or len(five) < 13 or len(fifteen) < 13:
            return {
                "symbol_key": symbol_key,
                "timestamp": now,
                "state": "WATCH",
                "score": 0,
                "reason": ["WAITING_CONTEXT"],
                "context": {"1m": len(one), "5m": len(five), "15m": len(fifteen)},
                "trade_ready": False,
                "alert_only": True,
            }

        last = one[-1]
        hist = one[-21:-1]
        resistance = max(x["high"] for x in hist)
        support = min(x["low"] for x in hist)
        close = last["close"]
        trend_1m = _trend(one, 5, 13)
        trend_5m = _trend(five, 5, 13)
        trend_15m = _trend(fifteen, 5, 13)

        side: str | None = None
        if close > resistance:
            side = "BUY"
        elif close < support:
            side = "SELL"
        elif trend_5m in ("BUY", "SELL") and trend_15m == trend_5m:
            side = trend_5m

        reasons: list[str] = []
        score = 0
        if side and trend_5m == side and trend_15m == side:
            score += 15
            reasons.append("5M_15M_TREND")
        elif side and trend_5m == side:
            score += 8
            reasons.append("5M_TREND")
        else:
            reasons.append("HTF_NOT_ALIGNED")

        if side and trend_1m == side:
            score += 8
            reasons.append("1M_IMPULSE")

        breakout = (side == "BUY" and close > resistance) or (side == "SELL" and close < support)
        if breakout:
            score += 18
            reasons.append("STRUCTURE_BREAK")
        elif side:
            atr = _atr(one)
            if atr and ((side == "BUY" and resistance - close <= 0.35 * atr) or (side == "SELL" and close - support <= 0.35 * atr)):
                score += 8
                reasons.append("NEAR_STRUCTURE")

        atr = _atr(one)
        candle_range = max(0.0, last["high"] - last["low"])
        range_ratio = candle_range / atr if atr and atr > 0 else None
        if range_ratio is not None:
            if range_ratio >= 1.5:
                score += 12
                reasons.append("ATR_EXPANSION")
            elif range_ratio >= 1.0:
                score += 7
                reasons.append("RANGE_EXPANSION")

        vols = [x["volume"] for x in one[-21:-1] if x["volume"] > 0]
        volume_ratio: float | None = None
        if vols and last["volume"] > 0:
            avg_vol = fmean(vols)
            if avg_vol > 0:
                volume_ratio = last["volume"] / avg_vol
                if volume_ratio >= 1.5:
                    score += 10
                    reasons.append("VOLUME_SURGE")
                elif volume_ratio >= 1.15:
                    score += 6
                    reasons.append("VOLUME_CONFIRM")
        else:
            reasons.append("VOLUME_UNAVAILABLE")

        closes = [x["close"] for x in one]
        highs = [x["high"] for x in one]
        lows = [x["low"] for x in one]
        rsi = _rsi(closes)
        wr = _williams(highs, lows, closes)
        momentum_ok = False
        if side == "BUY" and rsi is not None and wr is not None and rsi >= 54 and wr >= -45:
            momentum_ok = True
        if side == "SELL" and rsi is not None and wr is not None and rsi <= 46 and wr <= -55:
            momentum_ok = True
        if momentum_ok:
            score += 7
            reasons.append("MOMENTUM")

        vix_change_pct: float | None = None
        if vix is not None and vix > 0 and self._last_vix and self._last_vix > 0:
            vix_change_pct = (vix - self._last_vix) / self._last_vix * 100.0
            if side == "SELL" and vix_change_pct >= 0.25:
                score += 5
                reasons.append("VIX_ACCELERATION")
            elif side == "BUY" and vix_change_pct <= -0.25:
                score += 3
                reasons.append("VIX_SUPPORT")
        if vix is not None and vix > 0:
            self._last_vix = vix

        score = min(score, 70)
        state = "WATCH" if score < 65 else "ARMED"
        return {
            "symbol_key": symbol_key,
            "timestamp": now,
            "state": state,
            "score": int(score),
            "side": side,
            "underlying": close,
            "trade_ready": False,
            "alert_only": True,
            "reason": reasons,
            "metrics": {
                "trend_1m": trend_1m,
                "trend_5m": trend_5m,
                "trend_15m": trend_15m,
                "resistance_1m": resistance,
                "support_1m": support,
                "atr14_1m": atr,
                "range_atr": range_ratio,
                "volume_ratio": volume_ratio,
                "rsi14_1m": rsi,
                "williams_r14_1m": wr,
                "vix": vix,
                "vix_change_pct": vix_change_pct,
            },
        }

    def finalize_with_option(self, base: dict[str, Any], option_result: dict[str, Any] | None) -> dict[str, Any]:
        result = dict(base)
        symbol_key = str(base.get("symbol_key") or "")
        score = int(base.get("score") or 0)
        reasons = list(base.get("reason") or [])
        selected = option_result.get("selected") if isinstance(option_result, dict) else None
        if not isinstance(selected, dict):
            reasons.append(str((option_result or {}).get("reason") or "OPTION_UNAVAILABLE"))
            result["reason"] = reasons
            result["state"] = "ARMED" if score >= 55 else "WATCH"
            self._persist(result)
            return result

        premium = _num(selected.get("ltp"))
        volume = _num(selected.get("volume"))
        oi = _num(selected.get("oi"))
        oi_change = _num(selected.get("oi_change"))
        bid, ask = _num(selected.get("bid")), _num(selected.get("ask"))
        iv = _num(selected.get("iv"))
        delta = _num(selected.get("delta"))
        gamma = _num(selected.get("gamma"))
        theta = _num(selected.get("theta"))
        vega = _num(selected.get("vega"))
        option_symbol = str(selected.get("trading_symbol") or "")
        token = str(selected.get("instrument_token") or "")

        mem = self.memory.setdefault(symbol_key, DetectorMemory())
        premium_change_pct: float | None = None
        volume_delta: float | None = None
        derived_oi_change: float | None = oi_change
        if premium is not None and premium > 0 and mem.last_premium and mem.last_premium > 0:
            premium_change_pct = (premium - mem.last_premium) / mem.last_premium * 100.0
            if premium_change_pct >= 8:
                score += 8
                reasons.append("PREMIUM_ACCELERATION")
            elif premium_change_pct >= 3:
                score += 4
                reasons.append("PREMIUM_MOMENTUM")
        if volume is not None and mem.last_volume is not None:
            volume_delta = max(0.0, volume - mem.last_volume)
            if volume_delta > 0:
                score += 4
                reasons.append("OPTION_VOLUME_DELTA")
        if oi is not None and mem.last_oi is not None and derived_oi_change is None:
            derived_oi_change = oi - mem.last_oi
        if derived_oi_change is not None:
            if derived_oi_change > 0:
                score += 5
                reasons.append("OI_BUILDUP")
            elif derived_oi_change < 0 and premium_change_pct is not None and premium_change_pct > 0:
                score += 2
                reasons.append("OI_UNWIND_WITH_PRICE")

        spread_pct: float | None = None
        if bid and ask and bid > 0 and ask >= bid:
            mid = (bid + ask) / 2.0
            spread_pct = (ask - bid) / mid * 100.0 if mid else None
            if spread_pct is not None and spread_pct <= 2.0:
                score += 4
                reasons.append("TIGHT_SPREAD")
            elif spread_pct is not None and spread_pct > 4.0:
                reasons.append("WIDE_SPREAD")
                score -= 8

        if gamma is not None and delta is not None:
            score += 4
            reasons.append("GAMMA_DATA")
        if iv is not None and delta is not None and 0.15 <= abs(delta) <= 0.85:
            score += 4
            reasons.append("IV_DELTA_VALID")
        if oi is not None and oi > 0:
            score += 3
            reasons.append("OI_PRESENT")
        if volume is not None and volume > 0:
            score += 2
            reasons.append("OPTION_LIQUIDITY")

        score = max(0, min(100, int(round(score))))
        state = "WATCH"
        if score >= 92:
            state = "EXPLOSION"
        elif score >= 80:
            state = "TRIGGERED"
        elif score >= 65:
            state = "ARMED"

        overextended = premium_change_pct is not None and premium_change_pct >= 35.0
        if overextended and (spread_pct is None or spread_pct > 2.5):
            state = "COOLDOWN"
            reasons.append("OVEREXTENDED_NO_CHASE")

        now = float(base.get("timestamp") or time.time())
        if state == "EXPLOSION":
            if (
                mem.had_explosion_at is not None
                and now - mem.had_explosion_at <= 2700
                and mem.cooled_after_explosion
                and premium_change_pct is not None
                and premium_change_pct >= 5.0
            ):
                state = "RE-EXPLOSION"
                reasons.append("SECOND_ACCELERATION")
            mem.had_explosion_at = now
            mem.cooled_after_explosion = False
        elif mem.had_explosion_at is not None and score < 75:
            mem.cooled_after_explosion = True

        if premium is not None and premium > 0:
            mem.peak_premium = premium if mem.peak_premium is None else max(mem.peak_premium, premium)
            mem.last_premium = premium
        if volume is not None:
            mem.last_volume = volume
        if oi is not None:
            mem.last_oi = oi
        mem.last_state = state

        result.update({
            "state": state,
            "score": score,
            "trade_ready": True,
            "reason": list(dict.fromkeys(reasons)),
            "option": {
                "trading_symbol": option_symbol,
                "instrument_token": token,
                "exchange_segment": selected.get("exchange_segment"),
                "option_type": selected.get("option_type"),
                "strike": selected.get("strike"),
                "expiry": selected.get("expiry") or (option_result or {}).get("expiry"),
                "premium": premium,
                "bid": bid,
                "ask": ask,
                "spread_pct": spread_pct,
                "volume": volume,
                "volume_delta": volume_delta,
                "oi": oi,
                "oi_change": derived_oi_change,
                "iv": iv,
                "delta": delta,
                "gamma": gamma,
                "theta": theta,
                "vega": vega,
                "greeks_source": selected.get("greeks_source"),
                "quality_score": selected.get("score"),
                "premium_change_pct": premium_change_pct,
            },
        })
        self._persist(result)
        return result

    def record_base(self, result: dict[str, Any]) -> dict[str, Any]:
        self._persist(result)
        return result

    def _persist(self, payload: dict[str, Any]) -> None:
        symbol_key = str(payload.get("symbol_key") or "UNKNOWN")
        self.latest[symbol_key] = payload
        option = payload.get("option") if isinstance(payload.get("option"), dict) else {}
        metrics = payload.get("metrics") if isinstance(payload.get("metrics"), dict) else {}
        with self._connect() as con:
            con.execute(
                """
                INSERT INTO explosion_snapshots(
                    ts,symbol_key,state,score,side,underlying,option_symbol,premium,oi,oi_change,volume,iv,delta,gamma,vix,payload_json
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    float(payload.get("timestamp") or time.time()),
                    symbol_key,
                    str(payload.get("state") or "WATCH"),
                    int(payload.get("score") or 0),
                    payload.get("side"),
                    _num(payload.get("underlying")),
                    option.get("trading_symbol"),
                    _num(option.get("premium")),
                    _num(option.get("oi")),
                    _num(option.get("oi_change")),
                    _num(option.get("volume")),
                    _num(option.get("iv")),
                    _num(option.get("delta")),
                    _num(option.get("gamma")),
                    _num(metrics.get("vix")),
                    json.dumps(payload, separators=(",", ":"), default=str),
                ),
            )
            con.commit()


explosion_detector = ExplosionDetector()
