# Sakina AI — PHASE 6B: Local Web & LAN Testing Access — Proof

**FINAL VERDICT: PASS**
**STATUS: LOCAL_WEB_TEST_READY** (local beta access only — NOT LIVE_READY)
**BRANCH:** `qa-security-hardening`
**COMMIT HASH:** _(filled at commit — see git log; this report committed with the PHASE 6B change)_
**PUSH STATUS:** pushed to `origin qa-security-hardening`

Date: 2026-06-24 · Stack: local Docker QA (`sakina-infra/docker-compose.qa.yml`, api `:28080`).
Raw evidence: `test-results/phase6b-local-web-access-proof.md`. No mocks, no fake deploy, no secrets exposed.

## Access URLs
- **LOCAL API URL:** `http://localhost:28080/v1` (also `http://127.0.0.1:28080/v1`)
- **LAN API URL:** `http://192.168.0.51:28080/v1` (this machine's Wi-Fi IP; host-reachable = 200)
- **Emulator API URL:** `http://10.0.2.2:28080/v1`
- **FLUTTER WEB COMMAND:** `flutter run -d chrome --web-port 8090 --dart-define=SAKINA_API_BASE_URL=http://localhost:28080/v1`
- **APK BUILD COMMAND:** `flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://192.168.0.51:28080/v1`
- **APK PATH:** `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`
- **APK SIZE:** 184,323,862 B (≈ 175.8 MB)
- **DOCKER STATUS:** api + postgres + qdrant + redis + llm-gateway all Up; api binds `0.0.0.0:28080`.

## PASS/FAIL table
| Check | Result |
|---|---|
| Docker services up | PASS (5 services) |
| API health `localhost:28080` | PASS (200) |
| API health `127.0.0.1:28080` | PASS (200) |
| API health LAN `192.168.0.51:28080` | PASS (200 host→LAN; cross-device = owner-verify, firewall cmd provided) |
| CORS allows safe local origin | PASS (`access-control-allow-origin: http://localhost:8090`) |
| CORS denies foreign origin | PASS (`http://evil.com` → 400, no allow-origin) |
| CORS is explicit (no wildcard) | PASS (env allowlist) |
| Flutter analyze | PASS (No issues found) |
| Flutter web build | PASS (✓ Built build/web, 21M) |
| APK build | PASS (175.8 MB) |
| API-URL config proof | PASS (web bundle bakes `localhost:28080/v1`; APK bakes `192.168.0.51:28080/v1`) |
| Auth register/login | PASS (201 / 200 + JWT) |
| Quran anonymous endpoint | PASS (`/v1/quran/surahs` 200) |
| Prayer-times anonymous endpoint | PASS (`/v1/prayer-times` 200) |
| Ask AI Shaikh safe flow | PASS (authed 200, `ALLOWED_WITH_GUARDRAILS`, cites Quran 2:153; anon 401) |
| Entitlement endpoint | PASS (`/v1/entitlements/me` 200 authed / 401 anon; `/check` 200) |
| No secrets committed / in bundle | PASS (no real secret values in build/web; build/ gitignored) |

## Files changed
- `sakina-infra/docker-compose.qa.yml` — added env-driven, safe local `CORS_ALLOWED_ORIGINS` (default localhost:8090/8091; overridable to add LAN origin). No wildcard.
- `sakina-frontend/web/` — Flutter web platform scaffolding generated (`index.html`, `manifest.json`, `favicon.png`, `icons/`); enables `flutter run -d chrome` / `flutter build web`.
- `scripts/sakina-local-web.ps1` (new) — Windows launcher: detect LAN IP, set safe CORS, start stack, health-check, print URLs, optional Chrome run, optional firewall rule.
- `scripts/sakina-local-web.sh` (new) — Git Bash equivalent.
- `docs/sakina-local-web-testing-runbook.md` (new) — owner runbook (start, health, LAN IP, web, APK, emulator, phone, troubleshooting).
- `reports/sakina-phase6b-local-web-access-proof.md` (this) + `test-results/phase6b-local-web-access-proof.md` (raw evidence).

`lib/config/api_config.dart` was **not** modified — it already supports `--dart-define=SAKINA_API_BASE_URL`, so no hardcoded developer IP is introduced.

## Reports written
- `reports/sakina-phase6b-local-web-access-proof.md`
- `test-results/phase6b-local-web-access-proof.md`
- `docs/sakina-local-web-testing-runbook.md`

## Known limitations
- **Cross-device LAN** (a separate phone hitting `192.168.0.51:28080`) is proven only host→LAN-IP (200); the owner must confirm on the phone. If blocked, the exact Windows firewall command is provided (script `-OpenFirewall`).
- **HTTP only** (no TLS) for local testing — fine on a trusted LAN; do not expose to the internet.
- **Stripe** remains `provider_not_configured` (PHASE 5) — unchanged.
- **`ollama`** local port 11434 is held by another app; does not affect the API (`docker start sakina-infra-api-1`). LLM answers run via the in-stack `llm-gateway`.
- Not public deployment; **NOT LIVE_READY**.

## Owner testing steps
1. `pwsh ./scripts/sakina-local-web.ps1` → prints all API URLs and confirms health.
2. Browser on this PC: `pwsh ./scripts/sakina-local-web.ps1 -Web` (opens the app in Chrome against the local API).
3. Android emulator: install the APK built with `…=http://10.0.2.2:28080/v1`.
4. Real phone (same Wi-Fi): build APK with `…=http://192.168.0.51:28080/v1`, install, open; if it can't connect run `-OpenFirewall`.
5. Smoke: open Daily Essentials → Quran, Prayer times (anonymous); register/login → Ask AI Shaikh; check Subscription/entitlements.

## No Phase 1–5 regression
Auth, Quran, Prayer, Ask (cited + guardrailed), and entitlement gating all returned correct live results during this proof. No Phase 1–5 logic was modified (only compose CORS env + web scaffolding + scripts/docs).

## NEXT RECOMMENDED PHASE
PHASE 7 — security hardening (no cluster required), now that the owner has a usable local web/app testing path. Live cluster deploy (PHASE 6 live half) stays blocked until a reachable cluster + secrets + TLS are provided.
