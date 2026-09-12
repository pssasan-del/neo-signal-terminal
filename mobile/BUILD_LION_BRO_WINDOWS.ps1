$ErrorActionPreference = 'Stop'
Write-Host '=== LION BRO Windows Desktop Build ===' -ForegroundColor Cyan
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter SDK not found in PATH.' }
flutter config --enable-windows-desktop
if (-not (Test-Path 'windows')) { flutter create --platforms=windows . }
if (Test-Path 'windows_assets\app_icon.ico') { Copy-Item 'windows_assets\app_icon.ico' 'windows\runner\resources\app_icon.ico' -Force }
$mainCpp='windows\runner\main.cpp'
if (Test-Path $mainCpp) { (Get-Content $mainCpp -Raw).Replace('L"lion_bro"','L"LION BRO"') | Set-Content $mainCpp -Encoding UTF8 }
flutter pub get
flutter analyze
flutter test
flutter build windows --release
$release='build\windows\x64\runner\Release'
if (-not (Test-Path $release)) { $release='build\windows\runner\Release' }
if (-not (Test-Path $release)) { throw 'Windows release folder not found.' }
$exe=Get-ChildItem $release -Filter '*.exe' | Select-Object -First 1
if (-not $exe) { throw 'Built EXE not found.' }
Rename-Item $exe.FullName 'LION BRO.exe' -Force
Write-Host "READY: $release\LION BRO.exe" -ForegroundColor Green
Write-Host 'Keep the EXE together with the data folder and DLL files in the Release folder.'
