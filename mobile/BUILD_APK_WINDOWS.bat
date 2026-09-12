@echo off
setlocal
where flutter >nul 2>&1 || (echo Flutter not found. Install Flutter stable first.& pause & exit /b 1)
flutter create --platforms=android . || exit /b 1
flutter pub get || exit /b 1
flutter analyze || exit /b 1
flutter build apk --release || exit /b 1
echo.
echo APK READY: build\app\outputs\flutter-apk\app-release.apk
endlocal
pause
