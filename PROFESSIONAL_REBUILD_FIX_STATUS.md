# KING BRO TRADE — Professional Rebuild Fix Status

This rebuild addresses the current production complaints instead of adding another visual skin.

## Fixed in this source

1. Professional bright brokerage UI
   - Removed candy/neon/pink-glow presentation from the active design system.
   - Bright neutral background, white data cards, restrained crimson brand accent, dark high-contrast text.
   - Smaller radii, thinner borders, subtle shadows and denser information layout.
   - Roaring-lion art is retained as a controlled Home hero only.

2. Home page length / scrolling
   - Removed redundant giant NIFTY hero + tick cards + repeated action sections.
   - Home is now compact: hero, three live indices, quick actions, latest qualified signal.
   - Long lists such as Signals/Holdings still scroll normally because they are data lists.

3. Holdings price wait
   - Holdings enrichment now resolves a missing cash token by symbol when possible.
   - Quote extraction recognises additional Neo response aliases.
   - If live quote is still unavailable but broker previous-close is present, it is shown explicitly as PREV CLOSE instead of a fake live price.
   - No false -100% P&L is produced when price is genuinely unavailable.

4. Index option premium signal reliability
   - Option normaliser accepts more Kotak/Neo field aliases for token, symbol, strike, expiry, LTP, bid/ask, volume and OI.
   - CE/PE can be inferred from the broker trading symbol when the API omits a dedicated option-type field.
   - OI remains mandatory for an accepted contract.
   - Greeks are checked and computed when possible; missing Greeks lower quality instead of permanently blocking every otherwise-valid liquid option.
   - IMPORTANT: unresolved index signals are retried automatically every 30 seconds while the signal is alive. A transient broker search/quote failure no longer leaves the signal stuck in OPTION WAIT for the entire session.
   - When a retry resolves the contract, exact trading symbol/token/segment, premium, OI and Greeks are persisted and broadcast as option_ready.

5. Signal presentation
   - Internal broker keys remain cleaned for display.
   - Trade readiness and exact option failure reason are visible instead of a generic OPTION WAIT label.
   - Actual option contract is still required before index Trade-from-Signal can execute.

6. Live trading safety
   - Existing real-order server enablement is retained.
   - Kotak authentication, Risk Gate, Execution Arm and confirmation remain required before a real order is submitted.

## Verification completed here

- Python backend compile: PASS
- Backend automated tests: 25/25 PASS
- Source delimiter/bracket sanity check: PASS

## Still requires the real environment

- Flutter analyze/build must run in GitHub/Windows because Flutter SDK is not installed in this build container.
- Kotak live-session acceptance test is required for exact broker option/OI field behaviour and real LTP availability.
