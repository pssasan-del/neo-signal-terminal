# KING BRO TRADE — Strongest Strategy + Fresh UI

## Strategy engine: `king_bro_strongest_v3`
- Closed 5-minute setup is primary.
- EMA 9/21 direction.
- RSI 14 confirmation.
- Williams %R 14 confirmation.
- Proper True Range ATR (gap-aware), not only high-low average.
- 20-candle breakout.
- Breakout candle body/close-strength validation.
- Retest/proximity guard; rejects overextended breakouts and waits for retest where needed.
- Volume quality check when broker volume is available.
- Structure + ATR bounded stop.
- Minimum R:R 1:1.85; T2 2.30R; T3 3.00R.
- 15-minute trend confirmation is mandatory for production auto-scan once real history is available; no fabricated history.
- 1-minute immediate impulse conflict guard.
- Persisted 4H and Daily trend become active veto/bonus context when enough real candles exist.
- Production source now persists 1M, 3M, 5M, 15M, 4H and Daily candles.
- Option ranking keeps strict OI + Greeks + IV + spread + volume/liquidity validation from the previous consolidated build.

## Fresh UI
- Removed the previous dark cyan/robotic visual direction as the design baseline.
- New palette: pure white / pearl background, deep crimson red, charcoal typography, selective obsidian accents.
- High-contrast readable typography.
- Frosted white cards with soft depth and subtle crimson edge glow.
- Cleaner app bar and navigation treatment.
- Home, Signals, Scanner, Trade, Portfolio and Account inherit the same white/crimson design system.
- Holdings/Orders/Funds stay clean structured panels — no production raw JSON.
- Scanner strategy badges now reflect multi-timeframe / retest / ATR / OI+Greeks logic.

## Live trading
- Server live-order gate remains enabled in source/deploy configuration.
- Actual submission still requires authenticated Kotak session + Risk Gate ON + Execution ARMED + protected confirmation.

## Verification
- Python compile: PASS.
- Backend tests: 23/23 PASS.
- Flutter compiler is not installed in this build environment; APK compile must be accepted only after GitHub Actions reports green.
- Live Kotak option-chain field formats and real option premium/OI/Greeks must still be validated against the broker feed before calling production acceptance complete.
