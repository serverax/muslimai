# Sakina AI — Full Deep QA Audit

Date: 2026-06-22 · Branch: `qa-security-hardening` · Auditor: senior QA / security / readiness owner
Evidence root: `test-results/audit-2026-06-22/` and `reports/sakina-issue-register.md`
Method: 5 parallel static-analysis investigators over the full repo + **live Docker-Compose runtime proof** (qa stack, api on `localhost:28080`, real Postgres 15 + Qdrant + Redis, 28 migrations applied to a clean DB).

---

## 1. Executive verdict

**SAKINA AI NOT READY — FAILURES REMAIN.**

The system is far more real than a prototype: the Rust/actix-web backend compiles and boots, the Ask Shaikh happy path returns a genuinely cited answer with a persisted trace, high-risk fatwa questions escalate to a real scholar-review queue row, and per-user trace isolation holds at runtime. But the audit found **6 CRITICAL** and **8 HIGH** issues that block go-live, including: every `/admin/*` and scholar route is **completely unauthenticated with no RBAC**, anonymous callers can **inject audit/safety records**, the self-harm crisis classifier **misses common phrasings and then errors out**, and — before this session's repairs — the stack **could not even boot Postgres** and **no user could register**. Two CRITICALs (boot, registration) were fixed and verified during the audit; the rest remain OPEN.

## 2. Current readiness status

| Dimension | Status |
|---|---|
| Local Docker E2E (datastores + api) | PARTIAL PASS (after 2 fixes; ollama not co-located) |
| DB migrations on clean DB | PASS (28/28) |
| Auth / registration / login | PASS (after SAK-003 fix) |
| Ask Shaikh (safe) + citations + trace | PASS |
| High-risk fatwa escalation | PASS |
| Crisis / self-harm handling | FAIL (recall gap, SAK-004) |
| Admin / scholar RBAC | CRITICAL FAIL (SAK-001) |
| User isolation (trace) | PASS; (dashboard) FAIL (SAK-007) |
| Secrets in repo | PASS (`.env` gitignored); HIGH in distributed compose (SAK-013) |
| Kubernetes runtime | UNPROVEN (no live cluster) |
| CI/CD | Recent commits green-unblocked; not re-run this session |
| Frontend↔backend wiring | PASS (real, no direct-LLM); two stub screens |

## 3. Architecture understanding

Highest-priority flow as implemented (`/api/sakina/ask`, actix-web `main.rs:703`):
`auth → workspace ensure → PII redact → language/intent (keyword) → trace_uuid → local_sunni_topics lookup → [rules engine if SAKINA_RULES_ENGINE_URL] → safety classifier (keyword) → brain route (only can_generate read) → hybrid RAG (SQL+embeddings+Qdrant+graph) → [LLM compose, gated] → [citation guard if SAKINA_CITATION_GUARD_URL] → empty-answer refusal fallback → persist trace + answer → return → enqueue scholar review if high-risk`.

Two deployment topologies: **monolithic** (one `sakina-api` binary does brain/rules/rag/citation internally — what qa.yml runs) and **distributed microservices** (`docker-compose.distributed.yml`: api-gateway, brain, rules-engine, rag-service, citation-guard, llm-gateway, ollama). A second, cleaner answer engine (`decision_algorithm::decide`) exists with hard citation gating but is **dead** (wired to `EmptyRetriever`) — see SAK-021.

## 4. Service inventory

| Service | Lang | Image/bin | Port | Health | Notes |
|---|---|---|---|---|---|
| api | Rust/actix | `sakina-backend:latest` (`sakina-api`) | 28080→8080 | `/health`,`/readiness` | monolithic; verified UP, db connected |
| llm-gateway | Rust | `sakina-llm-gateway` | 8087/8080 | — | only component allowed to call Ollama |
| ollama | — | `ollama/ollama` | 11434 | — | NOT co-located this run (host port held by another project) |
| postgres | — | `postgres:15-alpine` | 5433→5432 | `pg_isready` | verified; init.sql repaired |
| qdrant | — | `qdrant/qdrant:v1.10.1` | 6333 | — | up |
| redis | — | `redis:7-alpine` | 6380→6379 | — | up |
| migrate | Rust | `sakina-migrate` | — | — | 28 migrations applied clean |

## 5. Frontend / mobile audit
Flutter app (`sakina-frontend`). Real `package:http` client → api-gateway (`api_config.dart` default `http://localhost:8080/v1`). **Direct-LLM check PASS** (no ollama/openai/11434 calls). JWT in `flutter_secure_storage`, sent as Bearer. Wired: auth, Ask Shaikh, Islamic Library, modules, iman-journey, multimodal, compliance, support. **Stubs/violations:** Kids Quran static, Tajweed Coach shows fabricated "92% accurate" feedback (SAK-019). Missing screens: qibla, zakah, inheritance, masjid-near-me, scholar/admin. RTL only in Islamic Library (SAK-023). Detail: `test-results/audit-2026-06-22/agent-frontend.md`.

## 6–7. Backend / API gateway audit
actix-web, ~120 routes across `/`, `/v1`, `/api`. Auth is **per-handler opt-in** (no middleware backstop; the only `.wrap()` is logging-only AuditMiddleware that always logs `anonymous`). Most user routes correctly call `authenticated_user_id` + `WHERE user_id=$2`. **Admin/scholar/event/audit routes omit auth entirely** (SAK-001). Full route table: `agent-routes-auth.md`.

## 8–9. Brain / mother algorithm & rules engine
Brain route (`aia.route()`) runs but is **cosmetic** — only `can_generate` is consumed; the computed `requires_escalation`/`review_required` policy flags are never read. Rules engine only active in distributed mode (`SAKINA_RULES_ENGINE_URL`). Real gating is the keyword if/else chain.

## 10. RAG audit
`HybridRagService` is real (SQL keyword over `sakina_ai.islamic_chunks` + OpenAI-compatible embeddings + Qdrant REST + graph fusion). Degrades silently to keyword-only on embeddings/Qdrant error (`hybrid_rag.rs:176-182`). Empty retrieval → refuses (no hallucination), verified. Runtime safe answer returned a real Quran 5:6 citation.

## 11. LLM gateway / Ollama audit
Backend reaches the LLM **only** via the gateway (unit-tested). Ollama is internal by network only (no app-layer auth). Gated by `SAKINA_LLM_ENABLED` + context + safety + citation; default-closed verified. **But** when the gateway is unreachable the ask path returns 502 rather than degrading (SAK-010).

## 12. Database / migration audit
28 migrations applied cleanly to a fresh DB (after SAK-002/003 fixes): public 31 tables, sakina_ai 77. Runner embeds migrations via `include_str!`, **no version tracking**, some non-idempotent `CREATE POLICY` (SAK-020). Missing: `kids_game_progress`, `scholar_accounts` (SAK-008), subscription/payment tables (SAK-012). Dual `public.users` (SAK-014). Full detail: `agent-db-schema.md` / `reports/sakina-db-audit.md`.

## 13. Auth / JWT / isolation audit
Argon2id passwords, JWT HS256 with ≥32-char secret enforced + DB-session binding (good). Hand-rolled verify has non-constant-time compare and skips alg/iss/aud (SAK-016). User isolation enforced at the **application layer** (RLS is bypassed for the app role, SAK-006). Runtime: user B reading user A's trace → **404** (PASS); dashboard leaks all users (SAK-007).

## 14. Scholar workflow audit
Escalation **write** works end-to-end (runtime: fatwa → `scholar_review_queue` row, status pending/high, request_id = trace_id). **But** no queue-read API, resolved answers never delivered back to users, crisis never enqueues (SAK-009). `scholar_accounts` table missing (SAK-008).

## 15. Islamic safety audit
- Normal worship (wudu): cited answer, ALLOWED_WITH_GUARDRAILS ✓
- High-risk fatwa (divorce): ESCALATED_TO_HUMAN + queue row ✓
- Crisis "suicide": CRISIS_ESCALATION, safe message, no LLM ✓
- Crisis "harm myself / end my life": **missed → 502** ✗ (SAK-004, CRITICAL)
- Citation enforcement: happy path cited, but unguarded in monolithic mode (SAK-005).

## 16. Quran / Tafseer / Hadith / Fatwa source audit
Relational schema present (022 quran/tafsir, 023 hadith/fatwa). Runtime citation referenced Tanzil Project Quran 5:6 (grade "high"). Corpus population not load-tested.

## 17–18. Public vs authenticated feature audit
Public (no login): health, metrics, waitlist, classify, several rag/islamic read endpoints (some over-exposed — info disclosure SAK-015). Authenticated: ask, chat, memory, multimodal, history, profiles, subscriptions, iman-journey. The named public tools in the spec (prayer times, qibla, zakah, inheritance, masjid) are **not implemented as standalone endpoints/screens**.

## 19. Admin / scholar dashboard audit
CRITICAL: unauthenticated and unauthorized (SAK-001). Dashboard guardrails endpoint leaks cross-user data (SAK-007).

## 20–22. Security / secrets / dependency audit
Parameterized SQL (no injection), CORS allowlist, fail-closed mock gating, gitleaks in CI = good. HIGH: no auth-endpoint rate limiting (SAK-011), hardcoded secrets in distributed compose (SAK-013). `cargo audit` not run (host cargo blocked by Application Control policy — dependency CVE scan UNPROVEN this session). Detail: `reports/sakina-security-findings.md`.

## 23. Docker Compose audit
qa.yml works after init.sql repair. `version:` attribute obsolete (warning). Distributed compose rebuilds the same image 6× and commits secrets. ollama host-port conflicts with other projects on 11434.

## 24. Kubernetes / Talos audit
Manifests exist under `sakina-infra/manifests` + `k8s/` + helm. **No live cluster available** in this environment (kubectl client only). Runtime k8s proof **UNPROVEN** — see `reports/sakina-k8s-runtime-audit.md`.

## 25. CI/CD audit
`.github/workflows` includes secret-scan (gitleaks 8.24.3) and deploy. Recent commit history is a string of "unblock CI" fixes; CI not independently re-run this session. Treat green CI as necessary-not-sufficient given the runtime CRITICALs above.

## 26. Observability / audit-trace audit
Every non-distributed answer persists a trace (`brain_decision_traces` + `ask_shaikh_answers`) — verified. AuditMiddleware logs requests but never resolves the real user (always `anonymous`). Audit tables are writable by anonymous callers (SAK-001).

## 27–28. Issues & severity
See `reports/sakina-issue-register.md`: 6 CRITICAL (SAK-001..006), 8 HIGH (SAK-007..014), 9 MEDIUM (SAK-015..023), 4 LOW (SAK-024..027). Two CRITICAL fixed this session (SAK-002, SAK-003).

## 29. Repair plan — see `reports/sakina-repair-plan.md`.
## 30. Go-live blockers — see `reports/sakina-go-live-blockers.md`. Top: SAK-001, SAK-004, SAK-005, SAK-006/007, SAK-008/009.

## 31. Commands executed (evidence)
- `docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .` → image built (177MB).
- `docker compose -f sakina-infra/docker-compose.qa.yml … up -d postgres qdrant redis` (after `down -v`).
- `… run --rm api sakina-migrate` → `Sakina migrations applied: 28`.
- `… up -d --no-deps api llm-gateway` → api healthy (`/health` db connected, `/readiness` ready).
- Full curl proof sequence → `test-results/audit-2026-06-22/runtime-proof.txt`.

## 32. Evidence file paths
- `test-results/audit-2026-06-22/runtime-proof.txt`
- `test-results/audit-2026-06-22/agent-routes-auth.md`, `agent-db-schema.md`, `agent-pipeline.md`, `agent-security.md`, `agent-frontend.md`
- `reports/sakina-issue-register.md` and the supporting reports listed in §30.

## 33. Final PASS/FAIL matrix

| Capability | Verdict | Proof |
|---|---|---|
| Postgres boots (clean) | PASS (after fix) | docker logs, no init errors |
| 28 migrations | PASS | migrate stdout |
| Register / login | PASS (after fix) | 201 + JWT |
| Ask Shaikh safe + citation | PASS | runtime-proof §2 (Quran 5:6) |
| Trace persisted | PASS | trace_id + DB |
| High-risk fatwa escalation | PASS | scholar_review_queue row |
| Crisis (matched) | PASS | CRISIS_ESCALATION |
| Crisis (unmatched phrasing) | FAIL | 502 |
| Citation hard-gate (monolithic) | FAIL | SAK-005 |
| User isolation (trace) | PASS | B→A 404 |
| User isolation (dashboard) | FAIL | SAK-007 |
| Protected route w/o token | PASS | 401 |
| Admin/scholar RBAC | FAIL | no 401; SAK-001 |
| Anonymous audit injection | FAIL | 201 row written |
| Secrets in repo | PASS | .env gitignored |
| K8s runtime | UNPROVEN | no cluster |
| Dependency CVE scan | UNPROVEN | host cargo blocked |

**Verdict: SAKINA AI NOT READY — FAILURES REMAIN.**
