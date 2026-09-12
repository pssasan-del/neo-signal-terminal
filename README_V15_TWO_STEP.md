# V15 — two-step completion candidate

Do not deploy the old V14 first. Use V15 only.

## Step 1 — Windows / GitHub mobile
Open PowerShell in this folder:

```powershell
powershell -ExecutionPolicy Bypass -File ".\STEP1_WINDOWS_GITHUB.ps1"
```

Wait for GitHub Actions `Build Android APK` to turn green before installing the APK.

## Step 2 — Oracle backend
After the APK build is green:

```powershell
powershell -ExecutionPolicy Bypass -File ".\STEP2_WINDOWS_ORACLE.ps1"
```

The Oracle deploy script does **not** overwrite `.env`, `candle_history.db`, or persisted signal data. It creates a backup, runs Python compile + tests, restarts the backend, and prints candle/signal counts.

After a deliberate backend restart, Kotak TOTP may be required because the official SDK client session is held in process memory. Ordinary app/websocket reconnects do not log out the broker session.
