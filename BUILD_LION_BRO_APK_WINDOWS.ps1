$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot\mobile"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter not found in PATH.' }
flutter create --platforms=android .
$manifest = 'android\app\src\main\AndroidManifest.xml'
$text = Get-Content $manifest -Raw
if ($text -notmatch 'android.permission.INTERNET') {
  $text = $text.Replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', "<manifest xmlns:android=`"http://schemas.android.com/apk/res/android`">`r`n    <uses-permission android:name=`"android.permission.INTERNET`"/>")
}
if ($text -notmatch 'usesCleartextTraffic') {
  $text = $text.Replace('<application', '<application android:usesCleartextTraffic="true"')
}
Set-Content $manifest $text -Encoding UTF8
flutter pub get
flutter analyze
flutter build apk --release --dart-define=LION_BRO_API_URL=http://129.154.35.105:8080
Write-Host "APK: mobile\build\app\outputs\flutter-apk\app-release.apk"
