from __future__ import annotations
from dataclasses import dataclass, asdict
from typing import Any, Iterable
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
import math


def _num(v: Any) -> float | None:
    try:
        if v is None or v == "": return None
        return float(v)
    except (TypeError, ValueError):
        return None


def _first(d: dict[str, Any], names: Iterable[str]) -> Any:
    for n in names:
        if n in d and d[n] not in (None, ""):
            return d[n]
    return None


def flatten_records(payload: Any) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    def walk(x: Any) -> None:
        if isinstance(x, dict):
            keys = {str(k).lower() for k in x}
            markers = {"instrument_token", "instrumenttoken", "trading_symbol", "tradingsymbol", "p_symbol", "psymbol", "ptrdsymbol", "psymbolname", "pscriprefkey", "ltp", "last_traded_price", "strike_price", "strikeprice"}
            if keys & markers:
                out.append(x)
            for v in x.values():
                if isinstance(v, (dict, list, tuple)): walk(v)
        elif isinstance(x, (list, tuple)):
            for v in x: walk(v)
    walk(payload)
    seen=set(); unique=[]
    for r in out:
        sig=tuple(sorted((str(k), str(v)) for k,v in r.items() if not isinstance(v,(dict,list,tuple))))
        if sig not in seen:
            seen.add(sig); unique.append(r)
    return unique


def _norm_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def _norm_pdf(x: float) -> float:
    return math.exp(-0.5*x*x) / math.sqrt(2.0*math.pi)


def _expiry_years(raw: str | None) -> float | None:
    if not raw: return None
    txt=str(raw).strip()
    fmts=("%Y-%m-%d","%d-%m-%Y","%d/%m/%Y","%d%b%Y","%d-%b-%Y","%d %b %Y","%Y/%m/%d")
    dt=None
    for f in fmts:
        try:
            dt=datetime.strptime(txt, f).replace(tzinfo=timezone.utc)
            break
        except ValueError:
            pass
    if dt is None:
        try: dt=datetime.fromisoformat(txt.replace('Z','+00:00'))
        except Exception: return None
    # Indian derivatives expire at market close in IST. Date-only broker fields must not be
    # treated as UTC or an expired contract could remain selectable for several hours.
    ist=ZoneInfo("Asia/Kolkata")
    if dt.tzinfo is None:
        dt=dt.replace(tzinfo=ist)
    else:
        dt=dt.astimezone(ist)
    expiry_close=dt.replace(hour=15,minute=30,second=0,microsecond=0)
    seconds=(expiry_close-datetime.now(ist)).total_seconds()
    if seconds <= 0: return None
    return max(3600.0,seconds)/(365.0*24*3600.0)


def _bs_price(spot: float, strike: float, t: float, rate: float, vol: float, typ: str) -> float:
    if min(spot,strike,t,vol) <= 0: return 0.0
    sv=vol*math.sqrt(t)
    d1=(math.log(spot/strike)+(rate+0.5*vol*vol)*t)/sv
    d2=d1-sv
    disc=math.exp(-rate*t)
    if typ.upper()=="CE": return spot*_norm_cdf(d1)-strike*disc*_norm_cdf(d2)
    return strike*disc*_norm_cdf(-d2)-spot*_norm_cdf(-d1)


def _implied_vol(spot: float, strike: float, t: float, rate: float, premium: float, typ: str) -> float | None:
    if min(spot,strike,t,premium) <= 0: return None
    lo,hi=0.01,5.0
    plo=_bs_price(spot,strike,t,rate,lo,typ); phi=_bs_price(spot,strike,t,rate,hi,typ)
    if premium < plo-0.05 or premium > phi+0.05: return None
    for _ in range(70):
        mid=(lo+hi)/2
        px=_bs_price(spot,strike,t,rate,mid,typ)
        if px < premium: lo=mid
        else: hi=mid
    return (lo+hi)/2


def _bs_greeks(spot: float, strike: float, t: float, rate: float, vol: float, typ: str) -> dict[str,float] | None:
    if min(spot,strike,t,vol) <= 0: return None
    sv=vol*math.sqrt(t)
    d1=(math.log(spot/strike)+(rate+0.5*vol*vol)*t)/sv
    d2=d1-sv
    pdf=_norm_pdf(d1); disc=math.exp(-rate*t)
    if typ.upper()=="CE":
        delta=_norm_cdf(d1)
        theta=-(spot*pdf*vol)/(2*math.sqrt(t)) - rate*strike*disc*_norm_cdf(d2)
    else:
        delta=_norm_cdf(d1)-1.0
        theta=-(spot*pdf*vol)/(2*math.sqrt(t)) + rate*strike*disc*_norm_cdf(-d2)
    gamma=pdf/(spot*sv)
    vega=spot*pdf*math.sqrt(t)/100.0
    return {"delta":delta,"gamma":gamma,"theta":theta/365.0,"vega":vega}


@dataclass(slots=True)
class OptionCandidate:
    trading_symbol: str
    instrument_token: str
    exchange_segment: str
    option_type: str
    strike: float
    expiry: str | None = None
    ltp: float | None = None
    bid: float | None = None
    ask: float | None = None
    volume: float | None = None
    oi: float | None = None
    oi_change: float | None = None
    iv: float | None = None
    delta: float | None = None
    gamma: float | None = None
    theta: float | None = None
    vega: float | None = None
    greeks_source: str | None = None
    spread_pct: float | None = None
    distance_pct: float | None = None
    score: float = 0.0
    accepted: bool = False
    reasons: tuple[str, ...] = ()
    lot_size: float | None = None
    def to_dict(self) -> dict[str, Any]: return asdict(self)


class OptionSelector:
    """Production option quality filter: price + spread + OI + Greeks.

    Broker Greeks are used when supplied. Otherwise IV and Black-Scholes Greeks are computed
    from live premium, spot, strike and expiry; they are explicitly labelled as computed.
    """
    def __init__(self, *, max_spread_pct: float = 2.0, min_premium: float = 5.0,
                 max_premium: float = 1000.0, max_distance_pct: float = 5.0,
                 require_oi: bool = True, require_greeks: bool = False, risk_free_rate: float = 0.065) -> None:
        self.max_spread_pct=max_spread_pct; self.min_premium=min_premium; self.max_premium=max_premium
        self.max_distance_pct=max_distance_pct; self.require_oi=require_oi; self.require_greeks=require_greeks
        self.risk_free_rate=risk_free_rate

    def normalize(self, rec: dict[str, Any], *, fallback_segment: str="NSEFO", fallback_type: str="") -> OptionCandidate | None:
        token=str(_first(rec, ("instrument_token","instrumentToken","token","pSymbol","p_symbol","pToken","instrumenttoken")) or "")
        symbol=str(_first(rec, ("trading_symbol","tradingSymbol","symbol","pTrdSymbol","p_trd_symbol","pTradingSymbol","tradingsymbol")) or "")
        strike=_num(_first(rec, ("strike_price","strikePrice","strike","stkprc","pStrikePrice","dStrikePrice")))
        if not token or strike is None: return None
        raw_type=_first(rec,("option_type","optionType","optType","optt","pOptionType","optiontype"))
        if raw_type in (None, ""):
            upper_symbol=symbol.upper().replace(" ", "")
            if upper_symbol.endswith("CE"): raw_type="CE"
            elif upper_symbol.endswith("PE"): raw_type="PE"
        option_type=str(raw_type or fallback_type).upper()
        segment=str(_first(rec,("exchange_segment","exchangeSegment","segment","exchange_segment_name","pExchSeg")) or fallback_segment)
        expiry=_first(rec,("expiry","expiry_date","expiryDate","expdt","pExpiryDate","pExpiry","expirydate","expDate"))
        iv=_num(_first(rec,("iv","IV","implied_volatility","impliedVolatility","implied_vol","impliedVol")))
        if iv is not None and iv > 3: iv/=100.0
        c=OptionCandidate(
            symbol,token,segment,option_type,strike,str(expiry) if expiry else None,
            _num(_first(rec,("last_traded_price","ltp","lastPrice","last_price","lp","lastTradedPrice","pLTP","pLastTradedPrice"))),
            _num(_first(rec,("best_bid_price","bid","bidPrice","bp","bestBidPrice","pBidPrice"))),
            _num(_first(rec,("best_ask_price","ask","askPrice","sp","bestAskPrice","pAskPrice"))),
            _num(_first(rec,("volume_traded_today","volume","vol","v","totalTradedVolume","pVolume"))),
            _num(_first(rec,("open_interest","oi","openInterest","open_int","openinterest","pOpenInterest","pOI"))),
            _num(_first(rec,("oi_change","oiChange","change_in_oi","changeInOI","chgOi","changeInOpenInterest","pChangeInOI"))),
            iv,
            _num(_first(rec,("delta","option_delta"))),
            _num(_first(rec,("gamma","option_gamma"))),
            _num(_first(rec,("theta","option_theta"))),
            _num(_first(rec,("vega","option_vega"))),
            "broker" if any(_first(rec,(k,)) is not None for k in ("delta","gamma","theta","vega")) else None,
        )
        c.lot_size=_num(_first(rec,("lot_size","lotSize","minimum_lot_quantity","minimumLotQuantity","lot","ls")))
        return c

    def _fill_greeks(self, c: OptionCandidate, underlying_ltp: float) -> None:
        if all(v is not None for v in (c.delta,c.gamma,c.theta,c.vega)) and c.iv is not None:
            return
        t=_expiry_years(c.expiry)
        if t is None or c.ltp is None: return
        iv=c.iv or _implied_vol(underlying_ltp,c.strike,t,self.risk_free_rate,c.ltp,c.option_type)
        if iv is None: return
        g=_bs_greeks(underlying_ltp,c.strike,t,self.risk_free_rate,iv,c.option_type)
        if not g: return
        c.iv=iv
        c.delta=c.delta if c.delta is not None else g["delta"]
        c.gamma=c.gamma if c.gamma is not None else g["gamma"]
        c.theta=c.theta if c.theta is not None else g["theta"]
        c.vega=c.vega if c.vega is not None else g["vega"]
        c.greeks_source=c.greeks_source or "computed_black_scholes"

    def evaluate(self, c: OptionCandidate, underlying_ltp: float) -> OptionCandidate:
        reasons=[]
        self._fill_greeks(c,underlying_ltp)
        if underlying_ltp <= 0: reasons.append("INVALID_UNDERLYING_PRICE")
        else:
            c.distance_pct=abs(c.strike-underlying_ltp)/underlying_ltp*100
            if c.distance_pct > self.max_distance_pct: reasons.append("STRIKE_TOO_FAR")
        if c.ltp is None: reasons.append("MISSING_LTP")
        elif not (self.min_premium <= c.ltp <= self.max_premium): reasons.append("PREMIUM_OUT_OF_RANGE")
        if c.bid is not None and c.ask is not None and c.bid > 0 and c.ask >= c.bid:
            mid=(c.ask+c.bid)/2; c.spread_pct=(c.ask-c.bid)/mid*100 if mid else None
            if c.spread_pct is not None and c.spread_pct > self.max_spread_pct: reasons.append("SPREAD_TOO_WIDE")
        else: reasons.append("SPREAD_UNAVAILABLE")
        if c.oi is None: reasons.append("OI_UNAVAILABLE")
        elif c.oi <= 0: reasons.append("OI_ZERO")
        if c.iv is None or any(x is None for x in (c.delta,c.gamma,c.theta,c.vega)):
            reasons.append("GREEKS_UNAVAILABLE")
        elif not (0.01 <= c.iv <= 5.0): reasons.append("IV_OUT_OF_RANGE")
        elif c.option_type=="CE" and not (0.05 <= c.delta <= 0.95): reasons.append("DELTA_OUT_OF_RANGE")
        elif c.option_type=="PE" and not (-0.95 <= c.delta <= -0.05): reasons.append("DELTA_OUT_OF_RANGE")

        score=100.0
        if c.distance_pct is not None: score -= min(30.0,c.distance_pct*6)
        if c.spread_pct is not None: score -= min(35.0,c.spread_pct*10)
        else: score -= 15.0
        if c.volume is None: score -= 5.0
        elif c.volume <= 0: score -= 15.0
        if c.oi is None: score -= 15.0
        elif c.oi <= 0: score -= 20.0
        if c.iv is None: score -= 10.0
        if c.delta is None: score -= 10.0
        elif 0.30 <= abs(c.delta) <= 0.70: score += 5.0
        hard={"INVALID_UNDERLYING_PRICE","STRIKE_TOO_FAR","MISSING_LTP","PREMIUM_OUT_OF_RANGE","SPREAD_TOO_WIDE","IV_OUT_OF_RANGE","DELTA_OUT_OF_RANGE"}
        if self.require_oi: hard |= {"OI_UNAVAILABLE","OI_ZERO"}
        if self.require_greeks: hard |= {"GREEKS_UNAVAILABLE"}
        c.accepted=not any(r in hard for r in reasons)
        c.reasons=tuple(reasons); c.score=round(max(0.0,min(100.0,score)),2)
        return c

    def rank(self, records: list[dict[str,Any]], *, underlying_ltp: float,
             option_type: str, fallback_segment: str="NSEFO") -> list[dict[str,Any]]:
        ranked=[]
        for rec in records:
            c=self.normalize(rec,fallback_segment=fallback_segment,fallback_type=option_type)
            if c and (not option_type or c.option_type in ("",option_type.upper())):
                ranked.append(self.evaluate(c,underlying_ltp))
        ranked.sort(key=lambda x:(not x.accepted,-x.score,x.distance_pct if x.distance_pct is not None else 999))
        return [x.to_dict() for x in ranked]

option_selector=OptionSelector(require_oi=True, require_greeks=False)
