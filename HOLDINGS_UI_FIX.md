# Holdings / Account UI Fix

Changed the More > Account section so broker payloads are not rendered as raw JSON in the production UI.

## Fixed
- Holdings now render as clean holding cards with symbol, quantity, average price, LTP, invested value, current value and P&L.
- Holdings summary shows total invested, current value, overall P&L and day P&L when available.
- Orders now render as compact broker order rows rather than JSON.
- Funds / Limits now render recognised balances as clean metrics rather than JSON.
- Trade Journal now renders recent entries as compact rows rather than JSON.
- Unknown/missing holdings return a clean empty state instead of a JSON dump.

## Notes
- Parsing supports multiple common Kotak/broker field-name variants because response field names can differ by endpoint/version.
- No fake values are generated. Missing fields are shown as `--`.
- Backend Python compile check passed.
- Flutter SDK is not installed in this environment, so the mobile app must still pass the GitHub Actions Flutter build before production install.
