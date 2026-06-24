# Sakina AI — Production Readiness & Deployment

Date: 2026-06-22 · Branch: `qa-security-hardening` (0 behind / 145 ahead of `origin/main` — clean superset; path to main is a PR/merge).

## Command-proven this engagement
| Area | Proof | Status |
|---|---|---|
| Backend image builds | `docker build -f sakina-backend/Dockerfile` → 177MB | PASS |
| Backend boots | `/health` db connected, `/readiness` ready | PASS |
| DB migrations (clean) | `sakina-migrate` → 30 applied, init.sql clean | PASS |
| Auth register/login | 201 + JWT | PASS |
| Ask Shaikh + citation | wudu → Quran 5:6, ALLOWED_WITH_GUARDRAILS | PASS |
| High-risk fatwa escalation | ESCALATED_TO_HUMAN + scholar_review_queue row | PASS |
| Crisis/self-harm | CRISIS_ESCALATION (incl. broadened phrasing) | PASS |
| User isolation | B→A trace = 404 | PASS |
| RBAC | anon→401, nonadmin→403, admin→201 | PASS |
| Dashboard (admin-only) | nonadmin→403, admin→200 | PASS |
| No direct frontend→LLM | grep: zero LLM calls in app; inference via `/api/sakina/ask` | PASS |
| Mobile app builds | `flutter build apk --debug` → `app-debug.apk` (184MB); `flutter analyze` → No issues | PASS |

## Environment constraints (this host)
- Host `cargo` blocked (Application Control os err 4551) → build backend in Docker only.
- Flutter 3.41.7 present at `C:\src\flutter` (call `flutter.bat`; bash wrappers are `.sh.bak`). Android SDK + Android Studio JBR present.
- No live Sakina k8s cluster (kubectl points to an unrelated AKS) → k8s runtime UNPROVEN.
- Ollama host :11434 held by another project → sakina Ollama not co-located; LLM-compose path degrades gracefully (SAK-010).

## Required environment variables (backend)
`DATABASE_URL`, `JWT_SECRET` (≥32), `ENCRYPTION_KEY` (≥32), `QDRANT_URL`, `SAKINA_REDIS_URL`,
`SAKINA_ENV`, `SAKINA_LLM_ENABLED`, `SAKINA_LLM_GATEWAY_URL`, `OLLAMA_BASE_URL`, `SAKINA_LLM_MODEL`,
optional distributed: `SAKINA_BRAIN_URL`, `SAKINA_RULES_ENGINE_URL`, `SAKINA_CITATION_GUARD_URL`,
`CORS_ALLOWED_ORIGINS`, fail-closed `ALLOW_MOCK_*` (must stay unset/false in prod).
Secrets live in `sakina-infra/.env` (gitignored) for local; in k8s use Secrets, not literals.

## Local Docker run (proven)
```
docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .
cd sakina-infra
docker compose -f docker-compose.qa.yml --env-file .env down -v
docker compose -f docker-compose.qa.yml --env-file .env up -d postgres qdrant redis
docker compose -f docker-compose.qa.yml --env-file .env run --rm api sakina-migrate   # -> 30
docker compose -f docker-compose.qa.yml --env-file .env up -d --no-deps api llm-gateway
# api: http://localhost:28080  (free host :11434 to also run ollama)
```

## Mobile build steps (proven on this host)
```
cd sakina-frontend
flutter pub get
flutter analyze                      # -> No issues found
flutter build apk --debug            # -> build/app/outputs/flutter-apk/app-debug.apk
# Point the app at a backend:
flutter build apk --release --dart-define=SAKINA_API_BASE_URL=https://api.<domain>/v1
```
API base URL is configurable via `--dart-define=SAKINA_API_BASE_URL` (`lib/config/api_config.dart`, default `http://localhost:8080/v1`).

## Staging / production path
- Staging: build `sakina-backend:latest`, push to registry, apply `sakina-infra/manifests` (overlays/sakina-prod) to the Talos/k8s cluster, run `sakina-migrate` as a Job, expose api-gateway behind ingress + TLS.
- Action before k8s deploy: regenerate the `postgres-init` ConfigMap from the repaired `init.sql` (`Makefile:18`) so SAK-002 boot fix reaches the cluster.
- TLS/domain: ingress + cert-manager (manifests present under `sakina-infra/manifests`); not runtime-verified here.

## Remaining blockers to LIVE_READY
- CRITICAL: SAK-006 (RLS app-role) — owner decision (app-layer isolation works today).
- HIGH: SAK-009 (scholar queue-read/delivery), SAK-011 (auth rate-limit), SAK-012 (subscription/payment schema + gating), SAK-013 (distributed-compose secrets).
- Feature completeness: several of the 25 features are not yet implemented end-to-end (qibla, zakat, inheritance, masjid-near-me, dua library, Islamic calendar, Ramadan/Hajj tools, full kids mode) — backend endpoints + UI screens missing; Tajweed/Kids screens now made honest (no fabricated data, SAK-019).
- UNPROVEN: k8s runtime, `cargo audit`, full-corpus RAG load, Ollama e2e, mobile on-device runtime (built, not device-tested).

## Verdict
**PARTIAL_READY.** Backend, database, auth, Islamic safety workflow (citation-grounded answers, fatwa escalation, crisis handling), user isolation, RBAC, and the mobile app build are command-proven. Not LIVE_READY: one CRITICAL (SAK-006) is an owner decision, several HIGH items and a number of the 25 product features remain unimplemented, and k8s/on-device/CVE proofs are not available in this environment.
