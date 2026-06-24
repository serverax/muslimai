# Cursor Phase 6C — Owner Local Access Repair

**FINAL VERDICT: PASS**
**STATUS: OWNER_LOCAL_ACCESS_READY**
**BRANCH:** `qa-security-hardening`
**Date:** 2026-06-24

## Root cause (Phase 6B owner validation failure)

Phase 6B documented and printed **API URLs** (`http://localhost:28080`, `/v1/health`) as if they were the app.
The owner opened those in a browser and saw JSON or 404 — not the Sakina Flutter UI.

| What owner tried | What they got | Fix |
|---|---|---|
| `http://localhost:28080` | 404 | Expected — no web UI on API port |
| `http://localhost:28080/v1` | 404 | Expected — API base, not a page |
| `http://localhost:28080/health` | JSON health | API smoke test only |
| **Correct app URL** | **`http://localhost:8090`** | Flutter web served separately |

## What Phase 6C changed

1. **`scripts/sakina-owner-local-test.ps1`** — one owner command: stack + proof + serve web on `:8090` + print four URL types.
2. **`docs/sakina-local-web-testing-runbook.md`** — clearly separates API vs Flutter web URLs.
3. **`sakina-frontend/lib/config/api_config.dart`** — default API base `http://localhost:28080/v1` (matches Docker QA port).
4. **`sakina-infra/docker-compose.qa.yml`** — removed host bind on Ollama `:11434` (conflicted with other local Ollama; blocked `docker compose up`).
5. **Debug Android cleartext** — `android/app/src/debug/` only; release unchanged.
6. Owner script loads **`sakina-infra/.env`** (no hardcoded DB secrets in script).

## Verified URLs (2026-06-24)

| Type | URL | Result |
|---|---|---|
| Flutter web app | `http://localhost:8090` | 200 HTML (Sakina UI) |
| API health | `http://localhost:28080/health` | 200 JSON |
| API base (local) | `http://localhost:28080/v1` | 404 in browser (expected) |
| API base (LAN) | `http://192.168.0.51:28080/v1` | reachable (health 200) |
| API base (emulator) | `http://10.0.2.2:28080/v1` | documented |

LAN IP **192.168.0.51** confirmed valid on this machine (Wi-Fi).

## PASS/FAIL (13 checks)

| # | Check | Status |
|---|-------|--------|
| 1 | Docker stack | PASS |
| 2 | API health localhost | PASS |
| 3 | API health 127.0.0.1 | PASS |
| 4 | API health LAN IP | PASS |
| 5 | Flutter web serves app page | PASS |
| 6 | App can call backend API (CORS) | PASS |
| 7 | APK builds with LAN API | PASS (184,323,862 B) |
| 8 | Quran endpoint | PASS |
| 9 | Prayer endpoint | PASS |
| 10 | Auth smoke | PASS |
| 11 | Entitlement endpoint | PASS |
| 12 | No secrets committed | PASS |
| 13 | Phase 1–5 smoke paths | PASS |

Raw command evidence: `test-results/cursor-phase6c-owner-local-access-proof.md`

## Files changed (Phase 6C only)

- `scripts/sakina-owner-local-test.ps1` (new)
- `docs/sakina-local-web-testing-runbook.md`
- `reports/cursor-phase6c-owner-local-access-repair.md` (this)
- `test-results/cursor-phase6c-owner-local-access-proof.md`
- `sakina-frontend/lib/config/api_config.dart`
- `sakina-infra/docker-compose.qa.yml`
- `sakina-frontend/android/app/src/debug/AndroidManifest.xml`
- `sakina-frontend/android/app/src/debug/res/xml/network_security_config.xml`

## Known limitations

- **Cross-device LAN** from a separate phone is host-proven (192.168.0.51:28080 health 200); owner should confirm on phone. Use `-OpenFirewall` if blocked.
- **HTTP only** on local LAN — not for internet exposure.
- **`sakina-infra/.env` required** — script loads it; do not commit `.env`.
- Phase 7 security hardening **not started** per owner instruction.

## Owner next steps

1. Run: `pwsh ./scripts/sakina-owner-local-test.ps1`
2. Open **`http://localhost:8090`** in Chrome (the app — not `:28080`).
3. Smoke: Daily Essentials → Quran, Prayer; register/login; check entitlements.
4. Phone: install APK from path printed by script (LAN API baked in).
