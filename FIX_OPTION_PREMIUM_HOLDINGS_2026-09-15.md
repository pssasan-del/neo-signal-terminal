# LION BRO - Option Premium + Holdings Repair

Source: neo-signal-terminal-main(4).zip

## Root fixes
- Kotak Neo v2 exchange segment values corrected from legacy `NSEFO/BSEFO/NSECM/BSECM` to API-compatible `nse_fo/bse_fo/nse_cm/bse_cm` across backend option resolver/schema/pipeline and Flutter trade UI.
- Option records now canonicalize broker-returned segment aliases before quote calls, preventing a discovered contract from failing at the live-premium quote step because of segment spelling.
- Existing genuine option flow preserved: index signal -> CE for bullish / PE for bearish -> nearest expiry -> ATM-near strikes -> broker quote -> LTP/OI/liquidity filter -> resolved tradable contract. No fake premium is introduced.
- Holdings parser expanded for Neo response aliases including displaySymbol/securityName/scripName and multiple holding quantity aliases. Live quote enrichment remains enabled and missing prices remain null/marked PREV_CLOSE rather than fake zero.
- Remaining visible mojibake in Flutter UI cleaned.

## Verification completed here
- Python compile: PASS
- Backend pytest: 25/25 PASS
- No claim of live Kotak validation: requires authenticated market-hours broker session.
- No claim of Flutter compile in this container: Flutter SDK unavailable here.
