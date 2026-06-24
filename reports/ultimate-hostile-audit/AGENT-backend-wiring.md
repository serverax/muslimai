# Hostile QA Audit — SakinaAL Rust Backend Wiring

Scope: `sakina-backend/src` — routes (`main.rs`), `handlers/`, `services/`, `models/`.
Method: static-only (`rg`/Read). No `cargo` run. Treated as guilty until proven wired.
Route map saved to `reports/ultimate-hostile-audit/020-backend-routes.txt`.

Verdict legend: WIRED = real service/sqlx + fail-closed; PARTIAL = real but a defect (forgeable auth / no auth where data is touched); FAKE = static/hardcoded JSON posing as live data; DEAD = defined, never referenced; STATUS-OK = honest fail-closed status/“coming soon”.

---

## Route → Handler → Service wiring table

| Route | Handler (file:line) | Service / sqlx (file:line) | Auth? | User/WS ownership? | DB/Qdrant/LLM? | Status |
|---|---|---|---|---|---|---|
| POST /api/sakina/ask | sakina_ask::ask (sakina_ask.rs:340) | AiaOrchestrator.route + answer_islamic (aia_orchestrator.rs:55,113); LLM gateway (llm_gateway.rs:71); persist_trace (sakina_ask.rs:203) | YES (sakina_ask.rs:348) | ensure_default_workspace (sakina_ask.rs:361) | DB+Qdrant+LLM | WIRED |
| POST /api/chat | chat::core_chat (chat.rs:197) | aia.answer_islamic (chat.rs:273); persist (chat.rs:306) | YES (chat.rs:205) | ensure_default_workspace (chat.rs:225) | DB+Qdrant | WIRED |
| POST /v1/chat/conversations | chat::create_conversation (chat.rs:451) | sqlx INSERT conversations (chat.rs:499) | YES (chat.rs:457) | user_id match (chat.rs:475); INSERT binds auth id (chat.rs:506) | DB | WIRED |
| GET /v1/chat/conversations/{id} | chat::get_conversation (chat.rs:530) | sqlx WHERE id+user_id (chat.rs:540) | YES (chat.rs:536) | WHERE user_id=$2 (chat.rs:545) | DB | WIRED |
| POST /v1/chat/.../messages | chat::add_message (chat.rs:613) | conversation ownership check (chat.rs:642); aia.answer_islamic (chat.rs:668) | YES (chat.rs:637) | WHERE user_id=$2 (chat.rs:643) | DB+Qdrant | WIRED |
| POST /v1/islamic/ask, /islamic/ask | islamic::ask (islamic.rs:90) | aia.answer_islamic→IslamicAnswerService.answer (islamic_knowledge.rs:273) | NO (public Islamic Q&A) | n/a (no user data) | DB+Qdrant | WIRED (public-read, acceptable) |
| GET /v1/islamic/sources, /documents, /chunks, /search, /citation | islamic.rs:32–88 | IslamicKnowledgeRepository sqlx (islamic_knowledge.rs:31–219) | NO | n/a (verified public corpus) | DB | WIRED (public-read) |
| POST /api/rag/search | rag::api_rag_search (rag.rs:120) | HybridRagService.search (hybrid_rag.rs:274) | NO | n/a | DB+Qdrant | WIRED (evidence-only) |
| POST /v1/rag/query | rag::query_rag (rag.rs:55) | embeddings.embed + qdrant.search + guardrails (rag.rs:74–90) | NO | n/a | Qdrant+vLLM | WIRED (evidence-only) |
| GET /v1/rag/sources | rag::rag_sources (rag.rs:266) | approved_sources_from_db sqlx (rag.rs:198) | **forgeable header only** (rag.rs:185) | none | DB | **PARTIAL** |
| GET /v1/rag/search | rag::rag_search (rag.rs:311) | approved_sources_from_db (rag.rs:198) | **forgeable header only** (rag.rs:185) | none | DB | **PARTIAL** |
| POST /v1/rag/decide | rag::rag_decide (rag.rs:257) | aia.decide (aia_orchestrator.rs:86) | NO | n/a | in-mem decision | WIRED |
| GET /v1/rag/status, /api rag status | rag::rag_status (rag.rs:247) | none (static readiness) | NO | n/a | none | STATUS-OK |
| POST /api/evaluation/check | evaluation::check (evaluation.rs:72) | citation_exists sqlx (evaluation.rs:7); evaluator.record_check | NO | n/a | DB | WIRED (citation validator real) |
| POST /api/brain/test-route, /debug/route | brain::test_route (brain.rs:22) | aia.route_trace (aia_orchestrator.rs:109) | NO (debug) | n/a | in-mem | WIRED |
| GET /api/brain/health, /debug/agents | brain::health/debug_agents (brain.rs:6,11) | aia.agents/audit_records | NO | n/a | in-mem | WIRED |
| GET /api/brain/audit/recent | brain::audit_recent (brain.rs:41) | aia.audit_records (in-mem) | NO | n/a | in-mem | WIRED (note: in-memory audit) |
| GET /api/brain/trace/{id} | brain_traces::get_trace (brain_traces.rs:7) | sqlx WHERE request_id+user_id (brain_traces.rs:14) | YES (brain_traces.rs:12) | WHERE user_id=$2 (brain_traces.rs:21) | DB | WIRED |
| POST /api/agent/feedback | agent_feedback::submit_feedback (agent_feedback.rs:14) | trace ownership + INSERT (agent_feedback.rs:26,57) | YES (agent_feedback.rs:19) | trace_user_id check (agent_feedback.rs:45) | DB | WIRED |
| POST /api/agent/rollout/route-probe, validate-probe | agent::rollout_* (agent.rs:35,79) | AgenticOrchestrator + Redis / WASM validator | gated by env+header flag (agent.rs:103) | n/a (probe) | Redis/WASM | WIRED (probe, disabled by default) |
| POST /api/memory/write | memory::write (memory.rs:16) | aia.route gate + engine.write (memory.rs:29,41) | YES (memory.rs:23) | user_id match (memory.rs:24) | DB | WIRED |
| GET/DELETE /api/memory(read/list/delete) | memory.rs:45,64,83 | engine + sqlx (memory.rs:88) | YES (memory.rs:50,69,87) | user_id match / WHERE user_id (memory.rs:51,70,100) | DB | WIRED |
| GET /api/memory/workspace/{id} | memory::list_workspace (memory.rs:122) | workspace owner check + sqlx (memory.rs:129,140) | YES (memory.rs:127) | owner==auth (memory.rs:137) | DB | WIRED |
| POST /api/multimodal/analyze | multimodal::analyze (multimodal.rs:80) | aia.route gate + MultimodalService.analyze (multimodal.rs:114,132) | YES (multimodal.rs:87) | binds user_id (multimodal.rs:136) | DB+AI | WIRED |
| GET/DELETE /api/multimodal/assets/{id} | multimodal.rs:152,166 | service.get/delete_asset(user_id,..) (multimodal.rs:158,172) | YES (multimodal.rs:157,171) | user_id scoped | DB | WIRED |
| GET /api/connectors/status | connectors::status (connectors.rs:6) | registry.connectors() | YES (connectors.rs:11) | n/a | in-mem | WIRED |
| GET /api/model-providers/status | model_providers::status (model_providers.rs:27) | ensure_default_workspace + env (model_providers.rs:32) | YES (model_providers.rs:31) | workspace | DB | WIRED |
| GET /api/cache/stats, /status | cache::stats (cache.rs:5) | SemanticCacheService.stats (cache.rs:7) | NO | n/a | DB | WIRED (degrades closed) |
| GET /api/knowledge-graph/health | knowledge_graph::health (knowledge_graph.rs:12) | to_regclass sqlx (knowledge_graph.rs:13) | NO | n/a | DB | WIRED |
| POST /api/knowledge-graph/entity | knowledge_graph::entity (knowledge_graph.rs:43) | KnowledgeGraphService.lookup (knowledge_graph.rs:50) | NO | n/a | DB | WIRED |
| GET/POST /api/user-learning/* | user_learning.rs:16,81,119,126,158 | sqlx prefs/consent/events (user_learning.rs:22,88,132,172) | YES (user_learning.rs:20,86,130,163) | ensure_default_workspace + user_id (user_learning.rs:21) | DB | WIRED |
| GET/PUT /v1/iman-journey/{user_id}/** | iman_journey.rs:30–101 | ImanJourneyService sqlx (services/iman_journey.rs) | YES (iman_journey.rs:37,...) | ensure_user_scope (iman_journey.rs:103) | DB | WIRED |
| POST /v1/sync/{user_id}/backup, GET download | sync.rs:15,62 | sqlx user_backups (sync.rs:41,76) | YES (sync.rs:22,68) | requested==auth (sync.rs:23,69) | DB | WIRED |
| POST /waitlist, /v1/waitlist | waitlist::create_waitlist_entry | rate-limited sqlx insert (waitlist.rs) | NO (public) + rate limit | n/a | DB | WIRED |
| GET /modules, /modules/*/status (all nests) | modules::*_status (modules.rs:127–157) | env flags only | NO | n/a | none | STATUS-OK (honest flag report) |
| GET /v1/modules/{quran,prayer,knowledge,community}/overview | modules::*_overview (modules.rs:248–393) | enforce_module_gate: flag + auth + DB entitlement (modules.rs:186) | YES (modules.rs:200) | user_has_entitlement sqlx (modules.rs:159) | DB | STATUS-OK (gated, returns empty + “coming soon / under review”, no fabricated content) |
| auth: register/login/refresh/me/logout (root, /api/auth, /v1/auth) | phase2.rs:31,58,70,78,87 | Phase2Repository sqlx (services/phase2.rs); JWT auth.rs | login/register public; me/logout YES (phase2.rs:82,91) | n/a / token | DB | WIRED |
| PUT /v1/profiles/{user_id}, POST family | phase2::upsert_profile/create_family_profile (phase2.rs:138,157) | repo sqlx | YES (phase2.rs:146,165) | requested==auth (phase2.rs:147,166) | DB | WIRED |
| POST /v1/subscriptions/{user_id}/activate | phase2::activate_subscription (phase2.rs:179) | repo.activate_subscription | YES + grant secret (phase2.rs:185,205) | requested==auth (phase2.rs:206) | DB | WIRED |
| GET /v1/subscriptions/{user_id}/entitlements | phase2::list_entitlements (phase2.rs:216) | repo.list_user_entitlements | YES (phase2.rs:222) | requested==auth (phase2.rs:223) | DB | WIRED |
| POST /v1/chat/.../feedback, report | phase2::create_chat_feedback/report_answer (phase2.rs:232,245) | repo | YES (phase2.rs:239,252) | binds auth user_id | DB | WIRED |
| POST /v1/account/delete, export | phase2::request_account_deletion/data_export (phase2.rs:486,542) | sqlx audit+outbox (phase2.rs:500,518) | YES (phase2.rs:490,546) | actor=auth user | DB+outbox | WIRED |
| GET /v1/notifications, POST mark-read, device-token, enqueue | phase2.rs:373,384,393,408 | repo | YES (phase2.rs:379,388,398,414) | user-scoped | DB | WIRED |
| POST /support, GET/append /v1/support/{id} | phase2.rs:419,430,457 | repo + owner check (phase2.rs:442,465) | YES (phase2.rs:425,441,463) | owner==auth (phase2.rs:446) | DB | WIRED |
| GET /v1/rag/sources/approved | phase2::approved_rag_sources (phase2.rs:261) | repo.list_approved_rag_sources | NO | n/a (public approved) | DB | WIRED |
| POST /v1/safety/{classification,mastermind,scholar-review,wasm-event} | phase2.rs:286,294,302,310 | repo INSERT log tables | **NO AUTH** | none | DB | **PARTIAL (unauth writes)** |
| POST /v1/admin/{roles,actions,scholar-accounts,review-assignments,source-approval} ; GET source-approval-queue | phase2.rs:318,326,334,342,350,357 | repo raw INSERT/SELECT (services/phase2.rs:1208,1332,1390 …) | **NO AUTH, NO ADMIN ROLE CHECK** | none | DB | **FAKE/INSECURE — privilege escalation** |
| POST /v1/notifications/templates | phase2::create_notification_template (phase2.rs:365) | repo | **NO AUTH** | none | DB | **PARTIAL (unauth admin write)** |
| POST /v1/rag/{retrieval,citation} log | phase2.rs:270,278 | repo INSERT | **NO AUTH** | none | DB | PARTIAL (unauth telemetry write) |
| POST /v1/audit/logs, /v1/security/log | phase2::create_audit_log/security_log (phase2.rs:470,478) | repo INSERT | **NO AUTH** | none | DB | **PARTIAL — log forgery/injection** |
| POST /v1/events/{app,chat,rag,admin} | phase2.rs:607,615,623,631 | repo INSERT | **NO AUTH** | none | DB | PARTIAL (unauth event write) |
| POST /classify (/v1) | classify::classify_intent (classify.rs:6) | aia.classify→semantic_router+brain (aia_orchestrator.rs:59) | NO | n/a | in-mem | WIRED |
| GET /v1/dashboard/guardrails | dashboard::get_guardrails (dashboard.rs:4) | **none — hardcoded array** | NO | n/a | none | **FAKE** |
| GET /v1/server-pubkey | user::get_server_pubkey (user.rs:3) | env var, fails closed (user.rs:8) | NO | n/a | env | WIRED |
| GET /health, /ready, /metrics | health.rs:6 / ops.rs:3 | pool.acquire + waitlist count (ops.rs:5) | NO | n/a | DB | WIRED |
| GET /v1/islamic/qdrant-plan, ingestion-scaffolds | islamic.rs:100,104 | static config/env descriptor | NO | n/a | none | STATUS-OK (config descriptor, not posed as live data) |

---

## FAKE / static-JSON returns (posing as live data)

1. **`handlers/dashboard.rs:4-13` `get_guardrails`** — returns a HARDCODED single-element array with a fabricated `{"query":"example","trigger_reason":"SIMILARITY_THRESHOLD_FAILED"}` entry and a fresh `Utc::now()` timestamp. No DB read, no auth. Routed at `main.rs:1182-1184` (`/v1/dashboard/guardrails`). This is fake live-data: a client cannot distinguish it from a real guardrail event log. **BLOCKER** for any UI that renders it as real guardrail history.

Honest (NOT fake), explicitly cleared:
- `modules.rs` `*_overview` “coming soon / under review” + empty arrays — gated behind flag+JWT+DB entitlement, returns no fabricated religious content; `validate_required_provenance` rejects unsourced content. ACCEPTABLE fail-closed.
- `modules.rs` `*_status` — honest env-flag status report.
- `islamic.rs:104 ingestion_scaffolds` / `:100 qdrant_plan` — config/plan descriptors, not posed as runtime results.
- `rag.rs:247 rag_status` — static readiness flags (index_ready:false), honest.

---

## DEAD backend code (defined, never referenced)

1. **`services/graph_rag.rs` `GraphRagService` (struct :17, `new`, `traverse` :26)** — `rg "GraphRagService::new"` and `"\.traverse\("` return ZERO call sites. Only references are the definition + the `pub use` re-export at `services/mod.rs:47`. The real graph hop in the live path uses `KnowledgeGraphService` (hybrid_rag.rs:286), not `GraphRagService`. DEAD.
2. **`services/mod.rs:63` `pub use offline_islamic_corpus::fallback as offline_fallback`** — `rg "offline_fallback"` matches only the re-export line; never called. (Sibling `offline_lookup` IS used at islamic_knowledge.rs:331.) DEAD re-export.
3. **`services/islamic_knowledge.rs:457 qdrant_hit_to_citation`** — explicitly `#[allow(dead_code)]`, “legacy … retained for older tests.” Self-declared dead.

Proof commands: `rg -n "GraphRagService" sakina-backend/src` → only mod.rs:47 + graph_rag.rs def. `rg -n "offline_fallback" sakina-backend/src` → only mod.rs:63.

Note: `IngestionProducer`/`OutboxRelay` are NOT dead — `IngestionProducer::new` used in `src/bin/ingest.rs:17`; `OutboxRelay::new` used in `main.rs:517`.

---

## Ask-AI-Shaikh (`sakina_ask::ask`) hop-by-hop trace

| # | Hop | Evidence (file:line) | Real? |
|---|---|---|---|
| 0 | AuthN (JWT + session row + sub match) | sakina_ask.rs:348 → auth.rs:121 (validate_jwt:93, session lookup:134, mismatch guard:155) | YES |
| 1 | Workspace resolution | sakina_ask.rs:361 → `SELECT sakina_ai.ensure_default_workspace($1)` (sakina_ask.rs:131) | YES |
| 2 | PII redaction (before any model/DB pattern logic) | sakina_ask.rs:369 → services::pii_redaction::redact_pii | YES |
| 3 | Safety pre-gates: out_of_scope / crisis / high_risk_fatwa / fabricated-ritual short-circuit | sakina_ask.rs:422-470 (fail-closed, scholar_review enqueue:465) | YES |
| 4 | Brain/orchestrator route (Mother Brain) | sakina_ask.rs:472 → AiaOrchestrator::route (aia_orchestrator.rs:55) → BrainController::route (brain_controller.rs:50): cost governor:52, policy:53, can_generate gate:61 | YES |
| 5 | RAG + citation + policy (only if can_generate) | sakina_ask.rs:485 → aia.answer_islamic (aia_orchestrator.rs:113) → BrainController::answer_islamic (brain_controller.rs:247): re-route gate:259, permit:266 | YES |
| 5a | Hybrid retrieval (keyword sqlx + Qdrant vector + graph + compression) | islamic_knowledge.rs:320 → HybridRagService::search (hybrid_rag.rs:274): keyword_search sqlx:83 (only verified/approved:92-93), vector_search Qdrant:170/embeddings:175/qdrant.search:179, graph.lookup:286, compressor.compress:335, weak_evidence_blocked:376 | YES |
| 5b | Semantic cache (lookup/upsert) | islamic_knowledge.rs:302,416 | YES |
| 5c | Citation validator / fatwa policy gate (fail-closed) | islamic_knowledge.rs:357 `evaluate_fatwa_policy(AnswerInput{...})`; if decision != allow_publish → refuses, “will not invent a ruling” (islamic_knowledge.rs:363-371) | YES |
| 6 | Evaluation AI (post-draft, blocks on FAIL) | brain_controller.rs:268 evaluator.evaluate_value; :274 `if review_result != "PASS"` → `Err(unauthorized "response rejected by evaluation AI")` | YES |
| 7 | LLM gateway (only if answer still empty AND enabled; blocks if no allowed context) | sakina_ask.rs:535 `llm_gateway.enabled()` → generate_sakina_answer (llm_gateway.rs:71): disabled→empty/closed:75, no-context→blocked:87, real HTTP POST to gateway:103-126 | YES |
| 8 | Final fallback if still empty (insufficient_context) | sakina_ask.rs:573 | YES (fail-closed) |
| 9 | Anonymous learning (no raw msg) + dual persistence (brain_decision_traces + ask_shaikh_answers) | sakina_ask.rs:582 (anon), :604 persist_trace (INSERT:209,259) | YES |

**Verdict: PASS.** Every claimed hop (Brain/orchestrator → RAG/hybrid retrieval → citation/fatwa-policy validator → evaluation AI → LLM gateway) is backed by real code with fail-closed behavior. Notable strengths: LLM is hard-gated to refuse generation when no verified context exists (llm_gateway.rs:87) and the fatwa policy gate refuses to invent rulings (islamic_knowledge.rs:363). No fake-OK path found in this handler.

Minor honesty notes (not failures): the Brain `decision_trace` step `evidence_retrieved`/`context_compressed`/`answer_evaluated` are partly synthetic constants inside `decision_trace` (brain_controller.rs:188-210) and `evaluate_draft` returns fixed 0.91/0.12 scores (brain_controller.rs:412) — the *trace metadata* is illustrative, but the *actual* retrieval/evaluation gates that affect the answer (HybridRagService, evaluator.evaluate_value, fatwa policy) are real. In-memory `BrainAuditLog` (`audit_recent`) is process-local, not durable.

---

## Summary counts

- Endpoints inspected: ~70 (incl. nested/duplicated mount points).
- WIRED: majority (auth + real sqlx/Qdrant/LLM + fail-closed).
- STATUS-OK (honest fail-closed): modules status + overviews, rag_status, qdrant_plan, ingestion_scaffolds.
- **FAKE: 1** — `dashboard::get_guardrails` (hardcoded fabricated guardrail array).
- **PARTIAL/INSECURE: see below.**
- **DEAD: 3** — `GraphRagService`, `offline_fallback` re-export, `qdrant_hit_to_citation`.

### Top blockers (ranked)

1. **CRITICAL — Unauthenticated admin / privilege escalation.** `/v1/admin/roles`, `/admin/scholar-accounts`, `/admin/review-assignments`, `/admin/actions`, `/admin/source-approval/*`, `GET /admin/source-approval/queue` (phase2.rs:318-363) require NO JWT and NO admin-role check; repo does raw INSERT/SELECT (services/phase2.rs:1208,1332,1390). Anyone can self-grant admin roles, mint verified scholar accounts, and read/modify the source-approval queue. Confirmed no auth middleware: `main.rs:597-599` wraps only CORS, Logger, and logging-only `AuditMiddleware` (middleware/audit.rs:1-79).
2. **HIGH — Unauthenticated audit/security log writes.** `POST /v1/audit/logs`, `POST /v1/security/log` (phase2.rs:470,478) accept anonymous writes → log forgery / injection / audit-trail poisoning.
3. **HIGH — Unauthenticated safety/event/telemetry writes.** `/v1/safety/*` (phase2.rs:286-315), `/v1/events/*` (phase2.rs:607-634), `/v1/rag/log-*` (phase2.rs:270,278), `/v1/notifications/templates` (phase2.rs:365) all write to DB with no auth.
4. **MEDIUM — Forgeable entitlement on RAG content.** `rag::rag_sources` / `rag::rag_search` gate premium access on the client-supplied `x-sakina-subscription-tier` header (rag.rs:185-196) instead of JWT+DB entitlement. Trivially bypassed by sending `x-sakina-subscription-tier: premium`. Contrast with `modules.rs:159-207` which does it correctly via `user_has_entitlement` sqlx. (`rag_sources` also returns only approved public sources, limiting blast radius, but the paywall is fake.)
5. **MEDIUM — FAKE data:** `dashboard::get_guardrails` hardcoded array (dashboard.rs:4).
6. **LOW — Dead code:** `GraphRagService` (graph_rag.rs:17), `offline_fallback` re-export (mod.rs:63), `qdrant_hit_to_citation` (islamic_knowledge.rs:457).

### UNPROVEN (cannot confirm statically)
- Whether an upstream gateway/ingress enforces admin auth in front of `/v1/admin/*` — NOT visible in this repo; from the Rust app’s perspective these routes are open. Marked INSECURE pending proof of an external gate.
- Runtime behavior of Qdrant/vLLM/LLM-gateway calls (no live services); wiring is structurally real.
