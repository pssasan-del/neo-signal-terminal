# LION BRO Flutter Build Fix — 2026-09-12

This revision addresses the GitHub Dart parser failure reported against the merged Flutter app.

## Fixed
- Rebuilt the malformed OptionChainPage widget tree.
- Rebuilt Live Options page widget tree.
- Rebuilt live Watchlist, Signals, Scanner, Orders, Portfolio and Manual Trade UI blocks in structured Dart.
- Rebuilt malformed SignalCard and OrderCard widgets.
- Fixed LineChartPainter ternary numeric syntax (`? 0.06 : 0.0`).
- Kept the dark/red LION BRO locked design and roaring-lion assets.
- Preserved the backend API contract and manual execution intent -> explicit confirmation flow.
- Preserved the existing backend strategy/parser files; no trading strategy redesign was made.
- Consolidated GitHub APK build to one root workflow: `.github/workflows/build-apk.yml`.

## Validation performed here
- Backend pytest: 25/25 passed.
- Structural delimiter scan of `mobile/lib/main.dart`: balanced.
- Flutter/Android SDK is not installed in this execution environment, so local APK compilation is not claimed.
- The GitHub workflow performs the decisive `flutter analyze` and release APK build.
