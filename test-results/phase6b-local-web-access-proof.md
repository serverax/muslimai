# PHASE 6B — Local Web / LAN Access — Raw Proof Evidence

Date: 2026-06-24 · Branch `qa-security-hardening` · Stack: local Docker QA (api `:28080`).
Machine LAN IP: `192.168.0.51` (Wi-Fi). No mocks; commands run against the live local stack.

## Docker services
```
sakina-infra-api-1         Up   0.0.0.0:28080->8080/tcp
sakina-infra-llm-gateway-1 Up
sakina-infra-postgres-1    Up   0.0.0.0:5433->5432/tcp
sakina-infra-qdrant-1      Up   0.0.0.0:6333->6333/tcp
sakina-infra-redis-1       Up   0.0.0.0:6380->6379/tcp
```
(api binds `0.0.0.0:28080` → reachable on localhost, 127.0.0.1, and the LAN IP.)

## API health (3 access paths)
```
http://localhost:28080/health   = 200
http://127.0.0.1:28080/health   = 200
http://192.168.0.51:28080/health = 200   (host → its own LAN IP)
```

## CORS (safe, explicit allowlist — NO wildcard)
api recreated with `CORS_ALLOWED_ORIGINS=http://localhost:8090,http://127.0.0.1:8090,http://192.168.0.51:8090,http://localhost:8091`
```
# allowed origin
OPTIONS /v1/ask  Origin: http://localhost:8090
  HTTP/1.1 200 OK
  access-control-allow-origin: http://localhost:8090
  access-control-allow-methods: OPTIONS, POST, GET
# disallowed origin
OPTIONS /v1/ask  Origin: http://evil.com
  HTTP/1.1 400 Bad Request        (no access-control-allow-origin → correctly denied)
```

## Endpoint smoke (live)
```
GET  /v1/quran/surahs                          = 200   (anonymous)
GET  /v1/prayer-times?lat=51.5&lng=-0.12&...   = 200   (anonymous)
POST /v1/ask  (anonymous)                      = 401   unauthorized (correct — login required)
POST /v1/auth/register                         = 201   user_id b211f458…
POST /v1/auth/login                            = 200   access_token (len 303 JWT)
POST /v1/ask  (Bearer)                         = 200   safety_state ALLOWED_WITH_GUARDRAILS, cites Quran 2:153
GET  /v1/entitlements/me  (Bearer)             = 200   {"entitlements":[],"premium":false}
GET  /v1/entitlements/me  (anon)               = 401   (correct)
POST /v1/entitlements/check (Bearer)           = 200   {"allowed":false,"tier_required":"premium"}
```

## Flutter
```
flutter analyze                 → No issues found! (36.5s)
flutter build web  --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1   → ✓ Built build/web (21M)
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://192.168.0.51:28080/v1
                                → ✓ Built build/app/outputs/flutter-apk/app-debug.apk (184,323,862 B ≈ 175.8 MB)
```

## API-URL config proof (which URL the app actually uses)
- `lib/config/api_config.dart` reads `String.fromEnvironment('SAKINA_API_BASE_URL', default 'http://localhost:8080/v1')`.
- Web bundle bakes the chosen URL: `build/web/main.dart.js` contains `http://localhost:28080/v1`.
- APK bakes the LAN URL passed at build time: `http://192.168.0.51:28080/v1`.
- `_endpoint()` appends `/v1` only if absent, so passing a base with or without `/v1` is safe.

## No secrets exposed
```
grep real secret values (sakina_password / jwt-secret / encryption) in build/web → NONE  PASS
only match for sk_test_ pattern = "sk_test_bit" inside canvaskit skwasm.js.symbols → Skia symbol, NOT a Stripe key
build/ is gitignored → no web/apk artifacts committed
```

## LAN cross-device note (honest)
Host-to-LAN-IP (`192.168.0.51:28080`) returns 200, proving the API is bound on the LAN interface.
True access from a *separate* phone on the same Wi-Fi depends on Windows Defender Firewall inbound
rules for the published port. No explicit allow rule for TCP 28080 was found; if a phone cannot
connect, run (admin PowerShell):
```
New-NetFirewallRule -DisplayName "Sakina Local API 28080" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 28080 -Profile Private
```
(or `scripts/sakina-local-web.ps1 -OpenFirewall`). This is the only LAN item the owner must confirm on-device.
