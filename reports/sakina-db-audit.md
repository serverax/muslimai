# Sakina AI — Database & Migration Audit

Date: 2026-06-22. Detail: `test-results/audit-2026-06-22/agent-db-schema.md`. Runtime: 28 migrations applied to a clean DB (public 31 + sakina_ai 77 tables).

## Migration runner
`src/bin/migrate.rs` embeds migrations via `include_str!` from `db/migrations/` (authoritative; sibling `migrations/` is empty — SAK-025). **No version tracking**; re-runs every blob. Mostly idempotent via `IF NOT EXISTS`, but `CREATE POLICY` in 022-026 lack `DROP POLICY IF EXISTS` → not safely re-runnable on a persisted DB (SAK-020). Post-migration gate asserts RLS on every table (passes).

## Runtime result
`Sakina migrations applied: 28` (after SAK-002/003 fixes). Verified present: `public.users`, `public.auth_sessions`, `sakina_ai.brain_decision_traces`, `sakina_ai.scholar_review_queue`, `sakina_ai.scholar_resolved_answers`.

## Required-entity mapping
EXISTS: users, profiles, sessions/tokens, workspaces, ask traces (`brain_decision_traces`, `ask_shaikh_answers`), citations (jsonb on answers + relational quran/fatwa), quran/tafsir (022), hadith/fatwa (023), safety decisions (024, 7 event tables), audit_logs (019), user_preferences (024/020), entitlements (026).
PARTIAL: roles (no user↔role assignment table); scholar escalations (`scholar_review_queue`, no FK closure); scholar reviews (split, no review-history); subscription (entitlements exist; **`subscription_plans`/`user_subscriptions`/`payment_*` missing** — SAK-012).
MISSING: `kids_game_progress`; **`public.scholar_accounts`** (referenced by `create_scholar_account`, never created — SAK-008).

## CRITICAL/HIGH DB findings
- **SAK-002 (FIXED)** init.sql `CREATE USER` aborted container init.
- **SAK-003 (FIXED)** registration `ON CONFLICT (email)` had no arbiter (partial unique index only).
- **SAK-006** RLS gives no real isolation (service-role predicate true for app role `sakina_user`).
- **SAK-014** Dual conflicting `public.users` (init.sql vs 002) — partially fixed (pub_key nullable).
- **SAK-008** `scholar_accounts` missing.
- **SAK-012** Subscription/payment tables referenced by dangling FKs/policies but never created.

## Integrity notes
Missing FK indexes across quran/hadith/fatwa/learning child tables; free-text status/role/grade columns without CHECK; trace correlation by string (`request_id`/`trace_id`) not FK; answer-level citations stored as opaque JSONB (not joinable to cited rows). See `agent-db-schema.md` §4.

## Clean-DB proof commands
`docker compose -f sakina-infra/docker-compose.qa.yml down -v && up -d postgres` → init clean; `run --rm api sakina-migrate` → 28 applied; counts via `information_schema.tables`.
