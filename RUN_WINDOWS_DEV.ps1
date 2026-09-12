$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $root "mobile")

flutter config --enable-windows-desktop
if (-not (Test-Path "windows")) {
  flutter create --platforms=windows --project-name neo_signal_terminal .
}
flutter pub get

$token = $env:APP_API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
  $token = Read-Host "Enter APP_API_TOKEN"
}
flutter run -d windows --dart-define=APP_API_TOKEN=$token
