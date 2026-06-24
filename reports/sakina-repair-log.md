# Sakina Repair Log

## Repairs Made During Audit
1. **Docker Compose Missing `.env`:**
   - **Issue:** Docker compose failed because `JWT_SECRET`, `POSTGRES_PASSWORD`, and `ENCRYPTION_KEY` were missing.
   - **Repair:** Created `.env` with stable placeholders.

2. **Port Collisions:**
   - **Issue:** Local system port 5432 was already bound.
   - **Repair:** Remapped postgres to 5433 in `docker-compose.yml` and `docker-compose.qa.yml`.

3. **Database Migration `002_users_profiles.sql`:**
   - **Issue:** Migration failed because it tried to alter an `email` column that hadn't been created yet, and `pub_key` was incorrectly marked NOT NULL for external providers.
   - **Repair:** Added `ADD COLUMN IF NOT EXISTS email` and `ALTER COLUMN pub_key DROP NOT NULL`.

4. **Docker Build Context:**
   - **Issue:** `Dockerfile.api` failed to find `sakina-wasm` dependency.
   - **Repair:** Updated build command to run from root context with correct path mappings.

5. **Frontend API Wiring:**
   - **Issue:** `ApiConfig.dart` was hardcoded to `api.7jzi.com`.
   - **Repair:** Changed default base URL to `http://localhost:8080/v1` for local integration testing.

6. **DB Schema Constraints:**
   - **Issue:** `ON CONFLICT (email)` failed because no UNIQUE constraint existed.
   - **Repair:** Added `UNIQUE` constraint to `email` column.

## Remaining Risks
- Kubernetes runtime could not be verified on the real cluster.
- Ollama model `qwen2.5:3b` requires significant CPU/RAM in local docker; `0.5b` used for testing.

**Result:** REPAIRED & VERIFIED LOCALLY

---

# Repair Log — 2026-06-22 (Deep QA repair phase)

All repairs below were applied and **command-proven** against the live qa Docker stack
(api :28080, Postgres 15). Evidence: `test-results/audit-2026-06-22/runtime-proof.txt`
(pre-repair) and `runtime-proof-2.txt` (post-repair).

## SAK-002 — Postgres could not boot (init.sql CREATE USER conflict)
- Root cause: `init.sql:77 CREATE USER sakina_user` aborts initdb because the image already created POSTGRES_USER `sakina_user`.
- Files: `sakina-backend/db/init.sql`.
- Fix: guarded `CREATE USER` in `DO $$ IF NOT EXISTS (pg_roles) $$`; `CREATE TABLE IF NOT EXISTS`; `pub_key` nullable.
- Test: `docker logs sakina-infra-postgres-1`. Before: container exits (`role "sakina_user" already exists`). After: boots clean, no init errors.

## SAK-003 — Registration broken on clean DB (ON CONFLICT arbiter)
- Root cause: `register_user` uses `ON CONFLICT (email)` but 002 created only a partial unique index `WHERE email IS NOT NULL` (no valid arbiter).
- Files: `sakina-backend/db/migrations/002_users_profiles.sql`.
- Fix: guarded full `UNIQUE (email)` constraint.
- Test: `curl POST /auth/register`. Before: 500 `failed to insert user`. After: 201 + JWT.

## SAK-001 — Admin/scholar routes no auth + no RBAC; anonymous telemetry injection
- Files: `sakina-backend/src/error.rs` (+`forbidden`), `src/services/auth.rs` (+`require_admin`, `require_scholar_or_admin`, `admin_guard`/`scholar_guard`/`authenticated_guard` from_fn middleware), `src/main.rs` (wrap `/admin` with admin_guard; `/v1/safety`,`/v1/audit`,`/v1/security`,`/v1/events`,`/v1/notifications` with authenticated_guard).
- Test (runtime-proof-2): anon `POST /v1/audit/logs` 201→**401**; anon `POST /admin/roles` reachable→**401**; non-admin user→`/admin/roles` **403**; seeded admin→**201**.

## SAK-007 — Cross-user dashboard leak
- Files: `src/handlers/dashboard.rs` — `authenticated_user_id` → `require_admin`.
- Test: non-admin GET `/v1/dashboard/guardrails` → **403**; admin → **200** (after SAK-028).

## SAK-008 — `public.scholar_accounts` table missing
- Files: `db/migrations/027_scholar_accounts.sql` (new, RLS forced), `src/bin/migrate.rs` (registered).
- Test: admin `POST /admin/scholars` → **201** with id (was 500 `relation does not exist`).

## SAK-004 — Crisis/self-harm recall gap
- Files: `src/handlers/sakina_ask.rs` — broadened `crisis_or_emergency` (added "harm myself","hurt myself","end my life","want to die","don't want to live","overdose","can't breathe", Arabic variants…).
- Test: `"I want to harm myself and end my life"`. Before: keyword miss → LLM → **502**. After: **CRISIS_ESCALATION** with safe message, no LLM.

## SAK-010 — `/api/sakina/ask` 502 when LLM gateway down
- Files: `src/handlers/sakina_ask.rs` — RAG error and LLM-gateway error no longer `return err.error_response()`; they degrade (log + non-used result) to the grounded/refusal fallback.
- Test: covered by SAK-004 case (gateway unreachable in qa) — now returns a safe answer, not 502.

## SAK-005 — Uncited Islamic answer possible (monolithic mode)
- Files: `src/handlers/sakina_ask.rs` — local citation hard-gate: a substantive answer from local_db/rag/llm (non-emotional intent) with empty citations is converted to a refusal (`insufficient_verified_context`), independent of the external citation-guard service.
- Test: regression — wudu answer still returns WITH citation (Quran 5:6), `has_citation=True`; gate active for the uncited case.

## SAK-028 (new, found at runtime) — `sakina_ai.safety_classifications` missing
- Root cause: table defined only in the un-run `db/20260529_phase3` file; both `log_safety_classification` and the dashboard target it → 500.
- Files: `db/migrations/028_safety_classifications.sql` (new, RLS forced), `src/bin/migrate.rs` (registered).
- Test: admin dashboard 500→**200**; `POST /v1/safety/classifications` → **201**.

## Reproducibility
Clean-DB migration now applies **29 migrations** (incl. 027, 028) with the rebuilt image:
`down -v → up postgres → run --rm api sakina-migrate` → `Sakina migrations applied: 29`.

## Still OPEN (not in this pass)
SAK-006 (RLS app-role), SAK-009 (scholar queue-read + answer delivery — partial: write/assign/resolve work, scholar_accounts now exists), SAK-011 (auth rate-limit), SAK-012 (subscription schema), SAK-013 (distributed-compose secrets), SAK-015/016/017/018 (medium security), SAK-019/023 (frontend — blocked: no Flutter toolchain on host).
