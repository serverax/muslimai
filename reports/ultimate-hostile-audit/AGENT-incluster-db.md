# ULTIMATE HOSTILE DB AUDIT — In-Cluster Staging Postgres

**Target:** pod `sakina-postgres-0`, namespace `sakina-mobile-staging`, db `sakina_mobile_staging`, PostgreSQL 15.18 (Alpine).
**Auditor stance:** hostile, no fake PASS, live output only. `cargo` NOT run.
**Date:** 2026-06-06.

---

## 1. Files inspected

- `sakina-backend/db/migrations/001..021_*.sql` (21 repo migration files) — the source of truth schema.
- `sakina-backend/db/migrations/018_replace_fake_rag_seed_content.sql` — RAG seed replacement (read in full).
- Live cluster objects: deploy `sakina-backend`, secret `sakina-postgres-secret`, svc `sakina-postgres`, jobs `sakina-db-migrate` and `sakina-db-migrations`, configmap `sakina-db-migrations`, pod `sakina-postgres-0`.

## 2. Exact identifiers / line refs

- DB creds (from secret `sakina-postgres-secret`): user=`sakina_staging_user`, db=`sakina_mobile_staging`, password length=18 (masked).
- Backend `POSTGRES_HOST=sakina-postgres` -> ClusterIP svc 10.99.78.69:5432 -> pod `sakina-postgres-0`. **This is the DB the live backend uses.** Not Railway.
- Schemas (3 app): `public` (18 tables), `sakina_ai` (25 tables), `outbox` (1 table). Total app tables = 44.
- RLS: all 44 app tables `rowsecurity = t` (100%).
- Policies: `pg_policies` count = 86 (public 29, sakina_ai 56, outbox 1).
- Migration runner command (job spec): `for f in /migrations/*.sql; do psql ... -v ON_ERROR_STOP=1 -f "$f"; done` — no ledger table written.
- 018 line 56-67: real Quran starter chunks INSERT replacing placeholder `'verified chunk text'` / `'Verified Source'`.

## 3. Commands run (all via `kubectl -n sakina-mobile-staging exec sakina-postgres-0 -- psql -U sakina_staging_user -d sakina_mobile_staging`; KUBECONFIG=~/.kube/config-hetzner)

- `\dn` (schemas); `SELECT schemaname,count(*) FROM pg_tables GROUP BY 1`; `\dt *.*`
- `SELECT schemaname,tablename,rowsecurity FROM pg_tables WHERE schemaname IN ('public','sakina_ai','audit','outbox')`
- `SELECT count(*) FROM pg_policies`; `SELECT schemaname,tablename,policyname,cmd FROM pg_policies ORDER BY 1,2 LIMIT 100`
- `to_regclass` for schema_migrations / _sqlx_migrations / refinery_schema_history (all NULL); name regex search for migrat|version|flyway|liquibase (none).
- `to_regclass` for the 7 key tables.
- `information_schema.columns` for user_id / workspace_id / deleted_at.
- Row counts on rag_* and islamic_* and core tables; islamic content inspection; fake-leftover check.
- `kubectl logs job/sakina-db-migrate` and `kubectl logs job/sakina-db-migrations`; `kubectl get jobs`; `kubectl get configmap`.

## 4. Evidence files created (reports/ultimate-hostile-audit/)

- `186-incluster-db-schemas.txt` — 3 schemas.
- `187-incluster-db-tables.txt` — table counts + full app table list.
- `188-incluster-rls.txt` — RLS per table + 100% summary.
- `189-incluster-policies.txt` — 86 policies, detail.
- `190-incluster-migrations.txt` — no ledger; two-job analysis; full 001-021 applied log.
- `191-incluster-key-tables.txt` — key table to_regclass results.
- `192-incluster-isolation-columns.txt` — user_id/workspace_id/deleted_at coverage.
- `193-incluster-content-rowcounts.txt` — row counts + islamic content proof.

## 5. Failures found

- **No persisted migration ledger** (`schema_migrations` / `_sqlx_migrations` absent). Migrations are applied by a shell `psql -f` loop relying on `IF NOT EXISTS` idempotency. There is **no in-DB record of which migrations ran** — provenance comes only from k8s job logs (ephemeral). This is a real auditability gap (not data corruption).
- **Two competing migrate jobs exist:** `sakina-db-migrate` (4d7h old) applied only **001-012** (its configmap has 12 keys). The schema was only brought to 021 by a **second, freshly-run** job `sakina-db-migrations` (7 min old) that applied **all 001-021**. The stale 12-file job/configmap is a footgun — if it ever re-runs as the canonical migrator, it under-migrates.

## 6. Not-wired / orphan / missing tables

- `sakina_ai.rag_retrieval_audit` = **MISSING** (does not exist live).
- `sakina_ai.safety_classifications` = **MISSING** (does not exist live).
  - Both are **also absent from repo migrations 001-021** (grep returned no match). So these are auditor-expected names that the codebase never defined — missing-by-omission, not a failed migration. Brain decision tracing IS present via `sakina_ai.brain_decision_traces` (+ `brain_evaluation_results`, `brain_memory_events`, `agent_feedback`, `anonymous_learning_events`, `scholar_review_queue`).
- `public.rag_documents` / `rag_chunks` / `rag_embeddings` exist but are **empty (0 rows)** — the public RAG pipeline tables are unseeded; live RAG content lives in `sakina_ai.islamic_*` instead.

## 7. Fake / seed concerns

- **Resolved / clean.** Migration 018 deleted the placeholder rows (`'verified chunk text'`, `'Verified Source'`) and inserted real, attributed Quran chunks. Live verification:
  - `islamic_sources`: 1 row, `source_status=approved`, `review_status=verified` (key `quran-reference-guidance-en`).
  - `islamic_documents`: 1 row ("Quran Reference Guidance Starter Corpus").
  - `islamic_chunks`: 12 rows, real citations (Quran 1:1-7, 2:201, 2:286, 16:90, 49:13, 94:5-6, 103:1-3, 112-114, 2:183-184).
  - Fake-placeholder leftover check = **0 rows**.
- Content is **minimal but real and approved** (12 chunks = starter corpus, not production-scale). `local_sunni_topics` = 10 rows; `modules` = 3; `users` = 28 (real data). `waitlist` = 0.

## 8. Repairs

- None applied (read-only hostile audit). Recommended (not done): (a) adopt a real migration ledger or pin a single canonical migrate job and delete the stale 12-file `sakina-db-migrate` job + configmap; (b) decide whether `rag_retrieval_audit` / `safety_classifications` are required and add migrations, or drop them from expectations; (c) seed `public.rag_*` or formally retire them if `sakina_ai.islamic_*` is the real RAG store.

## 9. Live proof excerpts

```
List of schemas:  outbox | public | sakina_ai   (3)
tables: public=18, sakina_ai=25, outbox=1
RLS summary:  public 18/18, sakina_ai 25/25, outbox 1/1  (rowsecurity=t everywhere)
pg_policies total = 86  (public 29, sakina_ai 56, outbox 1)
ledger: public.schema_migrations=NULL  _sqlx_migrations=NULL  refinery_schema_history=NULL
key tables: audit_logs=OK  brain_decision_traces=OK  waitlist=OK  users=OK  auth_sessions=OK
            rag_retrieval_audit=MISSING  safety_classifications=MISSING
isolation: public.user_id x9 ; sakina_ai.user_id x16, workspace_id x14, deleted_at x7
rowcounts: rag_documents=0 rag_chunks=0 rag_embeddings=0
           islamic_sources=1(approved/verified) islamic_documents=1 islamic_chunks=12
           local_sunni_topics=10 users=28 modules=3 waitlist=0
fake-leftover chunks = 0
migrate job 'sakina-db-migrations' (7m old): Applying 001..021 -> "Sakina migrations applied"
stale job 'sakina-db-migrate' (4d7h old): Applying 001..012 only -> "Migrations complete"
```

---

## VERDICT: STAGING-DB = PASS (with 2 non-blocking caveats)

The real in-cluster staging DB `sakina_mobile_staging` has **all 21 repo migrations applied (001-021, schema matches repo)**, **RLS enabled on 100% of app tables (44/44) with 86 policies**, **audit/trace tables present** (`audit_logs`, `admin_audit_events`, `brain_decision_traces` + brain/feedback suite), **strong user/workspace isolation columns** (user_id on 25 tables, workspace_id on 14), and **real approved Islamic RAG content** (12 verified Quran chunks, no fake placeholders). Caveats: (1) no persisted migration ledger + a stale 12-file migrate job coexists; (2) `rag_retrieval_audit`/`safety_classifications` never defined anywhere and `public.rag_*` tables are empty.

**Railway dev DB comparison:** The earlier audit hit the WRONG database (Railway `switchback.proxy.rlwy.net`); this audit targets the correct in-cluster DB (`sakina-postgres` svc -> `sakina-postgres-0`, the exact DB the live `sakina-backend` deployment connects to), which — unlike the dev DB — is fully migrated to 021 with RLS, policies, and seeded approved content.
