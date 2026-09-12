# V16 Holographic Glass UI Rebuild

Target visual language locked to the supplied reference:
- deep teal / black background
- electric cyan primary glow
- holographic frosted glass panels
- silver-white translucent reflection layer
- magenta-red SELL surfaces
- strong bloom on key prices and actions
- sharper robotic panel geometry
- circuit/grid background retained

Home/Market structure rebuilt to follow the reference pattern:
1. NIFTY 50 + India accent + Nifty 50 / Sensex header
2. Large centered glowing NIFTY price hero
3. High / Low / Volume / market status data row
4. TICK-BY-TICK dual BUY/SELL glass cards
5. ORDER ACTION dual BUY LONG / SELL SHORT glass controls
6. Latest signal remains available below when present

Existing V15 behavior preserved:
- Kotak connectivity and reconnect heartbeat
- signals/scanner/45+45 logic
- persistent candles and signal lifecycle
- manual trade / option trade / orders / portfolio / account
- risk gate, execution arm, server live-order gate
- backend endpoints unchanged

Validation in this package:
- backend tests: 22/22 passed
- Dart UTF-8/NUL sanity: passed
- bracket/structure lexical check: passed
- Flutter APK compile still requires GitHub Actions or a Flutter SDK machine
