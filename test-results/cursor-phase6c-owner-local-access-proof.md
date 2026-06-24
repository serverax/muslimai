# Cursor Phase 6C — Owner Local Access Proof

Generated: 2026-06-24 (Cursor Phase 6C repair)
Branch: qa-security-hardening
HEAD: 954700f (pre-commit; see git log after Phase 6C commit)
LAN IP: 192.168.0.51 (Wi-Fi — valid)

## URL types (Phase 6C fix — do NOT confuse API with web app)

| Purpose | URL |
|---|---|
| **Flutter web app (open in browser)** | `http://localhost:8090` |
| API health (JSON) | `http://localhost:28080/health` |
| API base (localhost) | `http://localhost:28080/v1` |
| API base (LAN phone/APK) | `http://192.168.0.51:28080/v1` |
| API base (emulator) | `http://10.0.2.2:28080/v1` |

## PASS/FAIL

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | Docker stack | PASS | sakina-infra-api-1 Up |
| 2 | API health localhost | PASS | http://localhost:28080/health -> 200 |
| 3 | API health 127.0.0.1 | PASS | http://127.0.0.1:28080/health -> 200 |
| 4 | API health LAN IP | PASS | http://192.168.0.51:28080/health -> 200 |
| 5 | Flutter web serves app page | PASS | http://localhost:8090 -> 200 HTML |
| 6 | App can call backend API | PASS | CORS allow-origin=http://localhost:8090 |
| 7 | APK builds with LAN API | PASS | app-debug.apk 184,316,971 B; built with `--dart-define=SAKINA_API_BASE_URL=http://192.168.0.51:28080/v1` |
| 8 | Quran endpoint | PASS | /v1/quran/surahs -> 200 |
| 9 | Prayer endpoint | PASS | /v1/prayer-times -> 200 |
| 10 | Auth smoke | PASS | register=201 login=200 |
| 11 | Entitlement endpoint | PASS | /v1/entitlements/me -> 200 (Bearer) |
| 12 | No secrets committed | PASS | Phase 6C files only; .env gitignored |
| 13 | Phase 1-5 smoke paths | PASS | auth+quran+prayer+entitlement |

## URL matrix (expected 404 on bare /v1 — not the app)

- http://localhost:28080 -> 404
- http://localhost:28080/health -> 200 API-JSON
- http://localhost:28080/v1 -> 404 (expected)
- http://localhost:28080/v1/health -> 200 API-JSON
- http://127.0.0.1:28080/health -> 200
- http://192.168.0.51:28080/health -> 200
- http://localhost:8090 -> 200 HTML (Flutter web app)

## APK build evidence

```
cd sakina-frontend
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://192.168.0.51:28080/v1
# Output: build/app/outputs/flutter-apk/app-debug.apk (184,316,971 bytes)
```

## Web bundle evidence

```
flutter build web --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1
findstr localhost:28080 build/web/main.dart.js  # FOUND
python -m http.server 8090 --bind 127.0.0.1 -d build/web
# http://localhost:8090 -> Sakina UI
```
