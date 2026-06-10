# AGENT-db — Hostile DB Audit (SakinaAL)

Date: 2026-06-06
Auditor mode: hostile, evidence-only. DATABASE_URL set, psql 18.4. No cargo run.
**VERDICT DB: FAIL** (live DB does not match repo migrations; RLS claimed by 017 is NOT present live; 0 policies; audit/trace/workspace tables absent live).

---

## 1. Files inspected
- `sakina-backend/src/bin/migrate.rs` (migration runner)
- `sakina-backend/db/migrations/001_init_extensions.sql` … `021_sakina_mother_local_topics.sql` (21 files)
- `sakina-backend/db/migrations/017_rls_user_isolation.sql` (RLS)
- `sakina-backend/db/migrations/018_replace_fake_rag_seed_content.sql` (RAG seed)
- `sakina-backend/db/migrations/019_agent_feedback.sql` (audit_logs / agent_feedback)
- `sakina-backend/db/migrations/020_workspace_learning_core.sql` (workspaces / workspace_id / deleted_at)
- `sakina-backend/db/migrations/014_brain_knowledge_graph.sql` (brain_decision_traces)
- `sakina-backend/db/source-candidates/islamic-source-candidates.json`
- `sakina-backend/db/init.sql`, plus 3 phase SQL/MD files (listed in 080)

## 2. Key line numbers
- `migrate.rs:32-117` — static array of 21 migrations, each via `include_str!`.
- `migrate.rs:119-122` — loop `sqlx::raw_sql(sql).execute(&pool)`; **no schema_migrations tracking, no content_hash, no idempotency guard beyond each file's own `IF NOT EXISTS`**.
- `017_rls_user_isolation.sql:29-81` — dynamic `DO $$` loop enabling RLS + FORCE on every table in public/sakina_ai/audit/outbox and creating service + user_id policies.
- `017_rls_user_isolation.sql:3-18` — defines `sakina_ai.current_user_id()` and `sakina_ai.rls_service_role()` (live: BOTH ABSENT).
- `018_replace_fake_rag_seed_content.sql:3-19` — deletes placeholder rows (`'verified chunk text'`, `'verified citation'`, `'Verified Source'`).
- `018_...sql:51-77` — inserts 12 REAL Quran reference chunks (Quran 1:1-7, 2:201, 2:286, 16:90, 49:13, 94:5-6, 103, 112, 113, 114, 2:183, 2:184), status approved/verified.
- `019_agent_feedback.sql:3-11` — `public.audit_logs` (NOTE: no user_id; actor-based). `019:53-54` agent_feedback has trace_id + user_id.
- `020_workspace_learning_core.sql:1,14-39,46-104` — `sakina_ai.workspaces`, `workspace_id` columns, `deleted_at` columns.
- `014_brain_knowledge_graph.sql:24` — `sakina_ai.brain_decision_traces`.

## 3. Commands run (all live, real output captured)
```
find sakina-backend/db -type f | sort                                  EXIT=0
rg -n "CREATE TABLE|...|trace" sakina-backend/db                        EXIT=0 (684 hits)
psql "$DATABASE_URL" -c "\dn"                                           EXIT=0
psql "$DATABASE_URL" -c "\dt *.*"                                       EXIT=0 (481 user tables)
psql "$DATABASE_URL" -c "SELECT ... rowsecurity FROM pg_tables ..."     EXIT=0 (191 rows, all f)
psql "$DATABASE_URL" -c "SELECT ... FROM pg_policies ..."               EXIT=0 (0 rows)
psql "$DATABASE_URL" -c "SELECT * FROM public.schema_migrations ..."    EXIT=0 (26 rows)
psql "$DATABASE_URL" -c "to_regclass(...sakina_ai.islamic_*...)"        EXIT=0 (all NULL)
psql "$DATABASE_URL" -c "to_regprocedure(sakina_ai.current_user_id())"  EXIT=0 (NULL)
psql "$DATABASE_URL" -c "to_regclass(audit_logs/brain_decision_traces/rag_retrieval_audit/safety_classifications)" EXIT=0 (all NULL)
psql ... column scan user_id/workspace_id/deleted_at/retention          EXIT=0
```

## 4. Evidence files created
- `reports/ultimate-hostile-audit/080-db-files.txt` (26 files)
- `reports/ultimate-hostile-audit/081-db-schema-scan.txt` (684 lines)
- `reports/ultimate-hostile-audit/082-db-schemas-live.txt` (public, sakina_ai)
- `reports/ultimate-hostile-audit/083-db-tables-live.txt` (481 user tables)
- `reports/ultimate-hostile-audit/084-db-rls-live.txt` (191 rows, rowsecurity all `f`)
- `reports/ultimate-hostile-audit/085-db-policies-live.txt` (0 rows)

## 5. Failures (hostile findings)
**F1 — CRITICAL: Live DB is NOT built from this repo's migrations.**
Live `public.schema_migrations` records 26 migrations named `001_sakina_foundation.sql … 026_rahma_content_sources_licence_status_alias.sql` (applied 2026-05-18/19). NONE of these filenames exist in this repo (`glob 001_sakina_foundation.sql`, `026_rahma_...` → No files found). The repo's `migrate.rs` embeds a DIFFERENT set (`001_init_extensions.sql … 021_sakina_mother_local_topics.sql`). The repo migration runner has never run against this DB.

**F2 — CRITICAL: RLS completely absent live.** `084` shows all 191 public/sakina_ai tables `rowsecurity = f`. `085` shows **0 policies**. Migration `017_rls_user_isolation.sql` (which would enable RLS + create per-table policies) was never applied. The functions it defines (`sakina_ai.current_user_id`, `sakina_ai.rls_service_role`) do not exist live (to_regprocedure → NULL). User data isolation at the DB layer is UNENFORCED.

**F3 — HIGH: 018 RAG-seed migration is inapplicable to live DB.** 018 operates on `sakina_ai.islamic_chunks / islamic_documents / islamic_sources`. Live: all three `to_regclass` → NULL. Live RAG data lives in differently-named tables (`public.islamic_source_chunks`, `islamic_documents`(public), `islamic_source_documents`, `rag_chunks`, `rag_documents`, etc.). 018 would also FAIL on a fresh apply unless 001-016 created those sakina_ai tables (they reference user_memory_entries etc.).

**F4 — HIGH: Audit/trace tables from task #5 do not exist live.** `audit_logs`, `brain_decision_traces`, `rag_retrieval_audit`, `safety_classifications` all → NULL. The live DB has a different audit family: `audit_events`, `admin_audit_log`, `content_audit_log`, `privacy_audit_log`, `ibadat_audit_log`, `sakina_answer_audit`, `sakina_sheikh_audit_log`, `self_improvement_audit_log`, `rag_query_audit`, `islamic_rag_query_audit`, `wasm_*_audit`, plus `rag_retrieval_logs`. Naming contract between repo and live DB is broken.

**F5 — HIGH: No workspace isolation live.** 0 tables in live DB have `workspace_id`. Repo migration 020 introduces `workspace_id` + `sakina_ai.workspaces`, never applied.

**F6 — MEDIUM: No soft-delete / retention live.** 0 tables have `deleted_at`; only 1 table (`data_processing_records`) has any retention column (`retention_until`). Repo 020 adds `deleted_at` to multiple sakina_ai tables; never applied.

**F7 — MEDIUM: migrate.rs has no migration ledger.** `migrate.rs:119-122` runs every embedded file every time with no record in any schema_migrations table and no content_hash check — divergent from the ledger style the live DB actually uses (filename/applied_at/content_hash columns). Re-running relies solely on per-statement `IF NOT EXISTS`; `017`'s blanket `ENABLE ROW LEVEL SECURITY` and policy DROP/CREATE are idempotent, but there is no drift detection.

## 6. Not-wired / orphan tables & unused migrations
- **Entire repo migration set (001-021 in `migrate.rs`) is unused against the current live DB** — different lineage. They are the *intended* schema but unverified live.
- Orphan/unverified live objects relative to repo: 481 live public tables vs the handful the repo migrations create in `public` (users, audit_logs, etc.). The bulk of live tables (charity_*, children_*, hadith_*, quran_*, ibadat_*, scholar_*, wasm_*, etc.) come from the rahma lineage not present in this branch's `db/migrations`.
- `sakina_ai` schema live = only `conversations`, `messages`, `waitlist`. Repo migrations 014/015/019/020 expect many more `sakina_ai` tables (brain_decision_traces, user_memory_entries, agent_feedback, workspaces, user_learning_preferences, habit_signals) — NONE exist live.

## 7. Fake / seed concerns
- Repo `018_replace_fake_rag_seed_content.sql` is **legitimately real** content: it removes placeholder rows and inserts 12 genuine Quran-reference chunks with correct citations (file:51-64). No fake "lorem"/placeholder remains in the seed. GOOD — but it is NOT applied to the live DB, so it neither helps nor harms live data.
- `db/source-candidates/islamic-source-candidates.json` lists real, named sources (Tanzil Quran Text, Al Quran Cloud API) with licence/attribution metadata and `source_approved_default: false`. Legitimate, not fabricated.
- Cannot confirm live RAG tables (`islamic_source_chunks`, `rag_chunks`) contain real vs placeholder content from migration scan alone — that lineage's seed SQL is not in this repo branch. **UNPROVEN** for live RAG content authenticity.

## 8. Repairs
None applied. Nothing trivial — the core issue (live DB built from a different migration lineage than this branch's `migrate.rs`) is a release/deployment decision, not an in-place fix. Do NOT blindly run repo migrate.rs against this live DB: 017 would enable FORCE RLS on all 481 tables while the app likely does not set `sakina.service_role`/`sakina.current_user_id`, which could lock out all queries; and 018/020 reference tables that don't exist live.

## 9. Live proof excerpts

### Live schemas (082)
```
 public    | pg_database_owner
 sakina_ai | postgres
```

### RLS coverage (084) — representative; ALL 191 rows = f
```
 public | users          | f
 public | user_profiles  | f
 public | chat_messages  | f
 public | payment_customers | f
 sakina_ai | conversations | f
 sakina_ai | messages      | f
```

### Policies (085)
```
 schemaname | tablename | policyname | cmd
------------+-----------+------------+-----
(0 rows)
```

### Functions expected by 017 (live)
```
 sakina_ai.current_user_id()  -> NULL (absent)
 sakina_ai.rls_service_role() -> NULL (absent)
```

### Tables expected by 017/018 (live)
```
 islamic_chunks | islamic_documents | islamic_sources -> all NULL
 conversations  | sakina_ai.conversations
 messages       | sakina_ai.messages
```

### Audit/trace tables (task #5, live)
```
 audit_logs | brain_decision_traces | rag_retrieval_audit | safety_classifications
        NULL                    NULL                  NULL                     NULL
```

### Live applied migrations (schema_migrations, first/last)
```
001_sakina_foundation.sql ... 026_rahma_content_sources_licence_status_alias.sql  (26 rows)
```

---

## RLS coverage table (live, key user-data tables)
| table | rowsecurity | has policy | has user_id/workspace_id |
|---|---|---|---|
| public.users | f | no | (id PK; no user_id col) |
| public.user_profiles | f | no | user_id ✓ / workspace ✗ |
| public.user_sessions | f | no | user_id ✓ / ✗ |
| public.user_subscriptions | f | no | user_id ✓ / ✗ |
| public.chat_conversations | f | no | user_id ✓ / ✗ |
| public.chat_messages | f | no | user_id ✗ / ✗ |
| public.payment_customers | f | no | user_id ✓ / ✗ |
| public.invoices | f | no | user_id ✓ / ✗ |
| public.zakat_calculations | f | no | user_id ✓ / ✗ |
| public.user_notifications | f | no | user_id ✓ / ✗ |
| sakina_ai.conversations | f | no | (no workspace_id live) |
| sakina_ai.messages | f | no | (no workspace_id live) |
| ALL 191 tables | **f** | **none (0 policies)** | **0 with workspace_id** |

Live totals: 49 public tables have `user_id`; 0 have `workspace_id`; 0 have `deleted_at`; 1 has `retention_until`.

## Repo migration integrity (the intended schema, NOT applied live)
- 21 SQL files, sequential `001`–`021`, **no gaps, no duplicate numbers**.
- `migrate.rs` embeds **all 21** via `include_str!` (21 `include_str!` calls == 21 files), applied in array order. No file skipped. PASS on file-embedding/ordering.
- BUT no ledger/hash tracking (F7).

## VERDICT: **DB FAIL**
The committed migrations are internally well-formed (ordered, fully embedded, real RAG seed), but the **running database does not correspond to them**: it was provisioned from a separate `sakina_foundation/rahma` migration lineage absent from this branch. Consequently the security controls this audit was asked to verify — RLS user isolation (017), real-RAG seed (018), workspace isolation (020), and the named audit/trace tables — are **NOT present in the live DB** (RLS off on all 481 tables, 0 policies, isolation functions/tables absent). Live RAG content authenticity is **UNPROVEN** (that lineage's seed is not in this repo).
