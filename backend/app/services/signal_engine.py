from __future__ import annotations

from dataclasses import dataclass, asdict
from statistics import fmean
from typing import Any


@dataclass(slots=True)
class Signal:
    symbol_key: str
    side: str
    entry: float
    stop: float
    target1: float
    target2: float
    rr: float
    score: int
    reason: str
    timeframe_sec: int
    source: str = "king_bro_strongest_v3"
    target3: float | None = None
    rsi14: float | None = None
    williams_r14: float | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _ema(values: list[float], period: int) -> float | None:
    if len(values) < period:
        return None
    result = fmean(values[:period])
    k = 2.0 / (period + 1.0)
    for value in values[period:]:
        result = ((value - result) * k) + result
    return result


def _rsi(values: list[float], period: int = 14) -> float | None:
    if len(values) < period + 1:
        return None
    changes = [values[i] - values[i - 1] for i in range(1, len(values))][-period:]
    gains = [max(x, 0.0) for x in changes]
    losses = [max(-x, 0.0) for x in changes]
    avg_gain = fmean(gains)
    avg_loss = fmean(losses)
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100.0 - (100.0 / (1.0 + rs))


def _williams_r(highs: list[float], lows: list[float], closes: list[float], period: int = 14) -> float | None:
    if len(highs) < period:
        return None
    hh = max(highs[-period:])
    ll = min(lows[-period:])
    if hh <= ll:
        return None
    return -100.0 * ((hh - closes[-1]) / (hh - ll))


def _true_range_rows(rows: list[dict[str, float]]) -> list[float]:
    out: list[float] = []
    prev_close: float | None = None
    for row in rows:
        h, l, c = row["high"], row["low"], row["close"]
        tr = h - l if prev_close is None else max(h - l, abs(h - prev_close), abs(l - prev_close))
        out.append(max(0.0, tr))
        prev_close = c
    return out


def _clean(rows: list[dict[str, Any]]) -> list[dict[str, float]]:
    clean: list[dict[str, float]] = []
    for row in rows:
        try:
            clean.append({
                "open": float(row["open"]),
                "high": float(row["high"]),
                "low": float(row["low"]),
                "close": float(row["close"]),
                "volume": float(row.get("volume") or 0.0),
            })
        except Exception:
            continue
    return clean


class StrictSignalEngine:
    """KING BRO strongest rule-based engine.

    Primary decision is on a CLOSED 5-minute candle. A 15-minute trend confirmation is
    mandatory for production auto-scans once enough context exists. 4H and Daily context,
    when persisted, may confirm the setup but never fabricate history. Proper True Range ATR,
    breakout quality/retest, momentum, volume and overextension filters are used.
    """

    def __init__(self, min_rr: float = 1.85, lookback: int = 20, min_score: int = 82) -> None:
        self.min_rr = min_rr
        self.lookback = lookback
        self.min_score = min_score

    @staticmethod
    def _trend(rows: list[dict[str, Any]], fast: int, slow: int) -> str | None:
        c = _clean(rows)
        if len(c) < slow:
            return None
        closes = [x["close"] for x in c]
        ef, es = _ema(closes, fast), _ema(closes, slow)
        if ef is None or es is None:
            return None
        if ef > es and closes[-1] >= ef:
            return "BUY"
        if ef < es and closes[-1] <= ef:
            return "SELL"
        return "NEUTRAL"

    def evaluate_strongest(
        self,
        symbol_key: str,
        rows_5m: list[dict[str, Any]],
        *,
        rows_1m: list[dict[str, Any]] | None = None,
        rows_15m: list[dict[str, Any]] | None = None,
        rows_4h: list[dict[str, Any]] | None = None,
        rows_1d: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        base = self.evaluate(symbol_key, rows_5m, 300)
        if base.get("status") != "SIGNAL":
            return base
        sig = dict(base["signal"])
        side = str(sig["side"])
        score = int(sig.get("score") or 0)
        reasons = [x.strip() for x in str(sig.get("reason") or "").split("+") if x.strip()]

        # 15M confirmation is the key higher-timeframe guard. Use EMA5/13 so a persisted
        # two-to-four-hour history is enough; if not ready, explicitly wait rather than guess.
        tf15 = self._trend(rows_15m or [], 5, 13)
        if tf15 is None:
            return {"status": "REJECTED", "reason": "WAITING_15M_CONTEXT", "need": 13, "have": len(rows_15m or [])}
        if tf15 != side:
            return {"status": "REJECTED", "reason": "15M_TREND_CONFLICT", "trend_15m": tf15, "side": side}
        score += 10
        reasons.append("15M_TREND")

        # 1M is a micro-timing guard when enough data exists. Neutral is allowed; direct
        # opposition is rejected to avoid entering into an immediate counter impulse.
        tf1 = self._trend(rows_1m or [], 5, 13)
        if tf1 is not None:
            if tf1 not in (side, "NEUTRAL"):
                return {"status": "REJECTED", "reason": "1M_IMPULSE_CONFLICT", "trend_1m": tf1, "side": side}
            if tf1 == side:
                score += 3
                reasons.append("1M_IMPULSE")

        # 4H/Daily become active only after real persisted history exists. Never synthesize
        # these candles. A confirmed opposite trend vetoes the setup; matching trend adds score.
        for label, rows, fast, slow in (("4H", rows_4h or [], 3, 5), ("1D", rows_1d or [], 2, 3)):
            trend = self._trend(rows, fast, slow)
            if trend is None:
                continue
            if trend not in (side, "NEUTRAL"):
                return {"status": "REJECTED", "reason": f"{label}_TREND_CONFLICT", "trend": trend, "side": side}
            if trend == side:
                score += 2
                reasons.append(f"{label}_TREND")

        sig["score"] = min(100, score)
        sig["reason"] = " + ".join(dict.fromkeys(reasons))
        sig["source"] = "king_bro_strongest_v3"
        sig["confirmations"] = {
            "1m": tf1 or "NOT_READY",
            "5m": side,
            "15m": tf15,
            "4h": self._trend(rows_4h or [], 3, 5) or "NOT_READY",
            "1d": self._trend(rows_1d or [], 2, 3) or "NOT_READY",
        }
        return {"status": "SIGNAL", "signal": sig}

    def evaluate(self, symbol_key: str, rows: list[dict[str, Any]], timeframe_sec: int = 300) -> dict[str, Any]:
        need = max(self.lookback + 2, 24)
        if len(rows) < need:
            return {"status": "REJECTED", "reason": "INSUFFICIENT_HISTORY", "need": need, "have": len(rows)}

        clean = _clean(rows)
        if len(clean) < need:
            return {"status": "REJECTED", "reason": "INVALID_CANDLE_HISTORY"}

        history = clean[:-1]
        last = clean[-1]
        closes = [x["close"] for x in clean]
        highs = [x["high"] for x in clean]
        lows = [x["low"] for x in clean]
        previous = history[-self.lookback:]
        resistance = max(x["high"] for x in previous)
        support = min(x["low"] for x in previous)
        entry = last["close"]
        if entry <= 0:
            return {"status": "REJECTED", "reason": "INVALID_PRICE"}

        ema9, ema21 = _ema(closes, 9), _ema(closes, 21)
        rsi14 = _rsi(closes, 14)
        williams = _williams_r(highs, lows, closes, 14)
        tr = _true_range_rows(history)
        atr = fmean(tr[-14:]) if len(tr) >= 14 else 0.0
        if atr <= 0:
            return {"status": "REJECTED", "reason": "NO_VOLATILITY"}
        if ema9 is None or ema21 is None:
            return {"status": "REJECTED", "reason": "EMA_NOT_READY"}

        side: str | None = None
        if entry > resistance and ema9 > ema21:
            side = "BUY"
        elif entry < support and ema9 < ema21:
            side = "SELL"
        else:
            return {"status": "REJECTED", "reason": "NO_CONFIRMED_BREAKOUT"}

        # Weighted quality score; deliberately avoids the old saturation where most valid signals became 100.
        score = 45
        reasons = ["EMA_TREND"]
        score += 8

        if rsi14 is None:
            return {"status": "REJECTED", "reason": "RSI_NOT_READY"}
        if side == "BUY" and 55 <= rsi14 <= 76:
            score += 7; reasons.append("RSI")
        elif side == "SELL" and 24 <= rsi14 <= 45:
            score += 7; reasons.append("RSI")
        else:
            return {"status": "REJECTED", "reason": "RSI_NOT_CONFIRMED"}

        if williams is None:
            return {"status": "REJECTED", "reason": "WILLIAMS_NOT_READY"}
        if side == "BUY" and -55 <= williams <= -5:
            score += 6; reasons.append("WILLIAMS")
        elif side == "SELL" and -95 <= williams <= -45:
            score += 6; reasons.append("WILLIAMS")
        else:
            return {"status": "REJECTED", "reason": "WILLIAMS_NOT_CONFIRMED"}

        breakout_distance = entry - resistance if side == "BUY" else support - entry
        breakout_atr = breakout_distance / atr
        if breakout_atr <= 0:
            return {"status": "REJECTED", "reason": "BREAKOUT_NOT_CONFIRMED"}
        if breakout_atr > 1.15:
            return {"status": "REJECTED", "reason": "OVEREXTENDED"}

        # Strong candle quality + retest/proximity. A close just beyond the level is accepted;
        # a wider breakout must show a wick back toward the broken level.
        candle_range = max(1e-9, last["high"] - last["low"])
        body_ratio = abs(last["close"] - last["open"]) / candle_range
        if body_ratio < 0.35:
            return {"status": "REJECTED", "reason": "WEAK_BREAKOUT_CANDLE"}
        if side == "BUY":
            retested = last["low"] <= resistance + 0.35 * atr
            close_strength = (last["close"] - last["low"]) / candle_range
        else:
            retested = last["high"] >= support - 0.35 * atr
            close_strength = (last["high"] - last["close"]) / candle_range
        if breakout_atr > 0.55 and not retested:
            return {"status": "REJECTED", "reason": "WAITING_RETEST"}
        if close_strength < 0.58:
            return {"status": "REJECTED", "reason": "WEAK_CLOSE"}
        score += 8
        reasons.append("BREAKOUT_RETEST" if retested else "CLEAN_BREAKOUT")

        previous_volumes = [x["volume"] for x in history[-20:] if x["volume"] > 0]
        if previous_volumes and last["volume"] > 0:
            avg_volume = fmean(previous_volumes)
            ratio = last["volume"] / avg_volume if avg_volume > 0 else 0.0
            if ratio >= 1.15:
                score += 5; reasons.append("VOLUME")
            elif ratio < 0.75:
                return {"status": "REJECTED", "reason": "WEAK_VOLUME"}

        # Structure-aware stop with ATR floor. Do not let a tiny final candle create a fragile SL.
        if side == "BUY":
            structural = min(last["low"], min(x["low"] for x in clean[-3:]))
            stop = min(structural, entry - 0.85 * atr)
            stop = max(stop, entry - 1.60 * atr)
            risk = entry - stop
        else:
            structural = max(last["high"], max(x["high"] for x in clean[-3:]))
            stop = max(structural, entry + 0.85 * atr)
            stop = min(stop, entry + 1.60 * atr)
            risk = stop - entry

        if risk <= 0:
            return {"status": "REJECTED", "reason": "INVALID_RISK"}
        if risk / entry > 0.035:
            return {"status": "REJECTED", "reason": "RISK_OUT_OF_RANGE"}

        if side == "BUY":
            target1, target2, target3 = entry + self.min_rr*risk, entry + 2.30*risk, entry + 3.00*risk
        else:
            target1, target2, target3 = entry - self.min_rr*risk, entry - 2.30*risk, entry - 3.00*risk

        score = min(score, 100)
        if score < self.min_score:
            return {"status": "REJECTED", "reason": "SCORE_TOO_LOW", "score": score}

        sig = Signal(
            symbol_key=symbol_key, side=side, entry=round(entry, 4), stop=round(stop, 4),
            target1=round(target1, 4), target2=round(target2, 4), target3=round(target3, 4),
            rr=self.min_rr, score=score, reason=" + ".join(reasons), timeframe_sec=timeframe_sec,
            rsi14=round(rsi14, 2), williams_r14=round(williams, 2),
        )
        payload = sig.to_dict()
        payload["atr14"] = round(atr, 4)
        payload["ema9"] = round(ema9, 4)
        payload["ema21"] = round(ema21, 4)
        payload["breakout_atr"] = round(breakout_atr, 3)
        payload["candle_body_ratio"] = round(body_ratio, 3)
        return {"status": "SIGNAL", "signal": payload}


signal_engine = StrictSignalEngine()


class BaselineSignalEngine:
    """Compatibility baseline retained only for legacy tests/imports."""
    def __init__(self, min_rr: float = 1.85, lookback: int = 20) -> None:
        self.min_rr = min_rr; self.lookback = lookback

    def evaluate(self, symbol_key: str, rows: list[dict[str, Any]], timeframe_sec: int = 300) -> dict[str, Any]:
        if len(rows) < self.lookback + 2:
            return {"status": "REJECTED", "reason": "INSUFFICIENT_HISTORY", "need": self.lookback + 2, "have": len(rows)}
        clean=_clean(rows)
        if len(clean) < self.lookback + 2:
            return {"status":"REJECTED","reason":"INVALID_CANDLE_HISTORY"}
        last=clean[-1]; previous=clean[-(self.lookback+1):-1]
        resistance=max(x["high"] for x in previous); support=min(x["low"] for x in previous); entry=last["close"]
        if entry > resistance: side="BUY"; stop=last["low"]; risk=entry-stop
        elif entry < support: side="SELL"; stop=last["high"]; risk=stop-entry
        else: return {"status":"REJECTED","reason":"NO_CONFIRMED_BREAKOUT"}
        if risk <= 0: return {"status":"REJECTED","reason":"INVALID_RISK"}
        t1=entry+self.min_rr*risk if side=="BUY" else entry-self.min_rr*risk
        t2=entry+2.3*risk if side=="BUY" else entry-2.3*risk
        sig=Signal(symbol_key,side,round(entry,4),round(stop,4),round(t1,4),round(t2,4),self.min_rr,80,"baseline breakout",timeframe_sec)
        return {"status":"SIGNAL","signal":sig.to_dict()}
