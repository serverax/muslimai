# Owner Script PID Variable Fix Proof

Date: 2026-06-25T00:00:57Z
Branch: qa-security-hardening
Command: `pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk -SkipDockerBuild`

## Root cause
PowerShell automatic variable `$PID` is read-only. Using `$pid` as a `foreach` loop variable in `Stop-PortListener` caused:
`Cannot overwrite variable PID because it is read-only or constant.`

## Fix applied
Renamed loop variable from `$pid` to `$portPid` in `Stop-PortListener`:
`foreach ($portPid in Get-PortOwner $Port) { ... }`

Also restored Flutter web build/serve in `-BuildApk` flow (removed auto `-SkipFlutterWeb`).

## Proof results

| Step | Result |
|------|--------|
| Docker backend build | PASS (full run without -SkipDockerBuild) |
| Docker services | PASS |
| API health | HTTP 200 |
| GET /v1/features | HTTP 200 (count=25) |
| flutter analyze | PASS |
| flutter test | PASS (42 tests) |
| flutter build web | PASS |
| Port 8090 cleanup | PASS (no `$PID` overwrite error) |
| Web serve | http://localhost:8090/ via npx serve |
| curl http://localhost:8090/ | HTTP 200 |
| APK build | FAIL — No Android SDK (expected on cloud VM; owner Windows machine with Android Studio should PASS) |

## curl proof
```
curl http://localhost:8090/ → HTTP 200
curl http://127.0.0.1:28080/health → HTTP 200
```

## Web server
- Engine: npx serve
- Port cleanup used `$portPid` successfully
- No read-only `$PID` variable collision

## APK
- Build started for emulator API base http://10.0.2.2:28080/v1
- Failed: `[!] No Android SDK found` (real tooling limitation, not script bug)
