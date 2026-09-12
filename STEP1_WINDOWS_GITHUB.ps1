$ErrorActionPreference = 'Stop'
$Source = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = 'D:\NEO_BUILD\neo_stage15\neo_signal_terminal'
if (!(Test-Path "$Repo\.git")) { throw "Git repo not found: $Repo" }
Copy-Item "$Source\mobile\lib\main.dart" "$Repo\mobile\lib\main.dart" -Force
Copy-Item "$Source\mobile\lib\king_bro_theme.dart" "$Repo\mobile\lib\king_bro_theme.dart" -Force
Copy-Item "$Source\mobile\lib\services\api_service.dart" "$Repo\mobile\lib\services\api_service.dart" -Force
Copy-Item "$Source\mobile\pubspec.yaml" "$Repo\mobile\pubspec.yaml" -Force
Copy-Item "$Source\.github\workflows\build-apk.yml" "$Repo\.github\workflows\build-apk.yml" -Force
Set-Location $Repo
git add mobile/lib/main.dart mobile/lib/king_bro_theme.dart mobile/lib/services/api_service.dart mobile/pubspec.yaml .github/workflows/build-apk.yml
git commit -m "V18 final integration: signal time, trade resolver, session guard, holographic UI"
git push
Write-Host "STEP 1 COMPLETE - V18 pushed; GitHub Actions build triggered."
