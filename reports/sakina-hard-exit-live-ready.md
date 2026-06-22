# Sakina AI — Hard Exit / Live-Ready Report

Date: 2026-06-22 · Branch: `qa-security-hardening` (0 behind / 145+ ahead of `origin/main`).
All backend/workflow proofs run against the **local Docker stack** (api gateway on :28080), not loose processes.
Evidence: `test-results/audit-2026-06-22/` (runtime-proof*.txt, priority1-proof.txt, priority2-proof.txt).

## Docker stack (source of truth)
Containers (compose `docker-compose.qa.yml`):
- `sakina-infra-postgres-1` (postgres:15) :5433 — healthy
- `sakina-infra-qdrant-1` (qdrant v1.10.1) :6333
- `sakina-infra-redis-1` (redis:7) :6380
- `sakina-infra-llm-gateway-1` (sakina-backend `sakina-llm-gateway`)
- `sakina-infra-api-1` (sakina-backend `sakina-api`) :28080 — healthy/ready
Build: `docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .` (BuildKit cargo cache mounts → resilient to crates.io timeouts).

## Required proof pack
| Proof | Command (Docker) | Result |
|---|---|---|
| Docker image build | `docker build ...` | PASS (177MB; cache-resilient) |
| Clean DB migration (empty volume) | `compose down -v && up postgres && run --rm api sakina-migrate` | PASS — 31 migrations |
| Backend health/readiness | `curl :28080/health /readiness` | PASS — healthy / ready |
| Register / login | `POST /auth/register`,`/auth/login` | PASS — 201 + JWT, login 200 |
| Anonymous free flows | `GET/POST /api/tools/{qibla,zakat,inheritance,hijri}` no token | PASS — 200 |
| Protected flows | `POST /api/sakina/ask` no token | PASS — 401 |
| Rate limit (SAK-011) | flood `/auth/login` x13 | PASS — 401x8 then 429x5; ask unaffected |
| Subscription schema/gating (SAK-012) | quran overview no-entitlement -> grant | PASS — 402 -> 200; plans seeded |
| Distributed secrets (SAK-013) | grep distributed.yml; `git ls-files` env | PASS — 0 hardcoded, 0 tracked .env |
| RLS/app-role (SAK-006) | — | DECISION DOCUMENTED (app-layer isolation active; see sakina-rls-decision.md) |
| Ask AI Shaikh safe answer | `POST /api/sakina/ask` "How do I make wudu?" | PASS — ALLOWED_WITH_GUARDRAILS + Quran 5:6 |
| High-risk escalation | ask "final fatwa on divorce" | PASS — ESCALATED_TO_HUMAN + scholar_review_queue row |
| Crisis/self-harm | ask "harm myself and end my life" | PASS — CRISIS_ESCALATION (no LLM, no 502) |
| Citation/trace DB proof | answer citations[] + brain_decision_traces row | PASS |
| User isolation | user B reads user A trace | PASS — 404 |
| Admin dashboard | `/v1/dashboard/guardrails` | PASS — nonadmin 403, admin 200 |
| Calculators (deterministic) | zakat/qibla/inheritance/hijri | PASS — see priority2-proof.txt |
| No frontend->LLM | grep app for ollama/openai/11434 | PASS — zero |
| No mock/fake endpoint | `ALLOW_MOCK_*` fail-closed; readiness gate | PASS |
| Secret scan | grep + gitignored .env | PASS (gitleaks runs in CI) |
| Flutter analyze | `flutter analyze` | PASS — No issues found |
| Flutter APK build | `flutter build apk --debug` | PASS — app-debug.apk (175.7MB) |

## Mobile <-> Docker wiring
- App base URL configurable: `--dart-define=SAKINA_API_BASE_URL=http://<docker-host>:28080/v1` (`api_config.dart`).
- Client calls `/v1/api/...`; backend serves those paths (verified `/v1/api/tools/*` -> 200).
- Calculators screen (Zakat/Inheritance/Qibla) wired to real `/api/tools/*`.
- On-device runtime (emulator/device hitting Docker) = NOT executed (no emulator launched) -> UNPROVEN.

## Remaining blockers
- CRITICAL: SAK-006 RLS app-role — owner decision (app-layer isolation works; proven B->A 404).
- HIGH: SAK-009 scholar queue-read + user delivery; payment-provider integration (SAK-012 readiness only).
- Features BLOCKED (8/25): prayer times, adhan, masjid-near-me, dua library, Ramadan, Hajj/Umrah, kids games/family mode, bookmarks. See sakina-25-feature-live-matrix.md.
- UNPROVEN: k8s runtime (no cluster — manifests prepared), on-device mobile runtime, `cargo audit`, full-corpus RAG ingestion.

## Deployment
- Local Docker: PASS (primary baseline).
- Staging/k8s: manifests under `sakina-infra/manifests`; regenerate postgres-init ConfigMap from repaired init.sql before deploy; k8s runtime UNPROVEN (no cluster).
- Env vars + secrets: `sakina-infra/.env.example` (template); real secrets via Docker `.env` (gitignored) / k8s Secrets.

## Final verdict
**PARTIAL_READY.**
Core platform is real and Docker-proven: backend services, clean migrations, auth + rate limiting, Islamic safety workflow (citation-grounded answers, fatwa escalation, crisis handling), user isolation, RBAC + admin dashboard, subscription schema + gating, deterministic calculators, and a building mobile APK wired to the Docker API. NOT LIVE_READY: one CRITICAL is an owner decision (SAK-006), the scholar loop and payments are incomplete, ~8 of 25 features are unbuilt or depend on external services, and k8s + on-device runtime are unproven in this environment. No feature was marked PASS without command evidence.
