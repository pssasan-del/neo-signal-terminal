# KING BRO TRADE V17

Use only these two deployment steps:

1. `powershell -ExecutionPolicy Bypass -File .\STEP1_WINDOWS_GITHUB.ps1`
2. After GitHub Actions APK build is green: `powershell -ExecutionPolicy Bypass -File .\STEP2_WINDOWS_ORACLE.ps1`

The Oracle deploy script preserves `.env`, candle-history storage and persisted signal data as documented in the V15 deep-fix base.

V17 adds the native holographic visual pass without replacing broker/scanner logic with mock data.
