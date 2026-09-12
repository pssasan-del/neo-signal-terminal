# LION BRO V5 — Funds + Logout Fix

- Portfolio tabs are now interactive: Positions / Holdings / Funds.
- Funds page reads `/portfolio/limits` and displays broker-supplied available cash/margin, used margin, collateral, exposure and total limit when present.
- Account menu on live Home now includes Logout.
- Logout asks for confirmation, calls `/auth/logout`, and returns to LION BRO login.
- No trading strategy or option-chain parser changes.
- Backend regression suite: 25/25 passed on five consecutive runs.
- Python backend compile: passed.
- Flutter SDK is not installed in this execution environment, so APK/EXE compilation is not claimed here; included CI/build scripts remain the final platform compile gate.
