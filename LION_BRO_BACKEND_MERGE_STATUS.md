# LION BRO + existing backend merge

## Preserved without strategy changes
- Existing FastAPI backend copied from the uploaded `neo-signal-terminal-main(2).zip`.
- Existing signal engine, option resolver/parser, scanner, risk engine, execution engine, positions, journal and broker services are not redesigned by this merge.
- Backend direct `/orders/place` remains disabled. Mobile manual trading uses the existing two-step `/execution/intent` -> explicit `/execution/{intent_id}/confirm` flow.
- No fake LTP/OI is injected by the mobile merge. Missing live values render as `--`.

## LION BRO Flutter UI now wired to backend
- Kotak TOTP login -> `/auth/login`
- Home/bootstrap -> `/app/bootstrap`
- WebSocket state/ticks -> `/ws/ticks`
- Watchlist/live ticks -> `/market/latest`
- Signals -> `/signals/lifecycle`
- Scanner status/start/stop -> `/scanner/status`, `/scanner/start`, `/scanner/stop`
- Orders -> `/orders`
- Portfolio positions -> `/portfolio/positions/live`
- Holdings -> `/portfolio/holdings`
- Limits/funds -> `/portfolio/limits`
- Manual order preparation/confirmation -> `/execution/intent` + `/execution/{intent_id}/confirm`
- Live option cards use already-resolved option metadata from signal lifecycle. Existing backend parser is preserved.

## APK build
- GitHub Actions workflow: `.github/workflows/build-lion-bro-apk.yml`
- Windows script: `BUILD_LION_BRO_APK_WINDOWS.ps1`
- Android INTERNET permission + cleartext HTTP support are added during scaffold generation because the current backend default is an HTTP Oracle IP.
- Production recommendation: move backend to HTTPS and then remove cleartext HTTP allowance.

## Validation performed here
- `python -m compileall -q app` -> PASS
- backend `pytest -q` -> **25 passed**
- Flutter/Android SDK is not installed in this execution environment, therefore APK compilation is **not claimed as tested here**. GitHub Actions is the intended compile gate.

## Secrets
No broker passwords/TOTP seeds are added to the Flutter app. Keep Kotak/API secrets in the backend/server environment only.
