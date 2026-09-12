from __future__ import annotations
from dataclasses import dataclass, asdict
from enum import Enum
from time import time
from typing import Any
from pathlib import Path
import sqlite3, uuid

class SignalState(str, Enum):
    WATCHING='WATCHING'; ACTIVE='ACTIVE'; ENTRY='ENTRY'; T1='T1'; T2='T2'; T3='T3'; SL='SL'; EXPIRED='EXPIRED'; CANCELLED='CANCELLED'

@dataclass(slots=True)
class TrackedSignal:
    id:str; symbol_key:str; side:str; entry:float; entry_low:float; entry_high:float; stop:float; target1:float; target2:float
    created_at:float; expires_at:float; state:SignalState=SignalState.ACTIVE; target3:float|None=None; score:int|None=None; rr:float|None=None
    reason:str|None=None; timeframe_sec:int=300; rsi14:float|None=None; williams_r14:float|None=None; last_price:float|None=None; updated_at:float|None=None
    trading_symbol:str|None=None; exchange_segment:str|None=None; instrument_token:str|None=None; generated_candle_at:float|None=None
    trade_ready:bool=False; option_status:str|None=None; underlying_symbol:str|None=None; option_type:str|None=None; strike:float|None=None; expiry:str|None=None
    option_ltp:float|None=None; option_bid:float|None=None; option_ask:float|None=None; option_volume:float|None=None; option_oi:float|None=None; option_oi_change:float|None=None
    option_iv:float|None=None; option_delta:float|None=None; option_gamma:float|None=None; option_theta:float|None=None; option_vega:float|None=None; option_quality_score:float|None=None; option_lot_size:float|None=None
    def to_dict(self)->dict[str,Any]:
        d=asdict(self); d['state']=self.state.value; return d

class SignalLifecycle:
    def __init__(self, db_path:Path|None=None)->None:
        self.items:dict[str,TrackedSignal]={}
        self.db_path=db_path or (Path(__file__).resolve().parents[2]/'data'/'signal_lifecycle.sqlite3')
        self.db_path.parent.mkdir(parents=True,exist_ok=True); self._init_db(); self._load()
    def _init_db(self):
        with sqlite3.connect(self.db_path) as c:
            c.execute('''CREATE TABLE IF NOT EXISTS signals (id TEXT PRIMARY KEY,payload TEXT NOT NULL,created_at REAL NOT NULL)'''); c.commit()
    def _save(self,s:TrackedSignal):
        import json
        with sqlite3.connect(self.db_path) as c:
            c.execute('INSERT OR REPLACE INTO signals(id,payload,created_at) VALUES(?,?,?)',(s.id,json.dumps(s.to_dict(),separators=(',',':')),s.created_at)); c.commit()
    def _load(self):
        import json
        with sqlite3.connect(self.db_path) as c: rows=c.execute('SELECT payload FROM signals ORDER BY created_at DESC LIMIT 500').fetchall()
        now=time()
        for (raw,) in rows:
            try:
                d=json.loads(raw); d['state']=SignalState(d.get('state','ACTIVE'))
                s=TrackedSignal(**d)
                if s.state not in {SignalState.T2,SignalState.T3,SignalState.SL,SignalState.EXPIRED,SignalState.CANCELLED} and now>s.expires_at:
                    s.state=SignalState.EXPIRED; s.updated_at=now; self._save(s)
                self.items[s.id]=s
            except Exception: pass
    def create(self,*,symbol_key:str,side:str,entry:float,stop:float,target1:float,target2:float,entry_tolerance_pct:float=.25,ttl_sec:int=1800,target3:float|None=None,score:int|None=None,rr:float|None=None,reason:str|None=None,timeframe_sec:int=300,rsi14:float|None=None,williams_r14:float|None=None,trading_symbol:str|None=None,exchange_segment:str|None=None,instrument_token:str|None=None,generated_candle_at:float|None=None,**extra)->dict[str,Any]:
        tol=abs(entry)*entry_tolerance_pct/100; now=time()
        trade_ready=bool(extra.get('trade_ready', bool(trading_symbol)))
        option_status=extra.get('option_status')
        initial_state=SignalState.ACTIVE if trade_ready or not extra.get('requires_tradable_contract', False) else SignalState.WATCHING
        s=TrackedSignal(
            uuid.uuid4().hex[:12],symbol_key,side.upper(),entry,entry-tol,entry+tol,stop,target1,target2,now,now+ttl_sec,initial_state,target3,score,rr,reason,timeframe_sec,rsi14,williams_r14,None,now,
            trading_symbol,exchange_segment,instrument_token,generated_candle_at,trade_ready,option_status,
            extra.get('underlying_symbol'),extra.get('option_type'),extra.get('strike'),extra.get('expiry'),
            extra.get('option_ltp'),extra.get('option_bid'),extra.get('option_ask'),extra.get('option_volume'),extra.get('option_oi'),extra.get('option_oi_change'),
            extra.get('option_iv'),extra.get('option_delta'),extra.get('option_gamma'),extra.get('option_theta'),extra.get('option_vega'),extra.get('option_quality_score'),extra.get('option_lot_size')
        )
        self.items[s.id]=s; self._save(s); return s.to_dict()
    def has_recent(self,symbol_key:str,side:str,within_sec:int=900)->bool:
        cutoff=time()-within_sec
        return any(x.symbol_key==symbol_key and x.side==side.upper() and x.created_at>=cutoff for x in self.items.values())
    def update_price(self,signal_id:str,price:float,now:float|None=None)->dict[str,Any]:
        s=self.items[signal_id]; now=now or time(); s.last_price=price; s.updated_at=now
        terminal={SignalState.T2,SignalState.T3,SignalState.SL,SignalState.EXPIRED,SignalState.CANCELLED}
        if s.state in terminal: self._save(s); return s.to_dict()
        if now>s.expires_at: s.state=SignalState.EXPIRED
        elif s.side=='BUY':
            if price<=s.stop:s.state=SignalState.SL
            elif s.target3 is not None and price>=s.target3:s.state=SignalState.T3
            elif price>=s.target2:s.state=SignalState.T2
            elif price>=s.target1:s.state=SignalState.T1
            elif s.entry_low<=price<=s.entry_high and s.state==SignalState.ACTIVE:s.state=SignalState.ENTRY
        else:
            if price>=s.stop:s.state=SignalState.SL
            elif s.target3 is not None and price<=s.target3:s.state=SignalState.T3
            elif price<=s.target2:s.state=SignalState.T2
            elif price<=s.target1:s.state=SignalState.T1
            elif s.entry_low<=price<=s.entry_high and s.state==SignalState.ACTIVE:s.state=SignalState.ENTRY
        self._save(s); return s.to_dict()
    def list(self,limit:int=100)->list[dict[str,Any]]:
        return [x.to_dict() for x in sorted(self.items.values(),key=lambda s:s.created_at,reverse=True)[:max(1,min(limit,500))]]
    def stats(self)->dict[str,Any]:
        rows=list(self.items.values()); counts={s.value:0 for s in SignalState}
        for x in rows: counts[x.state.value]=counts.get(x.state.value,0)+1
        terminal={SignalState.T2,SignalState.T3,SignalState.SL,SignalState.EXPIRED,SignalState.CANCELLED}
        scores=[x.score for x in rows if x.score is not None]
        return {'total':len(rows),'live':sum(x.state not in terminal for x in rows),'wins':sum(x.state in {SignalState.T1,SignalState.T2,SignalState.T3} for x in rows),'losses':sum(x.state==SignalState.SL for x in rows),'avg_score':round(sum(scores)/len(scores),1) if scores else None,'counts':counts}

signal_lifecycle=SignalLifecycle()
