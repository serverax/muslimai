# AGENT-brain-aia — Advanced Technology Wiring Audit (Hostile QA)

Scope: Is each "advanced technology" actually WIRED into the live `sakina_ask` Ask path
(`handlers/sakina_ask.rs` → `services/aia_orchestrator.rs` → `services/brain_controller.rs` → ...)
and does its output change the response/decision/trace? Evidence is file:line. No cargo run.

Live route registration: `main.rs:692` and `main.rs:940` →
`/api/sakina/ask` → `handlers::sakina_ask::ask`.

Handler dependencies actually injected (`sakina_ask.rs:340-347`): `AiaOrchestrator`,
`IslamicAnswerService`, `SakinaLlmGateway`, `PgPool`. That is the entire DI surface of the
live Ask path — note what is **absent**: MemoryEngine, McpConnectorRegistry, SemanticRouter
(as a direct dep), GraphRagService.

---

## Summary Table

| Technology | Constructed (file:line) | Called in live Ask path? (file:line) | Affects output? | Status |
|---|---|---|---|---|
| Brain / Mother Algorithm (`BrainController`) | `aia_orchestrator.rs:31` / `:45` (via `AiaOrchestrator::new*`); orchestrator built `main.rs:499` | YES — `sakina_ask.rs:472` `aia.route(...)` → `aia_orchestrator.rs:56` → `brain_controller.rs:50 route()`; and `sakina_ask.rs:485` `aia.answer_islamic` → `brain_controller.rs:247` | YES — `route.can_generate` gates generation at `sakina_ask.rs:484`; `answer_islamic` can hard-block (`brain_controller.rs:260-264`) | **WIRED** |
| AI Router / model routing (`AiRouter`) | `aia_orchestrator.rs:24` / `:38` | YES — `brain_controller.rs:51` `self.router.route(request)` produces the base route on every Ask | YES — base route (agent/model/risk/can_generate) flows into the gate at `sakina_ask.rs:484` and into persisted trace | **WIRED** |
| Evaluation AI (`BrainResponseEvaluator`) | `aia_orchestrator.rs:40` (`with_pool`, since `new_with_pool` is used by `main.rs:499`) | YES — `brain_controller.rs:268` `self.evaluator.evaluate_value(&answer, &route)` inside `answer_islamic` | YES — non-PASS returns `Err` and the RAG answer is rejected before delivery (`brain_controller.rs:274-290`); evaluator can FAIL (`brain_evaluator.rs:55-61`) | **WIRED** |
| Hybrid Search / Hybrid RAG (`HybridRagService`) | `main.rs:539` | YES — `sakina_ask.rs:485` `aia.answer_islamic` → `brain_controller.rs:267` `service.answer` → `islamic_knowledge.rs:320` `self.hybrid_rag.search` | YES — keyword+vector+graph fused scoring (`hybrid_rag.rs:163-168`), citations/answer/graph_path returned to handler (`sakina_ask.rs:498-529`) | **WIRED** |
| Knowledge Graph (`KnowledgeGraphService`) | `main.rs:504`, injected into HybridRag `main.rs:543` | YES — `hybrid_rag.rs:286` `self.graph.lookup(query)` | YES — sets `graph_score=0.4` affecting `final_score` (`hybrid_rag.rs:296-298`); graph citations + `graph_path` returned (`hybrid_rag.rs:347-358,389`) | **WIRED** |
| GraphRAG (`GraphRagService`) | NEVER constructed (only `graph_rag.rs:17,21` def + `mod.rs:47` re-export) | NO — zero call sites outside its own file | NO | **DEAD** |
| Semantic Cache (`SemanticCacheService`) | `main.rs:505`, injected `main.rs:549` | YES — `islamic_knowledge.rs:302` `self.cache.lookup` (hit short-circuits) + `:416` `self.cache.upsert` | YES — cache hit returns early with cached payload (`islamic_knowledge.rs:308-317`); miss writes cache | **WIRED** |
| Context Compression (`ContextCompressionService`) | `main.rs:506`, injected into HybridRag `main.rs:544` | YES — `hybrid_rag.rs:335` `self.compressor.compress(&compressed_inputs, top_k)` | PARTIAL — produces `compressed_tokens_before/after`, `compression_ratio` returned in payload (`hybrid_rag.rs:390-392`, surfaced `islamic_knowledge.rs:394-396`). Reported as metrics; does not gate/alter the answer text. See note. | **WIRED (metrics-only)** |
| Semantic Router (`SemanticRouter`) | `main.rs:498`, passed into orchestrator | NO (not on Ask path) — `.classify` only called via `aia_orchestrator.rs:67-71`, reachable from `/classify` (`classify.rs:10`), NOT from `aia.route`/`aia.answer_islamic` used by Ask | NO (for Ask) | **DECORATIVE on Ask path** (live only on `/classify`) |
| AIA / Agentic workflow (`AiaOrchestrator`) | `main.rs:499` | YES — it is the entry wrapper the handler calls (`sakina_ask.rs:472,485`) | YES — but it is a thin pass-through to `BrainController` (`aia_orchestrator.rs:56,118`); no independent multi-agent loop on Ask | **WIRED (thin wrapper)** |
| Memory Engine (`MemoryEngine`) | `main.rs:551` | NO — not injected into `ask()` (`sakina_ask.rs:340-347`); live only on `/api/memory/*` (`main.rs:767-776`) and `chat.rs:341` | NO (for Ask) | **DECORATIVE on Ask path** (live on memory/chat routes) |
| MCP connectors (`McpConnectorRegistry`) | `main.rs:553` (`from_env`) | NO — not injected into `ask()`; live only on `/api/connectors/status` (`main.rs:720-721`, `connectors.rs:9`) | NO (for Ask) | **DECORATIVE on Ask path** (live on connectors route) |
| WASM Fatwa Policy Gate (`sakina-fatwa-policy-gate`) | crate dep `Cargo.toml:33`; imported `islamic_knowledge.rs:11` | YES — `islamic_knowledge.rs:357` `evaluate_fatwa_policy(&AnswerInput{...})` inside `IslamicAnswerService::answer` | YES — if `decision != "allow_publish"` the answer text is overwritten with a scholar-review refusal (`islamic_knowledge.rs:363-371`) | **WIRED** (compiled-in crate, not WASM-runtime) |

---

## 9 Required Per-Tech Sections

### 1. Brain / Mother Algorithm
WIRED. The handler's main `else` branch calls `aia.route(&BrainRouteRequest{...})`
(`sakina_ask.rs:472`). `AiaOrchestrator::route` delegates to `BrainController::route`
(`aia_orchestrator.rs:56`). `BrainController::route` computes base route + cost governor +
safety policy and returns `can_generate` (`brain_controller.rs:56-61`). The handler gates RAG
generation on `route.can_generate` (`sakina_ask.rs:484`). Independently, the persisted trace
hard-codes `selected_agent='Mother Algorithm'` / `source_strategy='sakina_mother_algorithm'`
(`sakina_ask.rs:214-215`) — that string is decorative, but the *gating* is real.
Caveat: SemanticRouter is NOT part of this path; the "Mother Algorithm" routing on Ask is
`AiRouter` + policy, not the semantic router.

### 2. AIA / Agentic workflow
WIRED but thin. `AiaOrchestrator` is the injected entry object (`sakina_ask.rs:342`,
`main.rs:499`). Its Ask-relevant methods are pass-throughs: `route` → `brain_controller.route`
(`aia_orchestrator.rs:56`); `answer_islamic` → `brain_controller.answer_islamic`
(`aia_orchestrator.rs:118`). There is no agent loop / tool-calling / planning step on the Ask
path — "agentic" here means a single routed call. Honest status: real wrapper, not a real
multi-step agentic workflow.

### 3. Memory Engine
DECORATIVE on the Ask path. Constructed `main.rs:551`, injected as app_data, but the `ask`
handler does not take it as a parameter (`sakina_ask.rs:340-347`) and never references it.
The Ask handler instead writes `anonymous_learning_events` directly via raw SQL
(`sakina_ask.rs:291-323`) and the brain trace emits a hard-coded
`memory_action = "no_sensitive_memory_write"` step (`brain_controller.rs:216-217`) that is a
literal string, not a MemoryEngine call. MemoryEngine IS genuinely live on `/api/memory/*`
(`main.rs:767`) and in `chat.rs:341`, so it is not globally dead — just absent from Ask.

### 4. Semantic Cache
WIRED. Inside the RAG path `IslamicAnswerService::answer`: `self.cache.lookup` at
`islamic_knowledge.rs:302` returns early on a hit with cached payload
(`islamic_knowledge.rs:308-317`); on a miss `self.cache.upsert` persists the result
(`islamic_knowledge.rs:416`). Cache key incorporates language/intent/safety/source_version/user
(`islamic_knowledge.rs:295-301`). Output is materially changed on a hit.

### 5. Context Compression
WIRED (metrics-only). `self.compressor.compress(&compressed_inputs, top_k)` runs on every RAG
search (`hybrid_rag.rs:335`). Its outputs (`compressed_tokens_before/after`, `compression_ratio`)
are placed into `HybridRagResult` (`hybrid_rag.rs:390-392`) and surfaced in the answer payload
(`islamic_knowledge.rs:394-396`), and the Ask response carries the rag_context
(`sakina_ask.rs:501`). It affects the *response object* (observable metrics) but does not trim
the text actually sent to the LLM gateway nor gate the answer. Distinct from the
`brain_controller.rs:196 "context_compressed"="compressed"` trace step, which is a hard-coded
decorative string with no compressor call.

### 6. AI Router / model routing
WIRED. `AiRouter` is owned by `BrainController` and called on every route:
`brain_controller.rs:51 self.router.route(request)` (`AiRouter::route` at `ai_router.rs:171`).
The resulting agent/model/risk/can_generate fields drive the gate and the persisted trace. Live.

### 7. Evaluation AI
WIRED. `BrainResponseEvaluator::evaluate_value` is invoked on the produced RAG answer
(`brain_controller.rs:268`). A non-PASS verdict causes `answer_islamic` to return `Err`
(`brain_controller.rs:274-290`), which the handler propagates as an error response
(`sakina_ask.rs:531`) — i.e., the evaluator can suppress a RAG answer before delivery. The
evaluator has real FAIL branches (`brain_evaluator.rs:55-61`, escalation/grounding/language).
Uses the pooled variant (`with_pool`, `aia_orchestrator.rs:40`) for `record_answer_evaluation`.

### 8. Knowledge Graph vs GraphRAG
KnowledgeGraphService is LIVE: `hybrid_rag.rs:286 self.graph.lookup(query)`, contributing
`graph_score` to fused ranking (`hybrid_rag.rs:296`) and emitting `graph_path`/graph citations
(`hybrid_rag.rs:347-358,389`) that reach the Ask response (`sakina_ask.rs:502-529`).
GraphRagService is DEAD: it is only defined (`graph_rag.rs:17,21`) and re-exported
(`mod.rs:47`); `rg` shows zero construction or call sites. The two are not interchangeable in
practice — only the KnowledgeGraph variant runs.

### 9. MCP connectors
DECORATIVE on the Ask path. `McpConnectorRegistry::from_env()` is constructed (`main.rs:553`)
and injected, but the Ask handler does not depend on it (`sakina_ask.rs:340-347`). Its only
live route is read-only status at `/api/connectors/status` (`main.rs:720-721`,
`connectors.rs:9`). No connector is invoked while answering a user question.

### (Bonus) WASM Fatwa Policy Gate
WIRED. `sakina-fatwa-policy-gate` is a real path crate (`Cargo.toml:33`) imported at
`islamic_knowledge.rs:11` and called at `islamic_knowledge.rs:357`. When the policy returns a
decision other than `allow_publish`, the answer text is replaced with a scholar-review refusal
(`islamic_knowledge.rs:363-371`), directly changing user-visible output. Caveat: it is linked
in as a native Rust crate (compiled into the binary), not executed via a WASM runtime/sandbox
at request time — so "WASM policy gate" is wired in substance but not actually run as WASM.

---

## Hard-coded decorative trace steps (anti-pattern flags)
These appear in `brain_controller.rs::decision_trace` and are emitted as if technologies ran,
but no corresponding service is invoked from `BrainController`:
- `context_compressed = "compressed"` (`brain_controller.rs:196-197`) — no compressor call here
  (real compression happens separately in HybridRag).
- `memory_action = "no_sensitive_memory_write"` (`brain_controller.rs:216-217`) — literal string,
  no MemoryEngine call.
- `evidence_retrieved` outcome is derived only from `route.rag_required` flag
  (`brain_controller.rs:188-194`), not from actual retrieval at trace time.
- Handler trace hard-codes `selected_agent='Mother Algorithm'` (`sakina_ask.rs:214`).

---

## Verdicts

Per-tech (Ask path):
- WIRED (affects output): Mother Algorithm/BrainController, AiRouter, Evaluation AI, Hybrid RAG,
  KnowledgeGraphService, Semantic Cache, WASM Fatwa Policy Gate.
- WIRED (metrics-only, no gating): Context Compression.
- WIRED (thin pass-through wrapper, no real agent loop): AiaOrchestrator.
- DECORATIVE on Ask path (live elsewhere): Semantic Router (`/classify`), Memory Engine
  (`/api/memory`, chat), MCP connectors (`/api/connectors/status`).
- DEAD (never constructed/called anywhere): GraphRagService.

Overall: The Ask path is substantially real — routing, hybrid retrieval, knowledge-graph
fusion, semantic cache, fatwa policy gate, and evaluation all execute and can change/suppress the
answer, satisfying the "no isolated technology" rule for those. The violations of that rule are:
(1) GraphRagService is dead code shadowing the live KnowledgeGraphService; (2) MemoryEngine,
MCP, and SemanticRouter are constructed/injected but never touch the Ask flow (isolated relative
to Ask); (3) brain_controller emits decorative `context_compressed`/`memory_action` trace steps
that imply work not performed in that component; (4) the "WASM" policy gate and "agentic"
orchestrator are real but mislabeled (native crate; single-call wrapper).
