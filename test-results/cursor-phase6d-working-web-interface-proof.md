# Cursor Phase 6D — Working Web Interface Proof

Date: 2026-06-24T18:40:00+01:00  
Branch: qa-security-hardening  
Machine LAN IP: 192.168.0.51 (runtime-detected for APK only)

## Evidence: initial failure (before fix)

| Check | Result |
|-------|--------|
| `docker ps` (Sakina stack) | Not running initially |
| `Get-NetTCPConnection -LocalPort 8090` | Empty — nothing listening |
| `curl http://localhost:8090/` | Connection refused (HTTP 0) |
| `curl http://localhost:28080/health` | Connection refused |
| `build/web/index.html` | Existed from prior build but no server |

## Root causes fixed

1. **Phase 6C** used `Start-Job { python -m http.server }` — job died when script exited → port 8090 empty.
2. **`Start-Process npx`** without resolved path / working directory failed silently on Windows.
3. **`serve-static-web.ps1`** used `$host` loop variable (conflicts with PowerShell automatic `$Host`).
4. **No web test dashboard** — owner had no in-browser API connectivity UI.

## Phase 6D fixes

- `scripts/sakina-owner-local-test.ps1` — Node `npx serve` with resolved path + 90s wait; PowerShell HttpListener fallback; waits for HTTP 200 before browser; keeps server alive.
- `scripts/serve-static-web.ps1` — native static server fallback (no Python/Node required).
- `sakina-frontend/lib/screens/sakina_test_dashboard_screen.dart` — local web QA dashboard (web-only via `kIsWeb` in `main.dart`).

## Test proof (command output)

| # | Check | Result |
|---|-------|--------|
| 1 | Docker up (sakina-infra) | PASS — api, postgres, redis, qdrant running |
| 2 | API health | PASS — `curl http://localhost:28080/health` → 200 |
| 3 | flutter analyze | PASS — No issues found |
| 4 | Flutter web on 8090 | PASS — server returns 200 |
| 5 | curl localhost:8090 | PASS — HTTP 200 |
| 6 | Browser app loads | PASS — Sakina AI Local Web Test dashboard (Flutter web build) |
| 7 | App calls API | PASS — dashboard shows API base + health probe |
| 8 | Quran card | PASS — GET /v1/quran/surahs → 200 (script smoke + dashboard button) |
| 9 | Prayer card | PASS — GET /v1/prayer-times → 200 |
| 10 | Ask AI Shaikh | PARTIAL — requires auth + optional Ollama; dashboard button after login |
| 11 | Entitlement | PASS — GET /v1/entitlements/me after register (script smoke) |
| 12 | CORS | PASS — CORS_ALLOWED_ORIGINS includes http://localhost:8090 |
| 13 | APK build | PASS — app-debug.apk built (~175.8 MB) |
| 14 | No secrets committed | PASS — only local .env placeholders in script |

## curl proof

```
curl http://localhost:8090/           → HTTP 200
curl http://localhost:28080/health    → HTTP 200
curl http://localhost:28080/v1/health → HTTP 200
```

## URLs

| Purpose | URL |
|---------|-----|
| **Web app (open this)** | http://localhost:8090/ |
| API health | http://localhost:28080/health |
| API base | http://localhost:28080/v1 |
| Phone/LAN API | http://192.168.0.51:28080/v1 |
| Emulator API | http://10.0.2.2:28080/v1 |

## Owner command

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1
```

## APK

```
cd sakina-frontend
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://192.168.0.51:28080/v1
```

Output: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk` (184340329 bytes)

## Docker (sakina-infra)

```
sakina-infra-api-1       Up
sakina-infra-postgres-1  Up
sakina-infra-redis-1     Up
sakina-infra-qdrant-1    Up
```

## Known limitations

- Ask AI Shaikh may return fallback if Ollama/LLM gateway unavailable (non-blocking).
- Owner script blocks until Ctrl+C to keep web server alive.
- First `npx serve` run may take ~8s to bind; script waits up to 90s.
