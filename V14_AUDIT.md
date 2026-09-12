# V14 stability audit

Fixed/covered:
- Signals stats 404 compatibility.
- Scanner A/B fixed at 45 + 45 with punctuation-aware symbol resolution.
- Scanner status exposes failed symbol names.
- Persisted closed-candle SQLite history retained across backend restarts.
- Candle storage diagnostics endpoint `/market/candle-storage`.
- Normal Manual Trade swipe now submits after one full swipe (no second dialog) when all gates are enabled.
- Trade gives exact blockers for Risk Gate OFF, Execution Disarmed, or Oracle Live Order Gate Locked.
- `/execution` exposes `live_orders_unlocked` and risk status to the app.
- Existing execution intent, risk preflight, duplicate protection, order reconciliation, cancel/modify, kill switch remain intact.

Still market-dependent, not a code error:
- No signal if strict setup does not qualify.
- Strategy readiness needs >=24 persisted closed 5-minute candles per active symbol.
- Kotak can reject an otherwise valid order for account/product/exchange/broker reasons; Orders screen is the source of truth.
