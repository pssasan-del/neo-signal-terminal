# V15 deep audit

## Fixed
1. Mobile websocket overload: scanner stock ticks are no longer streamed to the phone. Only core indices are throttled to 2 updates/sec each; backend still processes every scanner tick.
2. App websocket idle disconnect: server heartbeat every 15 seconds + mobile heartbeat handling.
3. False RECONNECT badge: Home now uses actual broker authentication/feed freshness, not only the UI websocket flag.
4. Scanner semantics: RESOLVED is no longer mislabeled as LIVE; status reports receiving-tick count and missing symbols.
5. Scanner start timeout: mobile allows 45 seconds for the 45-symbol resolve/subscription operation.
6. Resolver resilience: retries transient Kotak search failures; punctuation aliases remain for M&M / BAJAJ-AUTO.
7. Candle persistence preserved: candle_history.db is never included/overwritten by deployment.
8. Signal persistence added: lifecycle is stored in backend/data/signal_lifecycle.sqlite3 and survives backend restart/deploy.
9. Home/Signals consistency: historical T1/T2/T3/SL signals survive and can appear on Signals after restart.
10. Risk correctness: execution ignores client-supplied open-position/day-P&L values and uses server-side position summary.
11. Auto-exit safety: automated SL/target order submission now requires Risk ON + Execution ARMED + server live-order gate.
12. Manual trading UX: Trade screen shows RISK / ARM / SERVER gates and can enable the two app-side gates before swipe.
13. Option trade label corrected to SWIPE TO BUY OPTION.
14. /system/diagnostics added for one-shot scanner/candle/signal/session diagnostics.

## Important behavior
- A market-feed/websocket reconnect does not require TOTP while the running Kotak session remains valid.
- A backend process restart loses the SDK's in-memory authenticated session. V15 does not fake a month-long session or serialize undocumented SDK secrets; after a deliberate backend restart, login may be required.
- 24 persisted closed 5M candles make a symbol strategy-ready; a signal is still generated only if the strict setup passes.
- Underlying index signals (NIFTY/BANKNIFTY/SENSEX) are analysis signals. An index itself cannot be bought/sold as an equity; use the Options flow for CE/PE execution.

## Design recommendation
Recommended: **Pro Broker HUD** — keep the current navy/cyan identity but reduce decorative glow, use compact information-dense cards, semantic green/red only for direction/P&L, and keep execution controls within Trade. This is the safest design direction because it looks professional without hiding trading state behind animation.
Alternative A: **Clean Quant Terminal** — nearly flat dark UI, thin cyan borders, more tables/data, least decorative.
Alternative B: **Robotic Command Center** — stronger glow/radar styling, visually impressive but lower information density.
