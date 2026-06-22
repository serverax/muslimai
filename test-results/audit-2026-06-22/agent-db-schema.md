# DB schema + RLS audit (agent result, 2026-06-22)

## Migration runner (`src/bin/migrate.rs`)
- Hardcoded ordered array of `include_str!("../../db/migrations/NNN.sql")` → `sqlx::raw_sql`. `db/migrations/` authoritative; sibling `sakina-backend/migrations/` EMPTY + never referenced (trap).
- NO version tracking (no schema_migrations table). Re-runs every blob. Mostly idempotent by `IF NOT EXISTS`, BUT `CREATE POLICY` in 022/023/024/025/026 lack `DROP POLICY IF EXISTS` → 42710 duplicate_object on re-run against persisted DB.
- `init.sql`, phase3, phase21 files NOT run by binary; init.sql wired as Postgres container init (manifests/postgres-deployment.yaml:86).
- Post-migration gate `migrate.rs:152-170` asserts rowsecurity=true on all tables in public/sakina_ai/audit/outbox else fails.

## CRITICAL — RLS gives NO real per-user isolation
- `sakina_ai.rls_service_role()` (`001:15-22`) returns true if GUC `sakina.service_role='on'` OR `current_user IN ('sakina_user','postgres','sakina_staging_user','sakina')`.
- App connects AS `sakina_user` (init.sql:77, postgres-deployment.yaml:8) = table owner.
- 017 FORCE RLS on every table (defeats owner-bypass) — correct. BUT every table's service policy `USING (rls_service_role())` satisfied on every row because current_user='sakina_user'.
- Even `set_config('sakina.service_role','off',true)` (phase2.rs:2007-2024) INERT: `OR current_user IN (...)` short-circuits true. Real isolation needs a different non-allowlisted role (e.g. sakina_app) that does NOT exist.
- NET: RLS enabled+forced (migrate gate passes, tests satisfied) but ZERO runtime tenant isolation on main app connection. MUST verify at runtime.

## Required-entity mapping
EXISTS: users(002), profiles(002), sessions/tokens(016), workspaces(020/024), ask traces(014 brain_decision_traces, 021 ask_shaikh_answers), citations(fragmented jsonb + relational quran_tafsir_citations/fatwa_citations), quran(022), tafseer(022), hadith(023), fatwa(023), safety decisions(024: 7 event tables), audit_logs(019), user_preferences(024/020).
PARTIAL: roles (admin_roles/permissions 010_admin_core, NO user↔role assignment table). scholar_escalations (scholar_review_queue 021, no FK closure). scholar_reviews (split queue + scholar_resolved_answers 025, no review-history). subscription/entitlements (entitlements+user_entitlements 026, usage_limits/premium_unlocks 024 EXIST, but NO subscription_plans/user_subscriptions/payment_*/refunds — dangling FKs 024:111, 026:21, 017:206-254 dead policies).
MISSING: kids_game_progress (entirely absent).

## Integrity
- Dual conflicting `public.users`: init.sql:61 (pub_key NOT NULL, no email) vs 002:3 (email/auth_provider). init runs first on container → pub_key NOT NULL forced.
- Duplicate 010_ prefix disjoint, no conflict but smell.
- Missing FKs: brain_decision_traces.user_id TEXT, user_memory_entries/multimodal_assets user_id bare uuid, scholar_review_queue request_id/conversation_id bare. Trace correlation by string.
- Missing FK indexes widespread. Status/role/grade columns free-text TEXT, no CHECK. Citations opaque JSONB.

## Top ranked
1. RLS no real isolation (service-role predicate always true for sakina_user).
2. Conflicting dual public.users.
3. Subscription/payment layer referenced but never created — gating half-built.
4. kids_game_progress missing.
5. Migrate runner no version tracking + non-idempotent CREATE POLICY.
6. Scholar/safety/audit not FK-closed, no review history.
