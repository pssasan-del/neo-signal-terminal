#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/home/opc/neo_signal_terminal_stage15/neo_signal_terminal}"
cd "$ROOT"

echo '=== Git update ==='
git fetch origin main
git checkout main
git pull --ff-only origin main
printf 'HEAD: '; git rev-parse HEAD

cd backend

if [[ ! -f .env ]]; then
  echo 'ERROR: backend/.env missing. Restore your existing Kotak credentials and APP_API_TOKEN first.' >&2
  exit 1
fi

python3 -m py_compile app/main.py app/core/config.py app/services/broker.py app/services/instruments.py app/services/explosion_detector.py app/services/telegram_alerts.py

if [[ -x ./venv/bin/python ]]; then
  ./venv/bin/python -m pytest -q || true
fi

for k in TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID; do
  if ! grep -Eq "^${k}=.+" .env; then
    echo "WARNING: $k is not configured in backend/.env; Telegram will stay disabled until added."
  fi
done

systemctl --user restart neo-backend
sleep 4
systemctl --user status neo-backend --no-pager

echo
echo '=== Health ==='
curl -fsS http://127.0.0.1:8080/health || true
echo

echo 'R2 backend deployed. Login once with Kotak TOTP, then the app will reuse that live backend session while it remains valid.'
