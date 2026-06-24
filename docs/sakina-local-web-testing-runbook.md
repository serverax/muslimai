# Sakina — Local Web & LAN Testing Runbook (PHASE 6D)

Local beta testing only — **not** public production. Never marks LIVE_READY.

## One command (Windows — start here)

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1
```

This script (Phase 6D):

1. Verifies Docker is running
2. **Builds** `sakina-backend:latest` locally (Docker Hub does not host this image)
3. Starts the QA stack (`sakina-infra/docker-compose.qa.yml`)
4. Runs `sakina-migrate`
5. Waits for API health on **localhost:28080**
6. Runs `flutter analyze` and `flutter build web`
7. Serves `build/web` on **port 8090** (Node `npx serve`, or PowerShell HttpListener if Node missing)
8. **Waits for HTTP 200** on `http://localhost:8090/` before opening the browser
9. **Keeps the web server alive** until you press Ctrl+C

Git Bash / Linux:

```bash
chmod +x ./scripts/sakina-owner-local-test.sh
./scripts/sakina-owner-local-test.sh
```

Optional flags:

| Flag | Effect |
|------|--------|
| `-OpenFirewall` (PS) | Add inbound Windows firewall rule for TCP 28080 |
| `-BuildApk` (PS) / `--build-apk` (sh) | Also build debug APK with detected LAN API URL |
| `-SkipFlutterWeb` / `--skip-flutter-web` | API stack only (no Flutter build/serve) |
| `-SkipDockerBuild` | Skip `docker build` when image already exists |
| `-NoBrowser` | Do not auto-open browser |

Legacy wrapper: `pwsh ./scripts/sakina-local-web.ps1 -Web`

---

## Port map (Phase 6D)

| Service | Port | URL |
|---------|------|-----|
| **Flutter web app** | **8090** | `http://localhost:8090` — open this in your browser |
| **Sakina API** | **28080** | `http://localhost:28080/v1` (REST prefix, not a web page) |
| API health (JSON) | 28080 | `http://localhost:28080/health` or `/v1/health` |

**Common mistake:** opening `http://localhost:28080/v1` expecting the UI. Use port **8090** for the web app.

---

## Web test dashboard

On Flutter **web** builds, the app opens **Sakina AI — Local Web Test** with:

- API base URL and health status (PASS/FAIL chips)
- Test buttons: health, Quran, prayer, auth, Ask AI Shaikh, escalation, entitlements, CORS
- Links to subscription, scholar review, and all 25 feature screens

Mobile APK builds are unchanged (normal onboarding UI).

---

## Prerequisites

- **Docker Desktop** running
- **Flutter SDK** 3.16+ on PATH
- **Node.js** recommended (script uses `npx serve`; PowerShell fallback if Node missing)
- Same Wi-Fi for phone APK testing

First Docker build can take **10–20 minutes**. Later runs use cached images.

---

## Phone APK (LAN IP — detected at runtime, never hardcoded)

1. Run the owner script; note the printed **LAN API URL** (e.g. `http://192.168.1.42:28080/v1`).
2. Build/install:

```bash
cd sakina-frontend
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1
```

3. Output: `build/app/outputs/flutter-apk/app-debug.apk`
4. Phone and PC on the **same** Wi-Fi.

### Android emulator

Use the host loopback alias:

```bash
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1
```

---

## Troubleshooting

### Nothing on http://localhost:8090 (connection refused)

**Phase 6C root cause:** Python `http.server` in a background job exited when the script ended.

**Phase 6D fix:** Node `npx serve` or `scripts/serve-static-web.ps1` (HttpListener), PID kept alive until Ctrl+C.

Check:

```powershell
Get-NetTCPConnection -LocalPort 8090 -State Listen
curl -v http://localhost:8090/
Get-Content test-results/.sakina-web-server.pid
```

### Docker is not running

Start **Docker Desktop**, wait until Running, re-run the script.

### API health fails

```bash
docker compose -f sakina-infra/docker-compose.qa.yml logs api
curl http://localhost:28080/health
```

### Browser CORS error

Flutter web must be on **8090**. Re-run the owner script — it sets `CORS_ALLOWED_ORIGINS` for localhost:8090.

### APK cannot connect

Rebuild with your **current LAN IP** (not `localhost`). Apply firewall rule: `-OpenFirewall`.

---

## Quick curl checks

```bash
curl http://localhost:8090/
curl http://localhost:28080/health
curl http://localhost:28080/v1/quran/surahs
```

---

## Reports

- Phase 6D proof: `test-results/cursor-phase6d-working-web-interface-proof.md`
- Phase 6D repair notes: `reports/cursor-phase6d-working-web-interface-proof.md`
- Phase 6C (prior): `reports/cursor-phase6c-owner-local-access-repair.md`

---

## Local vs live

| | Local (this runbook) | Live / staging |
|--|----------------------|----------------|
| Web UI | `http://localhost:8090` | Hosted Flutter/web deploy |
| API | `http://localhost:28080/v1` | `https://api.<domain>/v1` |
| Purpose | Owner QA | Beta / production |
