# Sakina Ultimate Hostile QA Audit

**Date:** 2026-06-06
**Branch:** `qa-security-hardening` · **HEAD:** `d76ed634876a77d1e47699bee07596d7456105ac`
**Auditor:** main controller + 9 specialized sub-agents (evidence-backed, hostile)
**Cluster proven:** Hetzner/Talos `admin@ordinox-talos` (kubeconfig `~/.kube/config-hetzner`), 3 nodes `talos-138-201-202-174`, `talos-5h3-83r`, `talos-h93-b9x`
**Evidence folder:** `reports/ultimate-hostile-audit/`

---

## Final Verdict

**NOT READY — REAL BLOCKERS REMAIN**

## One-line reason

The core product pipeline (Ask-AI-Shaikh → JWT/auth → Brain → hybrid RAG → fatwa/citation gate → isolated LLM gateway → qwen2.5:3b on a distributed Ollama DaemonSet) and the **staging cluster DB** are genuinely real, wired, and fail-closed — but **several CRITICAL security/compliance gaps remain**: unauthenticated admin/audit-write endpoints, GDPR account-deletion that never executes (dead outbox), no auth rate-limiting, and the Ask path does not persist its trace/audit rows in staging.

## Honesty notes that overturn earlier assumptions

1. **The first DB audit hit the WRONG database.** The local `DATABASE_URL` points to a **Railway** dev DB (`switchback.proxy.rlwy.net`), which is unmigrated and has no RLS. The **real in-cluster staging DB** (`sakina-postgres-0` / `sakina_mobile_staging`) is fully migrated (001–021), RLS on 44/44 tables, 86 policies, audit/trace tables present, 12 real Quran chunks seeded. **Staging DB = PASS.**
2. **The "tinyllama not qwen2.5:3b" finding was a live drift, now repaired.** Repo HEAD + CI evidence intend `qwen2.5:3b`; live Ollama was serving `tinyllama` on a single node. The repo manifest declared a DaemonSet but pinned it to one node via a `ReadWriteOnce` PVC. **Fixed** (emptyDir per-node DaemonSet) and **proven: qwen2.5:3b on all 3 nodes**. Durable only once committed (CI re-applies the old committed manifest).
3. **The proof-script harness is trustworthy** — `set -euo pipefail`, real curl/psql/kubectl assertions, fail-closed; the 54 "fake-pass" grep hits are all anti-cheat flags/regex literals, not bypasses. The 242 evidence files contain real output.

---

## Top 20 Blockers

| Rank | Severity | Area | Failure | Evidence | Required Fix |
|------|----------|------|---------|----------|--------------|
| 1 | CRITICAL | Auth | `/v1/admin/*` (roles, scholars, source-approval) have **no JWT and no role check** → anyone can self-grant admin / mint "verified" scholars | `handlers/phase2.rs:318-363`; raw INSERT/SELECT `services/phase2.rs:1208,1332,1390`; no auth middleware `main.rs:597-599` | Require JWT + admin role on every `/admin/*` handler; fail closed |
| 2 | CRITICAL | Data deletion / GDPR | `POST /v1/account/delete-request` only writes audit + an `outbox.events('account_deletion_requested')`; **no consumer exists** → never deleted | `handlers/phase2.rs:486-540`; `rg account_deletion_requested` → 0 consumers; live `outbox.events` 100% DeadLetter | Implement a real deletion/anonymization worker; add to outbox relay allowlist |
| 3 | CRITICAL | Outbox / async | Relay allowlist is **inverted**: the only events the API produces (`account_deletion_requested`, `data_export_requested`) are NOT allowlisted → retried 5× → DeadLetter; `outbox.dead_letters` table **does not exist** → relay task crashes | `services/outbox_relay.rs:22-90,64-71`; live `191-observability-live.txt` | Fix allowlist to cover produced events; create `dead_letters` table or change path |
| 4 | CRITICAL | Audit integrity | `/v1/audit/logs`, `/v1/security/log`, `/v1/safety/*`, `/v1/events/*`, `/v1/rag/log-*` accept **unauthenticated** writes → audit-trail forgery | `handlers/phase2.rs:286-315,470,478,607-634` | Require JWT (+ service role where appropriate) |
| 5 | HIGH | Observability | Ask path **never persists a trace/answer** in staging — `brain_decision_traces` holds only proof fixtures; `ask_shaikh_answers` = 0 rows; async writer no-ops unless built `with_pool` | `services/brain_audit.rs:50`; live `191`; `sakina_ask.rs:203-289` | Ensure the Ask handler's audit writer is pool-backed and persists every ask |
| 6 | HIGH | Auth | **No rate limiting** on `/auth/login`, `/auth/register`, `/auth/refresh` (only waitlist throttled) → brute force / credential stuffing | `handlers/phase2.rs:31,58,70`; `main.rs:555` waitlist limiter only | Add per-IP/account rate limiting to auth endpoints |
| 7 | HIGH | LLM infra durability | Distributed Ollama 3-node + qwen2.5:3b proven live, but the **committed** `ollama.yaml` pins the DaemonSet to one node via RWO PVC; CI re-applies it and reverts the fix | live `302/303`; committed pre-fix `ollama.yaml` | Commit the emptyDir DaemonSet fix so CI deploys it |
| 8 | HIGH | Audit logging | HTTP `AuditMiddleware` is **stdout-only** (no DB write); only deletion/export persist to `audit_logs` | `middleware/audit.rs:1-5,66-74`; live `audit_logs` all `data_export_requested` | Persist request audit rows to DB |
| 9 | HIGH | "No isolated tech" | `GraphRagService` **dead** (0 callers); `MemoryEngine`, `McpConnectorRegistry`, `SemanticRouter` **decorative on Ask** (constructed in `main.rs`, never reached from `ask()`) | `services/graph_rag.rs:17`; `AGENT-brain-aia.md`; `sakina_ask.rs:340-347` DI surface | Wire into Ask path or remove |
| 10 | HIGH | Trace honesty | Hardcoded trace literals imply work not done: `context_compressed="compressed"`, `memory_action="no_sensitive_memory_write"`, `selected_agent="Mother Algorithm"` | `brain_controller.rs:196,216`; `sakina_ask.rs:214` | Emit real per-component trace values |
| 11 | HIGH | Mobile / store | **No hosted Privacy Policy URL** (in-app text only) — Apple + Google Data-Safety submission blocker | `compliance_screen.dart:93-97` | Publish privacy policy at a public URL |
| 12 | HIGH | Mobile / signing | Release keystore + `key.properties` git-ignored/untracked → clean/CI checkout builds an **unsigned** AAB | root `.gitignore:49`; `android/app/build.gradle.kts:50-57` | Move signing secrets into CI secret store |
| 13 | MEDIUM | Authz | Forgeable paywall: premium gated on client header `x-sakina-subscription-tier` | `handlers/rag.rs:185-196` (cf. correct DB check `modules.rs:159`) | Gate on DB entitlement, never a client header |
| 14 | MEDIUM | Fake data | `dashboard::get_guardrails` returns a **hardcoded fabricated** guardrail-event array (no DB, no auth) | `handlers/dashboard.rs:4` | Back with real data + auth, or remove |
| 15 | MEDIUM | Frontend safety | Chat screen parses `safety`/`safety_state` but **does not display** crisis/escalation/caveat banner (Library screen does) | `chat_screen.dart:137` vs `islamic_library_screen.dart:226-245`; parsed `api_service.dart:1105` | Render safety state + caveats on chat |
| 16 | MEDIUM | LLM infra hygiene | Legacy `ollama` Deployment + duplicate `ollama`/`ollama-inference` Services linger alongside `sakina-ollama` | live `173`, `176` | Remove legacy ollama Deployment + stale services |
| 17 | MEDIUM | Metrics | `/metrics` exposes only 4 gauges (2 static) — liveness stub | `handlers/ops.rs:3-32` | Add real app metrics |
| 18 | MEDIUM | NetworkPolicy | No enforced network isolation of Ollama — CNI is **Flannel** (no policy controller); netpol added but inert | live CNI `kube-flannel`; `networkpolicy-llm.yaml` | Add policy engine, or accept ClusterIP+no-ingress+no-backend-URL |
| 19 | MEDIUM | CI/CD coverage | CI lints the **prod** manifest tree, never renders the active staging kustomize; `smoke-tests.yaml` omitted from kustomization | `.github/workflows/*`; `kustomization.yaml:10-21` | Render+validate staging tree; include smoke-tests |
| 20 | LOW | Frontend | Dead screens (`*_module_screen.dart`, `StagingClientConfig`, `BrainChatResponse`); chat Feedback/Report perma-disabled; nav label "knowledge"→Library mismatch | `home_shell_screen.dart:88-92`; `chat_screen.dart:122` | Remove dead code; fix nav label |

---

## Frontend ↔ Backend Wiring Matrix (key live flows)

| Screen | Service method (file:line) | Backend route | Handler | Runtime dep | Status |
|--------|----------------------------|---------------|---------|-------------|--------|
| Chat / Ask AI Shaikh | POST (`chat_screen.dart:114`) | `/api/sakina/ask` (`main.rs:692`) | `handlers::sakina_ask::ask` | Brain→RAG→fatwa gate→gateway→qwen2.5:3b→DB | **WIRED** (safety state not shown → PARTIAL UI) |
| Multimodal Analyze | `api_service.dart:823` Multipart | `/api/multimodal/analyze` | `handlers::multimodal::analyze` | JWT+OCR/vision (fail-closed)+citation | **WIRED** |
| Islamic Library | `api_service.dart` | `/v1/islamic/*` | `handlers::islamic::*` | DB chunks + citations | **WIRED** |
| Auth | `AuthService` | `/auth/*`,`/v1/auth/*` | `handlers::phase2::*` | JWT+sessions+Argon2id | **WIRED** (no rate limit) |
| Quran/Prayer/Community | flag-gated | `/modules/*/status` | `handlers::modules::*` | feature flags (default OFF) | **PARTIAL** (honest fail-closed) |
| Base URL | `api_config.dart:2-5` env `SAKINA_API_BASE_URL` default `https://api.7jzi.com/v1` | — | — | — | **SAFE** (no localhost) |

Contract: no required field missing; citation shapes align; `local_db_context`/`graph_context` ignored by frontend (non-breaking).

---

## Backend Route Audit (summary)

~70 endpoints (`020-backend-routes.txt`). Ask-AI-Shaikh hop trace = **PASS**: AuthN (JWT+session+sub `auth.rs:121`) → PII redaction → safety pre-gate → Brain route+cost/policy gate (`brain_controller.rs:50`) → hybrid RAG (`hybrid_rag.rs:274`) → fatwa/citation validator (`islamic_knowledge.rs:357`) → Evaluation AI (blocks non-PASS `brain_controller.rs:274`) → LLM gateway (blocks w/o context `bin/llm_gateway.rs:111`) → DB persistence path. **Insecure clusters:** unauth `/v1/admin/*`, `/v1/audit|security|safety|events/*` (#1, #4).

---

## Security / Workspace Isolation Audit

**PASS:** JWT signature+expiry+fixed HS256 (no `alg=none`) `auth.rs:93-119`; revocation via `auth_sessions` `auth.rs:134-157`; refresh single-use rotation `phase2.rs:278-315`; **BOLA/IDOR clean** (path-param routes check JWT-sub==id, overwrite client id); Argon2id `phase2.rs:2065`; CORS explicit origins no wildcard `main.rs:404-428`; upload auth+10MiB+magic-byte+per-user private+owner-scoped retrieval `services/multimodal.rs:86-135`; secret scan clean.
**FAIL/PARTIAL:** #1–#6, #8, #13. RLS is enforced in staging DB (44/44, 86 policies) — the inert-RLS finding applied only to the Railway dev DB.

---

## LLM Gateway / Ollama Isolation Audit — PASS (isolation) / repaired (distribution)

- Backend uses `SAKINA_LLM_GATEWAY_URL` only; **no `OLLAMA_BASE_URL`** in backend (`services/llm_gateway.rs:55-56`; live env). `OLLAMA_BASE_URL` only on gateway (`bin/llm_gateway.rs:234`; live `http://sakina-ollama:11434`).
- Gateway requires `trace_id`+`workspace_id` (live negative → **HTTP 400**, `184/305`), blocks generation w/o allowed context (`bin/llm_gateway.rs:111-121`), controlled anti-hallucination prompt (`:26-59`), pre-redacted input (`sakina_ask.rs:369-370`).
- **Distributed Ollama (repaired live):** DaemonSet on all 3 nodes; **qwen2.5:3b per-node** (`302/303`); gateway `/health`=200 `/ready`=200 (`182/183`).

---

## RAG / Citation Audit — PASS

Real hybrid retrieval: keyword (sqlx ILIKE verified-sources `hybrid_rag.rs:92-93`) + vector (Qdrant `qdrant_client.rs:142` + vLLM embeddings `embeddings.rs:79`) + graph (`KnowledgeGraphService.lookup hybrid_rag.rs:286`). Grounding by deterministic fatwa gate (`sakina-wasm/fatwa-policy-gate/src/lib.rs:31-62`, called `islamic_knowledge.rs:357`) — rulings without approval+verified citation blocked; gateway refuses empty context. Caveat: WASM gate runs as **native** crate, not WASM. `GraphRagService` dead.

---

## DB / Migration Audit

- **Staging DB (`sakina_mobile_staging`, PG 15.18) = PASS:** migrations 001–021, RLS 44/44, 86 policies, isolation cols (`user_id`×25,`workspace_id`×14,`deleted_at`×7), audit/trace tables, 12 Quran chunks + 28 users seeded (`186–190`).
- **Caveats:** no persisted migration ledger; stale `sakina-db-migrate` job applied only 001–012; `rag_retrieval_audit`/`safety_classifications` absent (also absent from repo).
- **Railway dev DB = FAIL** but irrelevant to staging (`082-085`).

---

## Kubernetes / CI/CD Audit

- **Live:** 12 sakina namespaces Active; **no sakina pod in bad state** (`174`; unhealthy pods are other tenants). Backend 2/2, gateway 1/1, postgres/qdrant/redis up.
- **Manifests:** kustomize clean; probes+limits everywhere; consistent `ghcr-pull-secret`; hardened securityContext; no lawapp/iterlaw, no compose, no localhost.
- **Gaps:** NetworkPolicy inert (Flannel); legacy ollama Deployment + dup services; app images on mutable branch tag (CI repins to SHA `sakina-deploy.yml:317-346`); `smoke-tests.yaml` not in kustomization; CI lints prod not staging.
- **CI/CD (no fake-pass):** builds+pushes real GHCR images, pins SHA, applies real manifests, `set -euo pipefail`, fails on rollout/smoke/bad-pod. No `continue-on-error`/`|| true`/echo-pass on required steps.
- **kubeconfig:** default `kubectl` was the dead AKS `aks-iterlaw-we-prod`; correct = `~/.kube/config-hetzner` (`admin@ordinox-talos`).

---

## Fake / Mock / Placeholder Inventory

| File:line | Pattern | Reachable? | Disposition |
|-----------|---------|-----------|-------------|
| `handlers/dashboard.rs:4` | hardcoded guardrail JSON | yes (unauth) | **Remove/replace** (#14) |
| `brain_controller.rs:196,216`,`sakina_ask.rs:214` | hardcoded trace literals | yes (every Ask) | **Replace** (#10) |
| `handlers/modules.rs:275,313,351,389` | "coming soon / under review" | yes | **OK** — honest fail-closed |
| `main.rs:83-89` `fake_mode_disabled()` | ALLOW_MOCK_* gates | startup | **OK** — anti-fake guard |
| `services/embeddings.rs:80-81,121` | rejects `mock://` | runtime | **OK** — anti-fake guard |

No fabricated AI answers, no client-side fake LLM, no static-JSON-as-runtime in the product path other than #14. Scan: `011-runtime-source-fakes.txt`.

---

## Dead Code Inventory

Backend: `GraphRagService` (`graph_rag.rs:17`), `LlmService` (`services/llm.rs`), `offline_fallback` re-export (`mod.rs:63`), `qdrant_hit_to_citation` (`islamic_knowledge.rs:457`).
Frontend: `*_module_screen.dart` ×4, `StagingClientConfig`, `BrainChatResponse.fromJson`.
Decorative-on-Ask: `MemoryEngine`, `McpConnectorRegistry`, `SemanticRouter`.

---

## Runtime Smoke Results (live, command-backed)

| Check | Result | Evidence |
|-------|--------|----------|
| Talos nodes (3 Ready) | PASS | `171` |
| Sakina namespaces (12) | PASS | `172` |
| No sakina pod unhealthy | PASS | `174` |
| cargo check --all-targets | PASS (0) | `121` |
| Ollama DaemonSet 3 nodes + qwen2.5:3b | PASS (after fix) | `302,303` |
| Gateway /health,/ready | PASS (200) | `182,183` |
| Gateway rejects missing trace_id | PASS (400) | `184,305` |
| Gateway qwen2.5:3b generation | see `305` | `305` |
| Backend gateway URL, no OLLAMA_BASE_URL | PASS | live env |
| Staging DB RLS/policies/seed | PASS | `186-190` |
| Ask path persists trace | **FAIL** | `191` |
| Outbox GDPR events drained | **FAIL** | `191` |
| flutter analyze / build | UNPROVEN | no flutter CLI |
| gitleaks / trivy | UNPROVEN | binaries absent |

---

## Distributed LLM Architecture — 14-point Acceptance

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Talos context active | ✅ |
| 2 | `sakina-mobile-staging` reachable | ✅ |
| 3 | Ollama DaemonSet | ✅ (repaired) |
| 4 | Pods on all nodes | ✅ (3/3) |
| 5 | `qwen2.5:3b` visible | ✅ (`ollama list` per node) |
| 6 | gateway deployed | ✅ |
| 7 | `/health` | ✅ 200 |
| 8 | `/ready` | ✅ 200 |
| 9 | rejects missing trace_id/workspace_id | ✅ 400 |
| 10 | backend uses `SAKINA_LLM_GATEWAY_URL` | ✅ |
| 11 | backend no `OLLAMA_BASE_URL` | ✅ |
| 12 | Ask E2E backend→Brain→gateway→Ollama | ⚠️ PARTIAL (gateway generation proven; full backend Ask E2E not run — no ingress + needs auth) |
| 13 | GitHub Actions deploys same architecture | ⚠️ PARTIAL (committed manifest had 1-node PVC bug; fix must be committed) |
| 14 | No Sakina pod in bad state | ✅ |

**Distributed LLM status: PARTIAL — proven live, not durable until committed + full backend Ask E2E captured.**

---

## Repairs Made During This Audit

### R1 — Ollama DaemonSet distribution fix (live + repo)
- **Failure before:** `infra/k8s/sakina-mobile-staging/ollama.yaml` declared a DaemonSet but used a shared `ReadWriteOnce` PVC, pinning it to one node → `kubectl get ds sakina-ollama` DESIRED=1; only `talos-h93-b9x` ran Ollama; model served `tinyllama`.
- **Repair:** rewrote `ollama.yaml` — per-node `emptyDir`, pinned `ollama/ollama:0.5.7`, `qwen2.5:3b`, postStart auto-pull, model-gated readiness probe, control-plane toleration, resource req/limits. Added `networkpolicy-llm.yaml` (gateway-only Ollama ingress; backend egress excludes 11434 — declared; Flannel does not enforce). Added both to `kustomization.yaml`.
- **Proof after:** `rollout status ds/sakina-ollama` → "successfully rolled out"; `ollama list` on all 3 pods → `qwen2.5:3b 1.9 GB` (`302,303`).
- **Status:** applied live & proven; **must be committed** so CI stops reverting it (a concurrent CI deploy re-applied the old manifest mid-audit).

No other repairs applied — remaining findings reported as blockers (record-before-repair; no weaker tests; no placeholders).

---

## Required Repair Order (numbered, with verification)

1. **Authenticate `/v1/admin/*` + audit/security/safety/event writes.** Verify: `POST /v1/admin/roles` no-token → 401; non-admin → 403.
2. **Implement account deletion + fix outbox.** Real worker; add produced events to allowlist; create `outbox.dead_letters`. Verify: deletion → rows gone/anonymized; `outbox.events.status='Sent'`.
3. **Rate-limit `/auth/login|register|refresh`.** Verify: 11 rapid logins → 429.
4. **Persist Ask trace/audit** (pool-backed writer). Verify: one ask → new `brain_decision_traces` + `ask_shaikh_answers` row.
5. **Commit the Ollama DaemonSet + NetworkPolicy fix.** Verify post-CI: `ds/sakina-ollama` DESIRED=3 ready=3, qwen2.5:3b per node.
6. **Full backend Ask E2E** (register→login→`/api/sakina/ask`) showing trace_id, citations/caveat, gateway-routed LLM, DB row.
7. **Remove fakes/dead/decorative:** `dashboard::get_guardrails`, trace literals, `GraphRagService`/`LlmService`/dead frontend; wire-or-delete Memory/MCP/SemanticRouter on Ask.
8. **Fix forgeable paywall** (`rag.rs:185-196` → DB entitlement).
9. **Display safety/caveat on chat screen.**
10. **Mobile store-readiness:** privacy policy URL; signing secrets to CI; crash reporting.
11. **Hygiene:** remove legacy ollama Deployment + dup services; include `smoke-tests.yaml`; render staging kustomize in CI; persist HTTP audit to DB; real metrics.

---

## Acceptance Criteria for Re-audit

Passes only when: blockers #1–#6 fixed with negative-test proof; DaemonSet fix committed + CI-deployed (DESIRED=3); a full authenticated Ask E2E persists a trace row and returns citations/caveat through gateway+qwen2.5:3b; auth endpoints rate-limited; account deletion verified end-to-end; no fabricated/decorative runtime data in the product path.

---

## Sub-agent reports (inputs merged above)

`AGENT-backend-wiring.md`, `AGENT-frontend-wiring.md`, `AGENT-security.md`, `AGENT-llm-rag.md`, `AGENT-db.md` (Railway dev DB), `AGENT-incluster-db.md` (staging DB), `AGENT-k8s-cicd.md`, `AGENT-multimodal.md`, `AGENT-brain-aia.md`, `AGENT-observability.md`, `AGENT-mobile-release.md`, `AGENT-proof-scripts.md`. Raw evidence: `001`–`305` in this folder.
