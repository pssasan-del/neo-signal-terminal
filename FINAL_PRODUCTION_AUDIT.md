# KING BRO TRADE — Final Production Candidate Audit

## Visual lock
- Obsidian black background with subtle crimson ambient glow.
- Heavy dark frosted glass cards, white high-contrast typography.
- Crimson primary/action/accent system; glow reserved for live/action emphasis.
- Raw cyan/teal design system replaced at theme level so all existing pages inherit the new palette.
- Account raw JSON is no longer rendered in the production UI.

## Signal / execution lock
- Signal generated timestamp is persisted (`created_at`) and rendered on cards and detail sheet.
- Signal lifecycle persists in SQLite across backend restart.
- Closed signals are blocked from fresh signal-order action.
- Stock signals can resolve missing broker metadata before opening the trade ticket.
- Protected signal trade uses execution intent + confirmation/risk gates.
- Spot index signals are not fabricated as tradable index orders. Automatic CE/PE contract selection remains broker-data dependent; no fake option contract is created.

## Session / reconnect lock
- Normal market websocket reconnect retains authenticated in-memory session and re-subscribes.
- Explicit logout requires confirmation.
- Account API responses containing Kotak `invalid session token` / `100022` now invalidate backend auth state and become a clean HTTP 401 `KOTAK_SESSION_EXPIRED` response.
- Mobile account panels no longer expose raw broker JSON/session errors.
- A genuinely expired Kotak session still requires a fresh supported login/TOTP; the app does not fake a month-long token.

## Persistence / scanner
- Candle-history DB is preserved by deployment scripts.
- Signal lifecycle DB is preserved by deployment scripts.
- Scanner A/B architecture and diagnostics retained from the master source.

## Verification completed here
- Python compile: PASS
- Backend pytest: 23/23 PASS
- Mobile UTF-8/NUL source check: PASS

## External gates still required
- GitHub Flutter Android compile.
- Live Oracle + Kotak authentication test.
- Live market signal -> broker contract -> protected order acknowledgement test.
