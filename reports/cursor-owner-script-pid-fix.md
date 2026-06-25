# Owner Script PID Variable Fix

Date: 2026-06-25T00:00:57Z
Branch: qa-security-hardening

## Summary
Fixed `scripts/sakina-owner-local-test.ps1` failure when serving Flutter web on port 8090 during `-BuildApk` runs.

## Root cause
`Stop-PortListener` used `foreach ($pid in Get-PortOwner $Port)` — `$pid` collides with PowerShell's read-only `$PID` automatic variable.

## Fix
- Renamed loop variable to `$portPid`
- Re-enabled Flutter web diagnostic build/serve when `-BuildApk` is passed
- Added cross-platform port detection fallbacks (`fuser`/`ss` on Linux)
- Made `Start-BackgroundProcess` skip `-WindowStyle Hidden` on non-Windows PowerShell

## Owner command
```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

## Verified (cloud VM)
- Docker stack, API health, analyze, web build, port 8090 serve, HTTP 200
- APK fails only due to missing Android SDK (owner machine expected to succeed)
