#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/neo_signal_terminal_stage15/neo_signal_terminal/backend"
SRC="$(cd "$(dirname "$0")" && pwd)/backend"
TS="$(date +%Y%m%d_%H%M%S)"
BK="$HOME/neo_final_backup_$TS"
mkdir -p "$BK"

# Back up current application code and .env; preserve runtime databases.
[ -d "$ROOT/app" ] && cp -a "$ROOT/app" "$BK/app"
[ -f "$ROOT/.env" ] && cp "$ROOT/.env" "$BK/.env"

# Replace application source only. Do not overwrite DBs or credentials.
rm -rf "$ROOT/app"
cp -a "$SRC/app" "$ROOT/app"

# User explicitly requested REAL orders enabled. Keep all credentials untouched.
# Risk Gate + Execution Arm + confirmation-token checks remain mandatory.
if [ -f "$ROOT/.env" ]; then
  grep -vE '^LIVE_ORDER_SUBMISSION_ENABLED=|^LIVE_ORDER_ACK=' "$ROOT/.env" > "$ROOT/.env.tmp" || true
  printf '\nLIVE_ORDER_SUBMISSION_ENABLED=true\nLIVE_ORDER_ACK=I_UNDERSTAND_REAL_ORDERS\n' >> "$ROOT/.env.tmp"
  mv "$ROOT/.env.tmp" "$ROOT/.env"
else
  printf 'LIVE_ORDER_SUBMISSION_ENABLED=true\nLIVE_ORDER_ACK=I_UNDERSTAND_REAL_ORDERS\n' > "$ROOT/.env"
fi

cd "$ROOT"
source venv/bin/activate
python -m compileall -q app
python -m pytest -q
systemctl --user restart neo-backend
sleep 3
systemctl --user is-active neo-backend
python - <<'PY2'
from app.services.market_pipeline import candles
from app.services.lifecycle import signal_lifecycle
from app.services.scanner import scanner_controller
from app.core.config import settings
from app.services.options import option_selector
print('CANDLE CLOSED 5M =', candles.storage_summary(300)['total_closed'])
print('PERSISTED SIGNALS =', signal_lifecycle.stats()['total'])
print('GROUP SIZE =', scanner_controller.groups()['count_each'])
print('LIVE ORDERS UNLOCKED =', settings.live_orders_unlocked)
print('OPTION OI REQUIRED =', option_selector.require_oi)
print('OPTION GREEKS REQUIRED =', option_selector.require_greeks)
PY2
printf '\nDEPLOY COMPLETE. Backup: %s\n' "$BK"
printf 'REAL ORDERS SERVER GATE IS ENABLED. Risk Gate + Execution Arm are still required before any order can submit.\n'
printf 'Backend restart requires Kotak login again if the broker SDK session cannot be restored.\n'
