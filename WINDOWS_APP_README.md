# KING BRO TRADE — Windows Desktop App

This package keeps the same Oracle/FastAPI backend used by the Android app and adds a responsive Windows desktop shell.

## Desktop UI behavior

- Width >= 900 px uses a left NavigationRail instead of the mobile bottom bar.
- Home, Signals, Scanner, Trade, Portfolio and More reuse the same live backend/API logic.
- Main content is centered with a 1380 px maximum width so the mobile layout does not stretch across a large monitor.
- The white + deep-crimson premium design system is shared with Android.

## Easiest build: GitHub Actions

1. Push this source to the existing private GitHub repository.
2. Keep repository secret `APP_API_TOKEN` set to the same bearer token expected by Oracle backend.
3. Open **Actions → Build Windows App → Run workflow**.
4. After the green build, download artifact **KING-BRO-TRADE-WINDOWS**.
5. Extract the ZIP and run `neo_signal_terminal.exe`.

Important: distribute/run the whole Release folder, not only the `.exe`, because Flutter Windows requires its DLL/data files.

## Local Windows build

Requirements:
- Flutter stable
- Visual Studio 2022 with **Desktop development with C++** workload
- Windows 10/11 SDK

From PowerShell in the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_APP.ps1
```

The script adds the Windows runner when absent, runs `flutter analyze`, builds Release, and creates:

`release\KING_BRO_TRADE_WINDOWS.zip`

## Architecture

`Kotak Neo API <-> Oracle FastAPI backend <-> Windows app + Android app`

Both clients use the same scanner, signal lifecycle, option-premium/OI/Greeks services, portfolio/account endpoints and protected real-order backend.
