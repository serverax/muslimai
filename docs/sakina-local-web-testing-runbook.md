# Sakina — Local Web & LAN Testing Runbook (PHASE 6C)

Local beta testing only — **not** public production. Backend runs in the local Docker QA stack
(`sakina-infra/docker-compose.qa.yml`), API on `:28080`. Flutter web app is served separately on
`:8090`. CORS uses a safe **explicit** local allowlist (no wildcard). Never marks LIVE_READY.

## TL;DR — one owner command

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1
```

Then open the **Flutter web app** URL printed by the script (typically `http://localhost:8090`).

> **Important:** `http://localhost:28080` is the **API** (JSON). It is not the Sakina UI.
> Opening `/v1` in a browser returns 404 — that is expected. Use port **8090** for the app.

## Four URL types (do not confuse them)

| Purpose | Example URL | What you see |
|---|---|---|
| **Flutter web app** (open in browser) | `http://localhost:8090` | Sakina UI (HTML) |
| API health (JSON smoke test) | `http://localhost:28080/health` | `{"status":"healthy",...}` |
| API base (app/curl/APK config) | `http://localhost:28080/v1` | 404 in browser (no UI route) |
| LAN API (phone/APK on Wi-Fi) | `http://192.168.0.51:28080/v1` | used via `--dart-define`, not browser |

Replace `192.168.0.51` with your machine's current LAN IP (`Get-NetIPAddress` below).

## 1. Start everything (owner script)

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1           # full proof + serve web on :8090
pwsh ./scripts/sakina-owner-local-test.ps1 -OpenBrowser   # also open Chrome
pwsh ./scripts/sakina-owner-local-test.ps1 -SkipApk       # faster (skip APK build)
```

Legacy launcher (stack + URLs only, no proof table):

```powershell
pwsh ./scripts/sakina-local-web.ps1
pwsh ./scripts/sakina-local-web.ps1 -Web    # runs flutter run -d chrome (interactive)
```

## 2. Confirm API health (JSON endpoints)

```powershell
curl http://localhost:28080/health      # expect 200
curl http://127.0.0.1:28080/health      # expect 200
curl http://localhost:28080/v1/health   # expect 200 (alias)
curl http://localhost:28080/v1          # expect 404 (no UI here)
```

## 3. Find your LAN IP (Windows)

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {$_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*'} |
  Select-Object IPAddress, InterfaceAlias
```

Test LAN reachability from this PC: `curl http://<LAN-IP>:28080/health`.

## 4. Pick the right API base URL

| Testing from | API base URL (`SAKINA_API_BASE_URL`) |
|---|---|
| This machine's browser (Flutter web) | `http://localhost:28080/v1` |
| Android **emulator** | `http://10.0.2.2:28080/v1` |
| Real phone / another PC on same Wi-Fi | `http://<LAN-IP>:28080/v1` |

Default in `lib/config/api_config.dart` is `http://localhost:28080/v1` (local Docker QA port).

## 5. Run the Flutter app in Chrome (manual alternative)

```bash
cd sakina-frontend
flutter run -d chrome --web-port 8090 \
  --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1
```

Or serve a pre-built bundle:

```bash
flutter build web --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1
python -m http.server 8090 -d build/web
```

## 6. Build the APK for local/LAN testing

```bash
cd sakina-frontend
# Android emulator:
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1
# Real phone on same Wi-Fi:
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. Debug builds allow cleartext HTTP to local/LAN
API only (`android/app/src/debug/` network config). Release security is unchanged.

## 7. Test from a real Android phone (same Wi-Fi)

1. Phone and PC on the **same** Wi-Fi network.
2. Build the APK with `SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1`.
3. If the app can't reach the API, open the Windows firewall (admin PowerShell):
   ```powershell
   pwsh ./scripts/sakina-owner-local-test.ps1 -OpenFirewall
   ```

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Browser shows blank / JSON at `:28080` | Opened API URL, not web app | Use `http://localhost:8090` |
| Browser shows CORS error | web port not in allowlist | run owner script (recreates api with CORS) |
| Phone can't reach API | Windows firewall blocks inbound 28080 | `-OpenFirewall` |
| `/v1` returns 404 in browser | no HTML route at API root | expected; use `:8090` for UI |
| Emulator can't reach `localhost` | emulator localhost = the emulator | use `http://10.0.2.2:28080/v1` |

## Quick API test list

```
GET  /health
GET  /v1/quran/surahs                 (anonymous)
GET  /v1/prayer-times?lat=..&lng=..&date=YYYY-MM-DD&tz=..   (anonymous)
POST /v1/auth/register  {email,password,display_name}
POST /v1/auth/login     {email,password}      → access_token
GET  /v1/entitlements/me            + Bearer
```
