# KING BRO TRADE V18 — integrated fix build

This package supersedes V14/V15/V16/V17.

## Fixed / hardened
- Signal cards show exact generated local time from persisted `created_at` plus lifecycle state.
- Closed T2/T3/SL/expired signals remain history and cannot accidentally open a fresh order.
- Scanner stock signals persist exact Kotak trading symbol, exchange segment and token.
- Old stock signals can resolve/backfill their broker contract on demand before opening Trade This Signal.
- Spot index signals are never submitted as fake cash orders; the app tells the user to choose a tradable Future/Option contract.
- Signal lifecycle survives backend restart in SQLite.
- Closed 5-minute candle history survives backend restart in SQLite.
- Market websocket reconnects/resubscribes without intentional logout/TOTP while the SDK session remains valid.
- Manual Logout now requires explicit confirmation; a normal reconnect never logs out.
- V15 scanner throttling/readiness/45-stock resolution hardening retained.
- Holographic teal/cyan glass + magenta SELL visual system retained and tightened.

## Verified in this package
- Python compileall: PASS
- Backend pytest: 23/23 PASS
- Dart source: UTF-8, zero NUL bytes
- Mobile/backend route audit: all referenced routes present

## Important runtime boundary
A deliberate backend process restart destroys the Kotak SDK's in-memory authenticated client. Current code does not fabricate or persist undocumented broker credentials/tokens. One TOTP login can therefore be required after a backend deployment/restart. Ordinary websocket/mobile reconnects do not intentionally log out.

## Two deployment steps
1. `powershell -ExecutionPolicy Bypass -File .\STEP1_WINDOWS_GITHUB.ps1`
2. After GitHub Android build is green: `powershell -ExecutionPolicy Bypass -File .\STEP2_WINDOWS_ORACLE.ps1`
