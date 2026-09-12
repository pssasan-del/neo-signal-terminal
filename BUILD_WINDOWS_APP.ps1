$ErrorActionPreference = "Stop"

Write-Host "KING BRO TRADE - Windows Builder" -ForegroundColor Red

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter not found. Install Flutter and Visual Studio Desktop development with C++." -ForegroundColor Yellow
  exit 1
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobile = Join-Path $root "mobile"
Set-Location $mobile

flutter config --enable-windows-desktop

if (-not (Test-Path "windows")) {
  Write-Host "Adding Windows desktop target..."
  flutter create --platforms=windows --project-name neo_signal_terminal .
}

flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings

$token = $env:APP_API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
  $token = Read-Host "Enter APP_API_TOKEN (same token used by Oracle backend)"
}
if ([string]::IsNullOrWhiteSpace($token)) {
  throw "APP_API_TOKEN is required."
}

flutter build windows --release --dart-define=APP_API_TOKEN=$token

$releaseDir = Join-Path $mobile "build\windows\x64\runner\Release"
$outDir = Join-Path $root "release\KING_BRO_TRADE_WINDOWS"
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Copy-Item "$releaseDir\*" $outDir -Recurse -Force

$zip = Join-Path $root "release\KING_BRO_TRADE_WINDOWS.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$outDir\*" -DestinationPath $zip -Force

Write-Host ""
Write-Host "BUILD COMPLETE" -ForegroundColor Green
Write-Host "App folder: $outDir"
Write-Host "ZIP: $zip"
Write-Host "Open neo_signal_terminal.exe inside the app folder." -ForegroundColor Cyan
