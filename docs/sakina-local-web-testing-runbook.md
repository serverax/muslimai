# Sakina — Local Web & LAN Testing Runbook (PHASE 6B)

Local beta testing only — **not** public production. Backend runs in the local Docker QA stack
(`sakina-infra/docker-compose.qa.yml`), API on `:28080`. CORS uses a safe **explicit** local
allowlist (no wildcard). Never marks LIVE_READY.

## TL;DR (one command)
```powershell
pwsh ./scripts/sakina-local-web.ps1          # start stack + print all API URLs
pwsh ./scripts/sakina-local-web.ps1 -Web     # also run Flutter web in Chrome
```
Git Bash equivalent: `./scripts/sakina-local-web.sh` (add `--web` to launch Chrome).

## 1. Start the Docker stack
```bash
cd sakina-infra
docker compose -f docker-compose.qa.yml up -d
```
(If `ollama` fails with "port 11434 already allocated", that's a known local conflict and does NOT
block the API — `docker start sakina-infra-api-1` to bring the API up on its own.)

## 2. Confirm API health
```bash
curl http://localhost:28080/health      # expect 200
curl http://127.0.0.1:28080/health      # expect 200
```

## 3. Find your LAN IP (Windows)
```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {$_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*'} |
  Select-Object IPAddress, InterfaceAlias
```
Use the Wi-Fi/Ethernet address (e.g. `192.168.0.51`). Test it: `curl http://192.168.0.51:28080/health`.

## 4. Pick the right API base URL
| Testing from | API base URL (the app appends `/v1` automatically) |
|---|---|
| This machine's browser | `http://localhost:28080/v1` |
| Android **emulator** | `http://10.0.2.2:28080/v1` (emulator alias for host) |
| Real phone / another PC on same Wi-Fi | `http://<LAN-IP>:28080/v1` |

## 5. Run the Flutter app in Chrome (web)
```bash
cd sakina-frontend
flutter run -d chrome --web-port 8090 \
  --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1
```
The CORS allowlist already includes `http://localhost:8090`. (To serve a pre-built bundle instead:
`flutter build web --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1`, then serve
`build/web` on port 8091, e.g. `python -m http.server 8091 -d build/web`.)

## 6. Build the APK for local/LAN testing
```bash
cd sakina-frontend
# Android emulator:
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1
# Real phone on same Wi-Fi:
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1
```
Output: `build/app/outputs/flutter-apk/app-debug.apk` (~176 MB). Install on the phone (USB or copy).

## 7. Test from a real Android phone (same Wi-Fi)
1. Phone and PC on the **same** Wi-Fi network.
2. Build the APK with `SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1` (step 6).
3. If the app can't reach the API, open the Windows firewall for the port (admin PowerShell):
   ```powershell
   New-NetFirewallRule -DisplayName "Sakina Local API 28080" -Direction Inbound `
     -Action Allow -Protocol TCP -LocalPort 28080 -Profile Private
   ```
   or `pwsh ./scripts/sakina-local-web.ps1 -OpenFirewall`.

## 8. Environment switching (no hardcoded dev IP)
The app never hardcodes a machine IP. The API URL is injected at build/run time via
`--dart-define=SAKINA_API_BASE_URL=...` (read by `lib/config/api_config.dart`). Modes:
- **Local Docker:** `http://localhost:28080/v1`
- **LAN:** `http://<LAN-IP>:28080/v1`
- **Emulator:** `http://10.0.2.2:28080/v1`
- **Future live beta:** `https://api.<your-domain>/v1` (same flag; no code change)

## 9. Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| Browser shows CORS error | web port not in allowlist | run on `--web-port 8090` (or 8091), or set `CORS_ALLOWED_ORIGINS` and recreate api: `CORS_ALLOWED_ORIGINS="http://localhost:<port>" docker compose -f sakina-infra/docker-compose.qa.yml up -d --force-recreate api` |
| Phone can't reach API | Windows firewall blocks inbound 28080 | add the firewall rule (step 7) |
| API not on LAN IP | bound to localhost only | already binds `0.0.0.0:28080`; verify `docker port sakina-infra-api-1` |
| `ollama` port conflict on `up` | 11434 held by another app | ignore; `docker start sakina-infra-api-1` |
| `/v1/ask` returns 401 | login required | register/login first, send `Authorization: Bearer <token>` |
| Emulator can't reach `localhost` | emulator localhost = the emulator | use `http://10.0.2.2:28080/v1` |

## Quick API test list
```
GET  /health
GET  /v1/quran/surahs                 (anonymous)
GET  /v1/prayer-times?lat=..&lng=..   (anonymous)
POST /v1/auth/register  {email,password,display_name}
POST /v1/auth/login     {email,password}      → access_token
POST /v1/ask            {question}   + Bearer  → answer + safety_state
GET  /v1/entitlements/me            + Bearer
POST /v1/entitlements/check {feature_key} + Bearer
```
