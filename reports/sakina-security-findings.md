# Sakina AI — Security Findings

Date: 2026-06-22. Detail/evidence: `test-results/audit-2026-06-22/agent-security.md`, `agent-routes-auth.md`, `runtime-proof.txt`.

## CRITICAL
- **SAK-001 Missing auth + RBAC.** `/admin/*`, scholar routes, `/v1/audit/*`,`/v1/security/*`,`/v1/events/*`,`/v1/safety/*` have no auth and no role check (`main.rs:822-852,1135-1210`, `phase2.rs:318-371`). Runtime: anonymous admin POSTs reach handler logic (never 401); anonymous `POST /v1/audit/logs` → **201, row written**.
- **SAK-006 RLS bypass.** `rls_service_role()` true for `current_user='sakina_user'` (app role) → no tenant isolation at the DB layer (`001:15-22`, `017`). Isolation relies entirely on app-layer filters.

## HIGH
- **SAK-007** `dashboard::get_guardrails` leaks all users' safety rows to any authenticated user (`dashboard.rs:17-35`).
- **SAK-011** No rate-limit/lockout on `/auth/login` & `/auth/register` (only `WaitlistRateLimiter`, `main.rs:563`).
- **SAK-013** Hardcoded "production"-named `JWT_SECRET`/`ENCRYPTION_KEY`/`POSTGRES_PASSWORD` in `docker-compose.distributed.yml` (5 services).

## MEDIUM
- **SAK-015** `/health/observability` + `/api/brain/audit/recent` public — info disclosure (runtime 200, no auth).
- **SAK-016** Hand-rolled JWT: non-constant-time signature compare (`auth.rs:101`); `alg`/`iss`/`aud` not validated. Mitigated by DB-session binding.
- **SAK-017** PII redaction heuristic/shallow before external LLM (`pii_redaction.rs`).
- **SAK-018** `guardrails.rs` is similarity-threshold only; content safety is a bypassable keyword blocklist.

## Positives (verified)
- Passwords Argon2id (`phase2.rs:2126`, schema 016). No plaintext/SHA.
- JWT secret ≥32 enforced; readiness gates on it (`auth.rs:48`, `main.rs:260`).
- SQL fully parameterized — **no injection** (every `format!` near SQL is an error msg or a bound LIKE pattern).
- CORS allowlist, no wildcard (`main.rs:404-427`).
- Mock/demo modes fail-closed (`ALLOW_MOCK_*` must be explicitly set; readiness refuses otherwise).
- `.env` gitignored — no live secret committed; CI runs gitleaks 8.24.3.
- No SSRF (service URLs from env), no path traversal.

## Not run (UNPROVEN)
- `cargo audit` dependency CVE scan — host cargo blocked by Application Control policy (os error 4551). Run inside the Rust build image in CI to close this.
- `trivy fs` / image CVE scan — not executed this session.
