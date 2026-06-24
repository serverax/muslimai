# Sakina AI — Repair Plan

Date: 2026-06-22. Ordered per master directive (critical security → auth → DB → ask → scholar → RAG → LLM → wiring → tools → gates → k8s → CI → UX → docs).

## Already fixed this session (verified)
| ID | Change | File | Verify | Before → After |
|---|---|---|---|---|
| SAK-002 | Guard `CREATE USER` in `DO $$ IF NOT EXISTS pg_roles $$`, `CREATE TABLE IF NOT EXISTS` | `sakina-backend/db/init.sql` | `docker logs postgres` | container-exit → boots clean |
| SAK-003 | Add guarded full `UNIQUE (email)` constraint | `sakina-backend/db/migrations/002_users_profiles.sql` | `curl /auth/register` | 500 → 201+JWT |
| SAK-014 (partial) | `pub_key` nullable in init.sql | `sakina-backend/db/init.sql` | register w/o pub_key | NOT NULL violation → ok |

## P0 — CRITICAL (block go-live)
1. **SAK-001 Auth+RBAC on admin/scholar/event routes.** Add an actix auth extractor/middleware resolving the JWT user + a role guard. Require `admin` on `/admin/*`, `scholar` on scholar routes, authentication on `/v1/audit/*`,`/v1/security/*`,`/v1/events/*`,`/v1/safety/*`,`/v1/notifications/templates`,`/v1/auth/sessions`. Add role column/table + `require_role()`. Test: anon→401, wrong-role→403, correct→2xx.
2. **SAK-004 Crisis recall + safe fallback.** Broaden crisis matcher (phrases incl. "harm myself","hurt myself","end my life","don't want to live", Arabic) or small classifier; crisis response must NEVER call LLM and never 5xx. Test: all 4 crisis phrasings → CRISIS_ESCALATION.
3. **SAK-005 Local citation/verified-source hard gate.** Before returning any Islamic answer require ≥1 verified citation OR convert to scholar-review/refusal (port `generated_from_verified_sources`). Test: empty-citation topic → refusal.
4. **SAK-006 Real RLS isolation.** Connect app as dedicated non-allowlisted role (`sakina_app`); remove `current_user IN (...)` shortcut from `rls_service_role()`; drive isolation by GUC. Test: GUC user B → 0 rows of user A.

## P1 — HIGH
5. SAK-007 Scope `dashboard::get_guardrails` to caller (or require admin).
6. SAK-008 Migration creating `public.scholar_accounts` (+FK).
7. SAK-009 `GET /scholar/queue` (scholar role) + deliver `scholar_resolved_answers` back to conversation; enqueue crisis.
8. SAK-010 LLM-gateway failure → grounded refusal (200), not 502.
9. SAK-011 Rate-limit + lockout on `/auth/login` & `/auth/register`.
10. SAK-012 Build subscription/payment schema or remove dangling refs.
11. SAK-013 Replace hardcoded secrets in `docker-compose.distributed.yml` with `${VAR:?required}`.
12. SAK-014 Make `init.sql` not own `public.users`.

## P2 — MEDIUM
13. SAK-015 auth on `/health/observability`, `/api/brain/audit/recent`.
14. SAK-016 constant-time JWT compare; validate `alg`/`iss`/`aud`.
15. SAK-017 stronger PII redaction before LLM.
16. SAK-018 real prompt-injection/content-safety check; rename `guardrails.rs`.
17. SAK-019 remove fabricated Tajweed "92%" feedback; flag Kids Quran coming-soon.
18. SAK-020 migration version tracking; guard `CREATE POLICY`.
19. SAK-021 wire `decide` engine with a real retriever or delete it.
20. SAK-022 propagate `enqueue_scholar_review` errors.
21. SAK-023 RTL Ask/Chat screen; use `CitationBadge`.

## P3 — LOW
22. SAK-024 delete junk `:` file + phantom `reports\r` dir; normalize CRLF.
23. SAK-025 remove empty `sakina-backend/migrations/` dir.
24. SAK-026 FK indexes + CHECK constraints.
25. SAK-027 replace 2 non-test `expect()`s.

Every repair records: file · why · test command · test result · before/after.
