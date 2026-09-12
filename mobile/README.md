# LION BRO — LOCKED UI BUILD

This source is the locked dark professional design based on the approved LION BRO preview.

## Important
- This is a real Flutter mobile-app source, not an HTML prototype.
- Current data is demo/mock data.
- No broker order is sent from this build.
- Kotak/API integration must be connected separately after UI approval.

## Build APK on Windows
1. Install Flutter stable + Android Studio.
2. In this folder run:
   flutter create --platforms=android .
   flutter pub get
   flutter analyze
   flutter build apk --release
3. APK output:
   build/app/outputs/flutter-apk/app-release.apk

## GitHub Actions
A workflow is included. Push the project to GitHub and run `Build Android APK` from Actions. It creates `lion-bro-release-apk` as an artifact.
