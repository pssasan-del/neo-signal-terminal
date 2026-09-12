# KING BRO TRADE — Consolidated Fix Audit

Build baseline: strongest strategy + Windows/Android adaptive source.

## Completed source fixes

1. **Full UI direction reset**
   - Pure white / deep crimson / obsidian professional brokerage palette.
   - Roaring-lion KING BRO hero asset added to Home.
   - Mobile bottom navigation reduced to 5 primary destinations; scanner remains available from Home and desktop rail.
   - Kill Switch changed to explicit danger-red styling.
   - Raw JSON panel removed from production Flutter source.

2. **Signal readability**
   - Internal keys such as `nse_cm|ULTRACEMCO` are cleaned for user display.
   - Market levels use consistent 2-decimal formatting.
   - Signal card separates direction/state, generated time, entry/SL/T1/T2, score/RR and tradability.
   - Option contract/premium/OI/Delta are surfaced directly when available.

3. **Signal scoring saturation**
   - Strongest strategy score weights rebalanced so valid signals do not trivially saturate at 100.
   - Minimum score raised to 82 with mandatory 15M confirmation retained.

4. **Strong strategy stack**
   - 5M breakout/retest primary setup.
   - EMA 9/21, RSI14, Williams %R14.
   - Proper True Range ATR.
   - Volume quality, weak-close and overextension guards.
   - 15M mandatory trend confirmation.
   - 1M opposite-impulse veto.
   - 4H/Daily context when real persisted candles are available.
   - Minimum R:R 1:1.85.

5. **Index -> option premium chain**
   - New broker-driven automatic index option resolver.
   - NIFTY: NSEFO / 50 strike step.
   - BANKNIFTY: NSEFO / 100 strike step.
   - SENSEX: BSEFO / 100 strike step.
   - BUY underlying setup resolves CE; SELL underlying setup resolves PE.
   - Nearest future expiry is discovered from broker instruments; no fabricated expiry.
   - Closest strikes are live-quoted and ranked.
   - Selected contract is subscribed to the market stream.

6. **OI + Greeks quality gate**
   - OI required.
   - OI change captured when broker supplies it.
   - IV, Delta, Gamma, Theta, Vega captured from broker or computed from live premium when possible.
   - Spread, volume, strike distance and premium range included in quality score.
   - Greeks are required by the production option selector.
   - Invalid/expired expiry parsing corrected to India market-close time (Asia/Kolkata).

7. **No fake tradable index signal**
   - Index signal without a resolved contract is created as `WATCHING`, `trade_ready=false`.
   - It cannot silently masquerade as an executable cash-index order.
   - On-demand `resolve-trade` now attempts the same live option-resolution chain.

8. **Correct option execution side**
   - Underlying SELL -> PE signal now means BUY the selected PE contract, not accidentally short the PE.
   - Stock SELL signals still submit SELL as intended.

9. **Option lot quantity**
   - Broker lot-size aliases are captured in option normalization.
   - Signal trade ticket defaults to resolved option lot size when supplied; otherwise 1 and requires user review.

10. **Trade-from-signal correctness**
    - Exact selected trading symbol, segment and token are persisted with the signal.
    - Trade ticket uses option live premium as reference when the signal is an option.
    - Closed signals remain non-tradable.

11. **Holdings false -100% fix**
    - Backend now enriches holdings with live broker LTP when instrument token is available.
    - Segment aliases are normalized for quote calls.
    - Missing LTP remains null / `PRICE_UNAVAILABLE`, never zero.
    - Portfolio P&L is hidden for unpriced holdings instead of displaying false -100% loss.
    - UI displays priced/unpriced count and `PRICE WAIT` state.

12. **Orders / Holdings / Funds presentation**
    - Production UI uses structured cards/rows rather than JSON dumps.
    - Raw `JsonPanel` widget removed.

13. **Session-expiry handling**
    - Broker replies containing invalid-session-token / Neo login-check failure now invalidate broker auth centrally.
    - Backend returns standardized `KOTAK_SESSION_EXPIRED` / `LOGIN_REQUIRED` 401.
    - Risk and execution arm are turned off on session-expiry error handler.
    - Flutter converts this into a readable `SESSION EXPIRED • Login to Kotak Neo again` message rather than raw JSON.
    - Ordinary WebSocket reconnect remains separate from broker logout.

14. **Scanner / persistence retained**
    - 45 + 45 scanner groups retained.
    - Candle SQLite persistence retained.
    - Signal lifecycle SQLite persistence retained.
    - Core indices remain always eligible for strategy evaluation.

15. **Real trading enabled by source/deploy**
    - `LIVE_ORDER_SUBMISSION_ENABLED=true` and required acknowledgement are set by the Oracle deploy script.
    - Risk Gate + Execution Arm + one-time confirmation token remain mandatory before actual order submission.

16. **Windows + Android**
    - Same Flutter source remains adaptive for mobile and desktop.
    - Desktop navigation rail retained; mobile gets compact primary navigation.
    - Same Oracle backend is used by both clients.

## Verification completed here

- Python compile: PASS.
- Backend tests: **25/25 PASS**.
- New regression tests cover non-tradable index WATCHING state and option lot-size normalization.

## Live acceptance gates still required

These depend on a real authenticated Kotak market session and cannot be truthfully certified offline:

1. Kotak broad derivatives search must return expiry/strike records in the exact production account response format.
2. NIFTY/BANKNIFTY/SENSEX option quote must expose usable OI and live premium; otherwise signal remains non-tradable by design.
3. GitHub Actions / local Flutter toolchain must compile the Android and Windows clients.
4. First live-order acceptance test should use minimum permitted quantity after Risk Gate + Execution Arm are intentionally enabled.

A build is not production-accepted until these live gates pass.
