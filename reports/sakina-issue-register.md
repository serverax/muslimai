# Sakina AI — Issue Register

Date: 2026-06-22 · Branch: `qa-security-hardening` · Auditor: senior QA/security
Method: 5 parallel static code investigators + live Docker-Compose runtime proof (qa stack on :28080).
Evidence: `test-results/audit-2026-06-22/` (agent-*.md, runtime-proof.txt).

Legend severity: CRITICAL (data leak / unsafe Islamic answer / broken auth / boot failure / fake readiness) · HIGH (broken key workflow / migration / missing citation/scholar) · MEDIUM (UX / missing error state / weak control) · LOW (cleanup).

## Repair status (updated 2026-06-22, phase 2 — command-proven, see sakina-repair-log.md)
FIXED+VERIFIED: SAK-001, SAK-002, SAK-003, SAK-004, SAK-005, SAK-007, SAK-008, SAK-010, SAK-028 (new).
OPEN: SAK-006 (RLS app-role), SAK-009 (scholar queue-read/delivery — partial), SAK-011, SAK-012, SAK-013, SAK-015..018, SAK-019/023 (frontend, no Flutter toolchain), SAK-014 (partial), SAK-020/021/022, SAK-024..027.
CRITICAL remaining: SAK-006 only.

---

## CRITICAL

### SAK-001 — Admin & scholar routes have NO authentication and NO RBAC
- Area: Auth/RBAC. Files: `src/main.rs:822-852,1135-1210`, `src/handlers/phase2.rs:318-371`.
- Evidence: Handlers take no `HttpRequest`, never call `authenticated_user_id`, no role check. Runtime: anonymous `POST /admin/roles` and `POST /admin/scholars` returned **500 (downstream DB), never 401** — handler executes for anonymous callers (`runtime-proof.txt`). `POST /v1/audit/logs` anonymous → **201, row written** (audit_logs 0→1).
- Impact: Any unauthenticated network client can attempt to mint admin roles, create scholar accounts, resolve scholar reviews, and **does** inject arbitrary audit/security/safety/event records.
- Root cause: No auth middleware; per-handler opt-in; these handlers omit the check. No RBAC exists anywhere in the codebase.
- Repair: Add auth+role middleware/extractor; require admin role on `/admin/*` and scholar role on scholar routes; require auth on all `/v1/audit/*`, `/v1/security/*`, `/v1/events/*`, `/v1/safety/*`.
- Status: OPEN.

### SAK-002 — Postgres cannot boot from shipped init.sql (CREATE USER conflict)
- Area: DB/Infra. File: `sakina-backend/db/init.sql:77`.
- Evidence: `CREATE USER sakina_user` aborts because the image already creates POSTGRES_USER `sakina_user` → initdb script errors → container exits (`docker logs`: `role "sakina_user" already exists`).
- Impact: `docker-compose.qa.yml` / `docker-compose.yml` postgres never reaches ready; whole stack down.
- Repair: APPLIED — guarded `CREATE USER` in a `DO $$ IF NOT EXISTS (pg_roles) $$` block + `CREATE TABLE IF NOT EXISTS`. After fix postgres boots clean (no init errors).
- Status: FIXED (verified runtime).

### SAK-003 — Registration is broken on a clean DB (ON CONFLICT vs partial unique index)
- Area: Auth/DB. Files: `src/services/phase2.rs:55-69`, `db/migrations/002_users_profiles.sql:41-43`.
- Evidence: `register_user` uses `INSERT ... ON CONFLICT (email)`, but 002 created only a **partial** unique index `WHERE email IS NOT NULL`. Postgres: `ERROR: there is no unique or exclusion constraint matching the ON CONFLICT specification`. Runtime first registration → 500 `failed to insert user`.
- Impact: No user can register → entire authenticated product (Ask Shaikh, history, escalation) unusable.
- Repair: APPLIED — added guarded full `UNIQUE (email)` constraint in 002 + applied to live DB. After fix registration → 201 with JWT.
- Status: FIXED (verified runtime).

### SAK-004 — Crisis / self-harm classifier has poor recall; missed crisis errors out
- Area: Islamic safety. File: `src/handlers/sakina_ask.rs:88-102,518-527`.
- Evidence: Keyword list (`"self harm"`,`"suicide"`,`"kill myself"`). Runtime: "I want to harm myself and end my life" did NOT match → fell through to LLM compose → **502** error to a vulnerable user. "suicide" DID match → correct `CRISIS_ESCALATION` message. So routing works but recall is brittle.
- Impact: Real self-harm phrasing can bypass crisis routing; with LLM unavailable the user gets an internal error instead of crisis support. Highest-harm failure mode.
- Repair: Broaden crisis detection (model/embedding classifier or much wider phrase set incl. "harm myself","end my life","hurt myself","don't want to live"); guarantee a safe crisis fallback that never depends on the LLM; never 502 a flagged-risk message.
- Status: OPEN.

### SAK-005 — Citation guard absent in non-distributed mode (zero-citation Islamic answers possible)
- Area: RAG/safety. File: `src/handlers/sakina_ask.rs:693-736`.
- Evidence: The only hard citation guard calls external `SAKINA_CITATION_GUARD_URL`; unset in monolithic/qa mode → block skipped. Non-LLM answer paths (local_sunni_topics with empty citations; templated IslamicAnswerService text) can return an Islamic answer with `citations:[]`. The verified-source hard gate lives in the dead `decide` engine.
- Impact: An Islamic answer can reach the user without sources in the default single-binary deployment.
- Repair: Enforce a local citation/verified-source gate in `sakina_ask.rs` for every Islamic answer (port the `generated_from_verified_sources` gate from `decision_algorithm.rs`).
- Status: OPEN. (Note: runtime safe-wudu answer DID carry a Quran 5:6 citation, so the happy path is cited; the gap is unguarded edge cases.)

### SAK-006 — RLS provides no real per-user isolation on the app connection
- Area: Security/DB. Files: `db/migrations/001_init_extensions.sql:15-22`, `017_rls_user_isolation.sql`.
- Evidence: `rls_service_role()` returns true when `current_user IN ('sakina_user',...)`; the app connects as `sakina_user`, so the service policy is satisfied on every row regardless of GUCs. `set_config('sakina.service_role','off')` is inert. Isolation depends entirely on app-layer `WHERE user_id=$2`.
- Impact: RLS is defense-theatre; any handler that forgets the user filter leaks across tenants (see SAK-007). A raw/injected query would see all tenants.
- Repair: Run the app as a dedicated non-allowlisted role (e.g. `sakina_app`) and drive isolation purely by the GUC, or remove the `current_user` shortcut from `rls_service_role()`.
- Status: OPEN. (Mitigation today: app-layer filtering — verified working for trace retrieval, B→A = 404.)

---

## HIGH

### SAK-007 — Cross-user data leak via dashboard
- Area: Isolation. File: `src/handlers/dashboard.rs:17-35`. Any authenticated user receives the last 100 `sakina_ai.safety_classifications` across ALL users (user_id, request_id), no user filter, no admin gate. Repair: scope to caller or require admin. Status: OPEN.

### SAK-008 — `public.scholar_accounts` table missing
- Area: DB/Scholar. `create_scholar_account` (`phase2.rs:1338`) inserts into `public.scholar_accounts`, which no migration creates. Runtime: `relation "public.scholar_accounts" does not exist`. Repair: add migration. Status: OPEN.

### SAK-009 — Scholar workflow not a closed loop
- Area: Scholar. No GET/list endpoint for `scholar_review_queue` in the prod router (only assign+resolve POST, `main.rs:845-851`); resolved answer (`scholar_resolved_answers`) is never delivered back to the originating user/conversation; crisis never enqueues. Repair: add queue-read + delivery-back. Status: OPEN. (Escalation WRITE verified working at runtime.)

### SAK-010 — `/api/sakina/ask` errors hard (502) when LLM gateway unreachable
- Area: Ask resilience. `src/handlers/sakina_ask.rs` (compose branch). Runtime: a question with no local/RAG hit + gateway down returned 500/`502 Bad Gateway` rather than a graceful grounded refusal. Repair: treat gateway failure as degrade-to-refusal, not 5xx. Status: OPEN.

### SAK-011 — No brute-force / rate-limit on `/auth/login` & `/auth/register`
- Area: Security. Only `WaitlistRateLimiter` exists (`main.rs:563`). Repair: per-IP + per-account throttling + lockout. Status: OPEN.

### SAK-012 — Subscription/payment schema referenced but never created
- Area: DB/monetization. `usage_limits.plan_id`→`subscription_plans`, `user_entitlements.subscription_id`→`user_subscriptions`, RLS policies for `payment_methods/subscription_events/refunds` (`017:206-254`) are all dangling; no such tables. Subscription gating is half-built. Repair: build billing schema or remove dangling refs. Status: OPEN.

### SAK-013 — Hardcoded "production"-named secrets in docker-compose.distributed.yml
- Area: Secrets. `JWT_SECRET=sakina_production_jwt_secret_32_chars_long`, `ENCRYPTION_KEY`, `POSTGRES_PASSWORD=sakina_password` committed across 5 services. Repair: move to `${VAR:?required}` like the main compose. Status: OPEN. (Note: `.env` is gitignored; main compose is correct.)

### SAK-014 — Dual conflicting `public.users` definition (init.sql vs migration 002)
- Area: DB. init.sql narrow users (pub_key) vs 002 (email). Load order on container makes init win; partially mitigated by SAK-003 fix and pub_key-nullable fix. Repair: make init.sql not own `public.users` (let migrations own it), or fully align. Status: PARTIALLY FIXED (pub_key nullable applied).

---

## MEDIUM

- SAK-015 — `/health/observability` and `/api/brain/audit/recent` public — operational info disclosure (`main.rs:355-386`, `brain.rs:41`). Runtime: 200 no auth. OPEN.
- SAK-016 — Hand-rolled JWT: non-constant-time signature compare (`auth.rs:101`); `alg`/`iss`/`aud` not validated. DB-session cross-check mitigates forgery. OPEN.
- SAK-017 — PII redactor heuristic/shallow (`pii_redaction.rs`) — misses bare names, intl phones, IDs before external LLM. OPEN.
- SAK-018 — `guardrails.rs` is a similarity threshold only, not a prompt-injection filter; content guardrails are a bypassable keyword blocklist. OPEN.
- SAK-019 — Frontend Tajweed Coach shows FABRICATED feedback ("makhraj for 'Qaf' is 92% accurate"); Kids Quran is a static stub (`tajweed_coach_screen.dart:85-87`, `kids_quran_screen.dart`). Violates no-fake-feature rule. OPEN.
- SAK-020 — Migrate runner has no version tracking; several `CREATE POLICY` (022-026) lack `DROP POLICY IF EXISTS` → not idempotent on a persisted DB (`src/bin/migrate.rs`). OPEN.
- SAK-021 — Two answer engines; the citation-gated `decide` engine is dead (wired with `EmptyRetriever`); live ask uses keyword engine. OPEN (architectural).
- SAK-022 — `enqueue_scholar_review` swallows its DB error (`let _ =`, `sakina_ask.rs:332`) — a failed escalation still tells the user "escalated". OPEN.
- SAK-023 — Frontend Ask/Chat screen not RTL-aware (Arabic answers not given RTL context); renders citations as plain text vs the CitationBadge widget. OPEN.

## LOW
- SAK-024 — Junk top-level files: a file literally named `:` and a phantom `reports\r` directory from CRLF corruption. OPEN.
- SAK-025 — Empty `sakina-backend/migrations/` dir (trap; authoritative dir is `db/migrations/`). OPEN.
- SAK-026 — Widespread missing FK indexes + free-text status/role columns without CHECK constraints. OPEN.
- SAK-027 — `expect()` in 2 non-test request paths (`rag.rs:370`, `ai_router.rs:310`) — invariant-protected. OPEN.
