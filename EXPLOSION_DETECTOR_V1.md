# LION BRO — Explosion Detector V1

This release adds an **independent alert-only Explosion Detector**. It does not replace or alter the Normal Engine and it never submits orders.

## Data source

- Kotak Neo live market/index feed and quote/search APIs only.
- Underlying context: closed 1M, 5M and 15M candles built from real broker ticks.
- Option selection: nearest live broker-discovered index expiry and ATM/near-ATM contracts.
- Captured option fields when available: premium/LTP, bid, ask, spread, volume, OI, OI change, IV, Delta, Gamma, Theta and Vega.
- `greeks_source` is preserved. If the broker does not supply complete Greeks, the existing option-quality module may derive IV/Greeks with Black-Scholes from live premium/spot/strike/expiry and labels them `computed_black_scholes`.
- India VIX is optional confirmation. The core-instrument sync now also attempts to subscribe to India VIX; detector operation does not fail if VIX is unavailable.

## States

`OFF -> WATCH -> ARMED -> TRIGGERED -> EXPLOSION -> RE-EXPLOSION / COOLDOWN`

Initial thresholds are deliberately strict and are intended for replay/live tuning:

- `<65`: WATCH
- `65–79`: ARMED
- `80–91`: TRIGGERED
- `92+`: EXPLOSION
- RE-EXPLOSION requires a prior explosion, a cooldown/pullback period and renewed premium acceleration.
- COOLDOWN blocks late chasing when 1-minute premium acceleration is extremely vertical and liquidity/spread confirmation is poor.

## Snapshot storage

`backend/explosion_history.db` stores detector snapshots for replay/backtesting. When a directional setup begins developing, the detector captures the selected option's premium, volume, OI/ΔOI and Greeks on closed one-minute evaluations. Underlying-only WATCH snapshots are still stored when an option has not yet been resolved.

## API

- `GET /explosion/status`
- `POST /explosion/toggle` with `{ "enabled": true|false }`
- `GET /explosion/history?limit=100&symbol_key=...`
- `POST /options/chain/index` for the genuine compact index option chain used by the app.

`/app/bootstrap` also includes `explosion` status for the app Home screen.

## UI

Android and Windows use the same Flutter source and therefore the same bright LION BRO theme:

- cool white / pale-blue surfaces
- royal/navy blue structure
- electric-cyan live/momentum accents
- crimson reserved for SELL/risk/errors
- subtle pulse/glow motion on the detector rather than heavy animation

The Home screen contains a separate Explosion Detector ON/OFF control. The detailed detector screen shows score, state, underlying, premium, OI, ΔOI, IV, Delta, Gamma, Greeks source and VIX when available.
