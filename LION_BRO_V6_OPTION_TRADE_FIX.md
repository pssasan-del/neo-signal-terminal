# LION BRO V6 — Option Contract → Trade Flow Fix

- Live Option Chain cards are now interactive.
- Tap contract -> Contract Details.
- BUY / SELL available directly on each contract and on Contract Details.
- Trade ticket is prefilled with trading symbol, genuine option LTP, exchange segment and BUY/SELL side.
- Trade ticket still uses existing backend execution intent -> explicit confirmation flow.
- No synthetic option premium is created; trade is blocked if a valid symbol/LTP is unavailable.
- Existing backend strategy and option resolver/parser were not redesigned.
- Backend pytest: 25/25 PASS, repeated 5 consecutive runs.
- Python compile: PASS.
- Dart/Flutter SDK unavailable in this environment, so APK/EXE compile is not claimed; GitHub build remains the platform compiler gate.
