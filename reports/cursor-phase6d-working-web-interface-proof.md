# Cursor Phase 6D — Working Web Interface Repair Report

## Summary

Phase 6C left **nothing listening on port 8090** after the PowerShell script exited. Phase 6D delivers a working owner workflow: one command starts Docker API on **28080**, builds/serves Flutter web on **8090**, waits for **HTTP 200**, opens the browser, and keeps the static server alive.

## Root cause

| Symptom | Cause |
|---------|-------|
| `curl localhost:8090` → connection refused | No persistent static server |
| Owner saw blank/failed page | Browser opened to dead port or API URL (`/v1`) instead of web app |
| Phase 6C script “completed” but 8090 dead | `Start-Job { python -m http.server }` terminated with parent session |

## Fix details

### `scripts/sakina-owner-local-test.ps1` (Phase 6D)

- Resolves `npx` path via `Get-Command`; sets `-WorkingDirectory` to `build/web`.
- Falls back to `scripts/serve-static-web.ps1` (HttpListener) if Node fails.
- Waits up to **90 seconds** for `http://localhost:8090/` → 200 before opening browser.
- Writes proof to `test-results/` and `reports/`.
- **Blocks on web server PID** until Ctrl+C (server stays up).

### `scripts/serve-static-web.ps1`

- PowerShell-native static file server (SPA fallback to `index.html`).
- Fixed `$Host` variable collision (renamed loop variable to `$bindHost`).

### Flutter web dashboard

- `lib/screens/sakina_test_dashboard_screen.dart` — connectivity cards + 10 test actions.
- `lib/main.dart` — `kIsWeb` routes to dashboard; mobile APK flow unchanged.

## Owner instructions

See `docs/sakina-local-web-testing-runbook.md`.

**Open:** http://localhost:8090/  
**Not:** http://localhost:28080/v1 (API prefix only)

## Verification commands

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1
curl http://localhost:8090/
curl http://localhost:28080/health
```

Proof log: `test-results/cursor-phase6d-working-web-interface-proof.md`
