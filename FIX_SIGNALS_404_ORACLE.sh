#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/neo_signal_terminal_stage15/neo_signal_terminal/backend"
MAIN="$ROOT/app/main.py"
cd "$ROOT"
cp "$MAIN" "$MAIN.before_signals_stats_$(date +%Y%m%d_%H%M%S)"
python - <<'PY'
from pathlib import Path
p=Path('app/main.py')
s=p.read_text()
if '@app.get("/signals/stats")' not in s:
    marker='@app.get("/signals/lifecycle")\nasync def lifecycle_list(): return signal_lifecycle.list()\n'
    route='''@app.get("/signals/lifecycle")\nasync def lifecycle_list(): return signal_lifecycle.list()\n\n@app.get("/signals/stats")\nasync def lifecycle_stats():\n    rows = signal_lifecycle.list()\n    terminal = {"T2", "T3", "SL", "EXPIRED", "CANCELLED"}\n    live = sum(1 for x in rows if str(x.get("state", "ACTIVE")).upper() not in terminal)\n    wins = sum(1 for x in rows if str(x.get("state", "")).upper() in {"T1", "T2", "T3"})\n    losses = sum(1 for x in rows if str(x.get("state", "")).upper() == "SL")\n    scored = [float(x["score"]) for x in rows if x.get("score") is not None]\n    return {\n        "total": len(rows),\n        "live": live,\n        "wins": wins,\n        "losses": losses,\n        "avg_score": round(sum(scored) / len(scored), 1) if scored else None,\n    }\n'''
    if marker not in s:
        raise SystemExit('Signals lifecycle route marker not found; no change made.')
    p.write_text(s.replace(marker, route, 1))
    print('ADDED /signals/stats')
else:
    print('/signals/stats already exists')
PY
source venv/bin/activate
python -m py_compile app/main.py
systemctl --user restart neo-backend
sleep 2
systemctl --user is-active neo-backend
python - <<'PY'
from app.main import app
paths={getattr(r,'path',None) for r in app.routes}
assert '/signals/stats' in paths
assert '/signals/lifecycle' in paths
print('SIGNALS ROUTES OK')
PY
