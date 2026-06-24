# Sakina True Workflow Machine Architecture

This file is an enforcement artifact for the Sakina restricted advanced technologies order. It is not a sign-off. The product is the integrated workflow. A named technology is accepted only when it runs inside this workflow and affects the real app result.

Acceptance vocabulary:

- COMPLETE = technology runs inside the real workflow and affects the real app result with positive, negative, trace/audit/metrics, CI, Docker, Kubernetes, and release APK/AAB proof.
- NOT COMPLETE = technology exists only as a file, script, route, table, report, or isolated test.

Current architecture verdict: NOT COMPLETE. Several runtime chains exist locally, but the full workflow is not accepted because required advanced proof scripts, iOS release path, live image/vision provider proof, Kubernetes proof, CI/CD proof, and full product gates are still failing or missing.

## 1. Full Sakina Workflow

1. User opens Sakina mobile app
   -> Flutter checks secure token
   -> frontend loads user profile, language, feature flags, entitlements

2. User asks a question or uploads text/image/audio/document
   -> frontend screen captures input
   -> frontend service sends real HTTP request
   -> request includes JWT and trace/request ID

3. Backend receives request
   -> validates JWT
   -> validates session/refresh status
   -> enforces user ownership
   -> applies RLS
   -> validates input/file/type/size
   -> rejects unsafe or unauthorised request

4. Brain Mother Algorithm starts
   -> creates trace ID
   -> loads user context safely
   -> checks language: Arabic / English
   -> classifies Islamic intent
   -> classifies sensitivity/risk
   -> checks feature flag and entitlement
   -> checks if human review may be needed

5. Prompt injection and safety pre-check
   -> blocks jailbreak attempts
   -> blocks malicious retrieved-source instructions
   -> blocks tool abuse
   -> records safety decision in trace

6. AIA / Agentic workflow starts
   -> intent agent classifies the question
   -> language agent handles Arabic/English
   -> memory agent decides safe memory use
   -> retrieval agent decides needed sources
   -> Graph RAG agent finds related concepts
   -> citation agent verifies support
   -> hallucination agent checks unsupported claims
   -> Islamic safety agent validates final answer
   -> every agent has schema, allowlist, denylist, timeout, retry, audit, trace

7. Memory engine runs
   -> checks consent
   -> loads only this user's memory
   -> blocks cross-user memory
   -> blocks sensitive memory without consent
   -> writes/deletes memory only through Brain permission

8. Retrieval planner runs
   -> decides whether RAG is needed
   -> decides whether Graph RAG is needed
   -> decides whether hybrid search is needed
   -> decides whether the answer can be general/caveated

9. Hybrid Search runs
   -> vector search in Qdrant
   -> lexical/full-text search in DB
   -> merge and rank results
   -> remove duplicates
   -> apply Arabic/English weighting
   -> apply source trust weighting
   -> store ranking decision in trace

10. Graph RAG runs
   -> extracts Islamic concepts
   -> traverses knowledge graph
   -> finds related topics/sources/cautions
   -> sends graph context back to Brain
   -> graph result affects retrieval or final answer

11. Islamic Source Trust Ranking runs
   -> Quran references highest
   -> verified hadith/guidance ranked by trust
   -> weak/unverified/user-provided content downgraded or blocked
   -> conflicting sources flagged
   -> trust decision appears in trace

12. Context compression runs
   -> compresses retrieved context
   -> preserves source IDs
   -> preserves safety flags
   -> preserves user intent
   -> preserves Arabic/English meaning
   -> fails safely if compression loses required evidence

13. Semantic cache runs
   -> checks if similar safe answer exists
   -> enforces user isolation
   -> checks source version hash
   -> checks TTL
   -> reruns safety/citation checks before returning cached answer
   -> records cache hit/miss metrics

14. Cost governor runs
   -> estimates provider/model cost
   -> checks quota/budget
   -> blocks abuse
   -> downgrades to cheaper route where safe
   -> records cost decision

15. AI Router runs
   -> selects provider/model based on Arabic/English, Islamic risk, citations, complexity, latency, cost, and provider availability
   -> disabled provider must not be selected
   -> failed provider must fallback or fail closed

16. WASM deterministic module runs where required
   -> source trust scoring
   -> safety risk scoring
   -> citation support scoring
   -> retrieval reranking
   -> bad input fails safely
   -> output affects Brain decision
   -> trace shows WASM stage

17. LLM/provider generates draft answer where required
   -> provider receives only required context
   -> PII minimised
   -> no direct handler-to-LLM call allowed
   -> all provider calls go through Brain and AI Router

18. Citation validator runs
   -> checks cited source IDs exist
   -> checks claims are supported
   -> rejects fabricated citations
   -> blocks or caveats unsupported claims

19. Hallucination validator runs
   -> detects unsupported Islamic claims
   -> detects overconfident fatwa-like language
   -> detects missing evidence
   -> blocks or rewrites unsafe answer

20. Islamic policy-as-code safety guard runs
   -> applies versioned safety rules
   -> handles sensitive religious questions
   -> handles sectarian/rage-bait questions
   -> handles crisis/self-harm religious questions
   -> handles medical/legal/financial crossover questions
   -> advises qualified scholar where needed
   -> records policy decision in trace

21. Human review queue runs if high risk
   -> creates review item or safe escalation state
   -> minimises PII
   -> frontend receives caveated response
   -> direct bypass is blocked

22. Final response created
   -> answer
   -> citations
   -> caveats
   -> confidence/source support
   -> next steps
   -> trace ID
   -> safety state

23. Persistence layer updates
   -> DB writes answer/session/trace/audit
   -> Qdrant used where needed
   -> Redis/Valkey cache updated where safe
   -> outbox event created where async work is needed
   -> metrics updated
   -> no secrets/PII leaked

24. Frontend receives real response
   -> parses backend response model
   -> displays answer
   -> displays citations/source basis
   -> displays caveats/warnings
   -> displays review/escalation status if needed
   -> does not show fake/static/demo result

25. Observability proves the full machine
   -> same trace ID appears in frontend request, backend logs, Brain trace, DB row, Qdrant/vector span, cache span, provider span, audit log, and response
   -> OpenTelemetry metrics show real counters
   -> errors are traced safely

26. Security gates prove the workflow
   -> JWT required
   -> invalid JWT rejected
   -> revoked token rejected
   -> cross-user access rejected
   -> RLS enforced
   -> CORS restricted
   -> rate limit enforced
   -> PII redacted
   -> secrets masked
   -> OWASP API tests pass
   -> MASVS mobile checks pass

27. Delivery gates prove release readiness
   -> Docker build passes
   -> Kubernetes deployment works
   -> restricted pod policy passes
   -> CI/CD runs remotely
   -> SAST/SCA/secret/container scans pass
   -> release APK builds
   -> release AAB builds
   -> no localhost in release
   -> permissions match enabled features

## 2. Runtime Machine Map

### Brain Mother Algorithm

Where it sits in the workflow: Steps 4, 8, 12-22 as the central controller.  
What runtime decision it makes: whether the request can proceed, which route/agent/retrieval/provider/safety path is used, and whether a final answer can be returned.  
What code implements it: `sakina-backend/src/services/brain_controller.rs`, `sakina-backend/src/services/brain_policy.rs`, `sakina-backend/src/services/brain_evaluator.rs`, `sakina-backend/src/services/aia_orchestrator.rs`.  
What backend route invokes it: chat handlers, `/api/brain/trace`, `/api/rag/query`, `/api/memory/*`, `/api/multimodal/analyze`.  
What Brain stage invokes it: request intake through final response.  
What DB/Qdrant/cache/WASM/outbox object it uses: `sakina_ai.brain_decision_traces`, semantic cache metadata, audit events.  
What frontend feature uses it: chat, Islamic library ask flow, memory, multimodal upload.  
Positive runtime proof: `scripts/sakina/tech-brain-orchestrator-proof.sh`.  
Negative runtime proof: `scripts/sakina/final-brain-workflow-gate.sh` requires bypass and safety proofs, but currently fails because dependent proof scripts are missing.  
What trace/audit/metrics prove it ran: brain trace rows and `/health/observability`.  
CI/Docker/Kubernetes/release proof: not currently accepted.  
Missing pieces: full product gate, Kubernetes evidence, remote CI evidence, release artifact evidence.

### AIA / Agentic Workflow

Where it sits in the workflow: Step 6 between Brain and retrieval/validation tools.  
What runtime decision it makes: controlled agent selection and stage execution.  
What code implements it: `sakina-backend/src/services/aia_orchestrator.rs`, Brain services.  
What backend route invokes it: chat, RAG, memory, multimodal, brain trace routes.  
What Brain stage invokes it: intent, language, memory, retrieval, graph, citation, hallucination, safety.  
What DB/Qdrant/cache/WASM/outbox object it uses: brain traces and audit events; retrieval agents use DB/Qdrant.  
What frontend feature uses it: chat, Islamic ask, multimodal.  
Positive runtime proof: `scripts/sakina/tech-agentic-workflow-proof.sh`.  
Negative runtime proof: `scripts/sakina/final-brain-workflow-gate.sh` requires it but fails on missing advanced subproofs.  
What trace/audit/metrics prove it ran: brain execution trace fields.  
CI/Docker/Kubernetes/release proof: not currently accepted.  
Missing pieces: full workflow and deployment proof.

### RAG for Islamic Sources

Where it sits in the workflow: Steps 8-12, 18-20.  
What runtime decision it makes: which verified Islamic sources support the answer.  
What code implements it: `sakina-backend/src/services/hybrid_rag.rs`, `sakina-backend/src/services/qdrant_client.rs`, `sakina-backend/src/handlers/rag.rs`, Islamic knowledge services.  
What backend route invokes it: `/api/rag/query`, chat/ask flows, multimodal document analysis through Brain.  
What Brain stage invokes it: retrieval planner, source trust, context compression, validation.  
What DB/Qdrant/cache/WASM/outbox object it uses: Islamic source/document/chunk tables, Qdrant collections, semantic cache.  
What frontend feature uses it: Islamic library ask, chat, multimodal document analysis.  
Positive runtime proof: `scripts/sakina/tech-rag-proof.sh`, `scripts/sakina/multimodal-brain-rag-proof.sh`.  
Negative runtime proof: RAG unavailable/provider missing paths are required by advanced gates.  
What trace/audit/metrics prove it ran: citations in response, brain trace retrieval fields, Qdrant query evidence.  
CI/Docker/Kubernetes/release proof: not currently accepted.  
Missing pieces: live provider and deployment evidence remain blockers.

### Graph RAG / Islamic Knowledge Graph

Where it sits in the workflow: Step 10 and part of Steps 8-12.  
What runtime decision it makes: related Islamic concept expansion and source/caution relationships.  
What code implements it: `sakina-backend/src/services/graph_rag.rs`, `sakina-backend/src/services/knowledge_graph_service.rs`, `sakina-backend/src/services/hybrid_rag.rs`.  
What backend route invokes it: RAG/chat routes through hybrid retrieval.  
What Brain stage invokes it: Graph RAG relationship agent and retrieval planner.  
What DB/Qdrant/cache/WASM/outbox object it uses: `sakina_ai.knowledge_graph_entities`, `sakina_ai.knowledge_graph_edges`.  
What frontend feature uses it: citation/related source rendering where returned.  
Positive runtime proof: `scripts/sakina/tech-graph-rag-proof.sh`.  
Negative runtime proof: final advanced gate requires graph proof but full product gate still fails.  
What trace/audit/metrics prove it ran: graph trace fields and graph citations.  
CI/Docker/Kubernetes/release proof: not currently accepted.  
Missing pieces: full chain deployment and release proof.

### Hybrid Search and Qdrant

Where it sits in the workflow: Step 9.  
What runtime decision it makes: vector plus lexical merge/rank/dedup and source weighting.  
What code implements it: `sakina-backend/src/services/hybrid_rag.rs`, `sakina-backend/src/services/qdrant_client.rs`, embeddings services.  
What backend route invokes it: `/api/rag/query` and Brain-controlled ask/multimodal flows.  
What Brain stage invokes it: retrieval planner.  
What DB/Qdrant/cache/WASM/outbox object it uses: Qdrant Islamic chunks collection and Islamic chunk tables.  
What frontend feature uses it: Islamic ask, chat, multimodal document result.  
Positive runtime proof: `scripts/sakina/tech-hybrid-search-proof.sh`, `scripts/sakina/tech-rag-proof.sh`.  
Negative runtime proof: Qdrant unavailable must fail in real mode; full gate still needs proof.  
What trace/audit/metrics prove it ran: retrieval trace, citations, Qdrant evidence files.  
CI/Docker/Kubernetes/release proof: not currently accepted.  
Missing pieces: current script listing did not include all referenced Qdrant/vector proof scripts; deployment proof remains missing.

### Islamic Source Trust Ranking

Where it sits in the workflow: Step 11.  
What runtime decision it makes: source authority weighting and conflict flagging.  
What code implements it: partially represented in hybrid RAG source metadata and validation services.  
What backend route invokes it: RAG/chat/multimodal via Brain retrieval.  
What Brain stage invokes it: source trust ranking stage.  
What DB/Qdrant/cache/WASM/outbox object it uses: source metadata in DB/Qdrant payloads.  
What frontend feature uses it: citation/source basis display.  
Positive runtime proof: expected `scripts/sakina/tech-source-trust-ranking-proof.sh`.  
Negative runtime proof: missing.  
What trace/audit/metrics prove it ran: source ranking trace required.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: required source trust proof script is missing; cannot be accepted.

### Context Compression

Where it sits in the workflow: Step 12.  
What runtime decision it makes: reduces evidence while preserving citations, safety flags, intent, and language meaning.  
What code implements it: `sakina-backend/src/services/context_compression.rs`.  
What backend route invokes it: Brain/RAG answer paths.  
What Brain stage invokes it: context compression stage.  
What DB/Qdrant/cache/WASM/outbox object it uses: retrieved context and trace fields.  
What frontend feature uses it: final answer/citation display indirectly.  
Positive runtime proof: `scripts/sakina/tech-context-compression-proof.sh`.  
Negative runtime proof: evidence-loss fail-safe required by advanced gate.  
What trace/audit/metrics prove it ran: brain trace compression fields.  
CI/Docker/Kubernetes/release proof: not accepted.  
Missing pieces: full workflow and deployment proof.

### Semantic Cache and Redis / Valkey

Where it sits in the workflow: Step 13 and runtime cache support.  
What runtime decision it makes: safe cache hit/miss, source-version/TTL/user isolation, performance cache use.  
What code implements it: `sakina-backend/src/services/semantic_cache.rs`; Redis/Valkey proof is not established.  
What backend route invokes it: Brain/RAG answer paths and `/api/cache/stats`.  
What Brain stage invokes it: semantic cache check/update.  
What DB/Qdrant/cache/WASM/outbox object it uses: `sakina_ai.brain_cache_metadata`; Redis/Valkey object not proven.  
What frontend feature uses it: chat/ask indirectly through faster backend response.  
Positive runtime proof: `scripts/sakina/tech-semantic-cache-proof.sh`.  
Negative runtime proof: cross-user/no-leak proof required.  
What trace/audit/metrics prove it ran: cache hit/miss stats.  
CI/Docker/Kubernetes/release proof: Redis/Valkey proof missing.  
Missing pieces: `scripts/sakina/tech-redis-valkey-cache-proof.sh` is missing.

### AI Router and Cost Governor

Where it sits in the workflow: Steps 14-17.  
What runtime decision it makes: provider/model selection, quota/cost control, failover/fail-closed behavior.  
What code implements it: `sakina-backend/src/services/ai_router.rs`, `sakina-backend/src/services/llm.rs`, `sakina-backend/src/services/aia_orchestrator.rs`; cost governor proof script is missing.  
What backend route invokes it: Brain-controlled chat/RAG/multimodal paths.  
What Brain stage invokes it: cost governor and AI router.  
What DB/Qdrant/cache/WASM/outbox object it uses: provider/model fields in brain traces; cache can reduce calls.  
What frontend feature uses it: all AI answer flows indirectly.  
Positive runtime proof: `scripts/sakina/tech-ai-router-proof.sh`; expected cost proof `scripts/sakina/tech-cost-governor-proof.sh`.  
Negative runtime proof: provider unavailable must not return fake answer.  
What trace/audit/metrics prove it ran: provider/model/latency/confidence fields.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: live LLM provider and cost governor proof are not fully accepted.

### WASM Deterministic Module

Where it sits in the workflow: Step 16.  
What runtime decision it makes: deterministic scoring/ranking/safety helper output that affects Brain decisions.  
What code implements it: WASM integration must be proven; backend route `/wasm-events` logs events.  
What backend route invokes it: expected Brain/RAG/calculation path plus `/wasm-events` audit route.  
What Brain stage invokes it: WASM scoring stage.  
What DB/Qdrant/cache/WASM/outbox object it uses: WASM artifact and event/audit rows.  
What frontend feature uses it: prayer/qibla/safety/ranking if exposed.  
Positive runtime proof: expected `scripts/sakina/tech-wasm-proof.sh`.  
Negative runtime proof: bad input fail-safe required.  
What trace/audit/metrics prove it ran: WASM event rows and Brain trace stage.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: current script inspection did not find `scripts/sakina/tech-wasm-proof.sh`; not accepted.

### Citation Validator and Hallucination Validator

Where it sits in the workflow: Steps 18-19.  
What runtime decision it makes: whether cited sources exist and claims are supported; whether unsupported or overconfident Islamic claims are blocked/caveated.  
What code implements it: evaluation/citation services and handlers, `sakina-backend/src/handlers/evaluation.rs`, Brain evaluator services.  
What backend route invokes it: Brain/RAG/chat/multimodal answer paths.  
What Brain stage invokes it: citation verifier and hallucination reviewer.  
What DB/Qdrant/cache/WASM/outbox object it uses: retrieved source IDs, evaluation trace rows, audit events.  
What frontend feature uses it: caveat/refusal/citation rendering.  
Positive runtime proof: expected `scripts/sakina/tech-citation-hallucination-validator-proof.sh`.  
Negative runtime proof: fake citation trap and unsupported claim blocker.  
What trace/audit/metrics prove it ran: evaluation and safety trace.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: required proof script is missing from current script listing.

### Policy-as-Code / Islamic Safety Guard / Prompt Injection Guard

Where it sits in the workflow: Steps 5 and 20.  
What runtime decision it makes: jailbreak/tool abuse blocking, sensitive religious safety, caveat/refusal/escalation.  
What code implements it: `sakina-backend/src/services/guardrails.rs`, `sakina-backend/src/services/brain_policy.rs`, evaluation services.  
What backend route invokes it: all Brain-controlled answer paths.  
What Brain stage invokes it: safety pre-check, Islamic policy guard, high-risk review.  
What DB/Qdrant/cache/WASM/outbox object it uses: safety/audit trace rows and retrieved source context.  
What frontend feature uses it: answer/caveat/refusal rendering.  
Positive runtime proof: expected `scripts/sakina/tech-policy-as-code-proof.sh`; Islamic regression script.  
Negative runtime proof: expected `scripts/sakina/tech-prompt-injection-proof.sh` and `scripts/sakina/islamic-safety-regression.sh`.  
What trace/audit/metrics prove it ran: safety decisions in trace and audit events.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: prompt-injection-specific proof script is missing; full deployment proof missing.

### Memory Engine and PII Redaction

Where it sits in the workflow: Steps 7 and privacy handling across 17, 23, 25.  
What runtime decision it makes: consent-gated user-owned memory read/write/delete and privacy minimization.  
What code implements it: `sakina-backend/src/services/memory_engine.rs`, `sakina-backend/src/handlers/memory.rs`, redaction in multimodal service.  
What backend route invokes it: `/api/memory/write`, `/api/memory/read`, `/api/memory/delete`, multimodal provider path.  
What Brain stage invokes it: memory permission and PII minimization.  
What DB/Qdrant/cache/WASM/outbox object it uses: memory tables, multimodal assets, audit events.  
What frontend feature uses it: API service memory methods; visible memory management still needs full screen proof.  
Positive runtime proof: `scripts/sakina/tech-memory-engine-proof.sh`; expected PII script.  
Negative runtime proof: cross-user memory and PII leakage proofs required.  
What trace/audit/metrics prove it ran: memory DB rows and audit trace.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: `scripts/sakina/tech-pii-redaction-proof.sh` is missing.

### Outbox / Queue and Human Review Queue

Where it sits in the workflow: Steps 21 and 23.  
What runtime decision it makes: durable async work and high-risk escalation.  
What code implements it: `sakina-backend/src/services/outbox_relay.rs`; human review implementation not accepted.  
What backend route invokes it: ingestion/background relay; high-risk Brain path expected.  
What Brain stage invokes it: human review escalation and async events.  
What DB/Qdrant/cache/WASM/outbox object it uses: outbox schema/tables and human review queue tables if present.  
What frontend feature uses it: caveated review/escalation status if exposed.  
Positive runtime proof: expected `scripts/sakina/tech-event-outbox-proof.sh`, `scripts/sakina/tech-human-review-queue-proof.sh`.  
Negative runtime proof: retry/idempotency and admin access denial required.  
What trace/audit/metrics prove it ran: outbox event states and audit rows.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: required outbox and human review proof scripts are missing from current script listing.

### Multimodal AI

Where it sits in the workflow: Steps 2-3, 6, 8-24.  
What runtime decision it makes: accepts or rejects private upload, extracts text/vision/audio understanding, routes through Brain/RAG/safety.  
What code implements it: `sakina-frontend/lib/screens/multimodal_analysis_screen.dart`, `sakina-frontend/lib/services/api_service.dart`, `sakina-backend/src/handlers/multimodal.rs`, `sakina-backend/src/services/multimodal.rs`, `sakina-backend/src/main.rs`.  
What backend route invokes it: `/api/multimodal/analyze`, `/api/multimodal/assets/{asset_id}`.  
What Brain stage invokes it: multimodal route via AIA, then RAG/citation/safety if Islamic sources are needed.  
What DB/Qdrant/cache/WASM/outbox object it uses: `sakina_ai.multimodal_assets`, private storage, brain trace, Qdrant/RAG for extracted text.  
What frontend feature uses it: Analyze tab in `home_shell_screen.dart`.  
Positive runtime proof: `scripts/sakina/multimodal-brain-rag-proof.sh` for text document path.  
Negative runtime proof: `scripts/sakina/multimodal-security-proof.sh`.  
What trace/audit/metrics prove it ran: asset DB metadata, trace ID, Brain/RAG fields.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: live image/vision provider key or local OCR/vision engine is missing; iOS path is missing; full release permissions proof fails.

### OpenTelemetry / Audit / Security Gates

Where it sits in the workflow: Steps 25-27.  
What runtime decision it makes: observability does not decide answers, but proves runtime behavior and security gates reject unsafe paths.  
What code implements it: `sakina-backend/src/telemetry*`, health observability handlers, audit services, security scripts.  
What backend route invokes it: all routes through middleware plus `/health/observability`.  
What Brain stage invokes it: trace and audit around every stage.  
What DB/Qdrant/cache/WASM/outbox object it uses: audit tables, brain traces, metrics/logging.  
What frontend feature uses it: request ID propagation and error rendering.  
Positive runtime proof: expected `scripts/sakina/tech-observability-stack-proof.sh`, `scripts/sakina/security-regression.sh`.  
Negative runtime proof: secret/PII leakage, invalid JWT, cross-user access, CORS/rate-limit, OWASP/MASVS proofs.  
What trace/audit/metrics prove it ran: `/health/observability`, audit events, trace IDs.  
CI/Docker/Kubernetes/release proof: missing.  
Missing pieces: OWASP/MASVS/SAST/container/Kubernetes restricted proof scripts are missing.

### Delivery Machine: CI/CD, Docker, Kubernetes, Release APK/AAB

Where it sits in the workflow: Step 27.  
What runtime decision it makes: release acceptance or rejection.  
What code implements it: `.github/workflows/*`, Docker/infra/k8s manifests, Flutter Android/iOS project files.  
What backend route invokes it: deployment probes hit `/health/ready` and product endpoints.  
What Brain stage invokes it: deployed runtime must show Brain traces.  
What DB/Qdrant/cache/WASM/outbox object it uses: deployed Postgres/Qdrant/cache/storage/secrets/PVCs.  
What frontend feature uses it: release APK/AAB and store configuration.  
Positive runtime proof: final closed beta and product gates.  
Negative runtime proof: fake CI pass scanner and Kubernetes missing/CrashLoop/ImagePull checks.  
What trace/audit/metrics prove it ran: remote CI logs and Kubernetes health/readiness evidence.  
CI/Docker/Kubernetes/release proof: currently not accepted.  
Missing pieces: `sakina-frontend/ios` is missing; Kubernetes proof is not passing; remote CI proof is not accepted; final product gates fail.

## 3. Missing Implementation and Proof Pieces

- `scripts/sakina/tech-source-trust-ranking-proof.sh` is missing.
- `scripts/sakina/tech-citation-hallucination-validator-proof.sh` is missing from current script listing.
- `scripts/sakina/tech-redis-valkey-cache-proof.sh` is missing.
- `scripts/sakina/tech-wasm-proof.sh` is missing from current script listing.
- `scripts/sakina/tech-event-outbox-proof.sh` is missing from current script listing.
- `scripts/sakina/tech-observability-stack-proof.sh` is missing from current script listing.
- `scripts/sakina/tech-owasp-api-security-proof.sh` is missing.
- `scripts/sakina/tech-owasp-masvs-mobile-proof.sh` is missing.
- `scripts/sakina/tech-sast-sca-container-proof.sh` is missing.
- `scripts/sakina/tech-kubernetes-restricted-proof.sh` is missing.
- `scripts/sakina/tech-prompt-injection-proof.sh` is missing.
- `scripts/sakina/tech-pii-redaction-proof.sh` is missing.
- `scripts/sakina/tech-data-retention-deletion-proof.sh` is missing.
- `scripts/sakina/tech-backup-disaster-recovery-proof.sh` is missing.
- `scripts/sakina/tech-load-performance-proof.sh` is missing.
- `scripts/sakina/tech-canary-rollout-proof.sh` is missing.
- `scripts/sakina/tech-crash-reporting-proof.sh` is missing.
- `scripts/sakina/tech-cost-governor-proof.sh` is missing.
- `scripts/sakina/tech-human-review-queue-proof.sh` is missing.
- `scripts/sakina/auth-refresh-proof.sh` is required by the closed beta gate and is missing.
- `sakina-frontend/ios` is missing, so iOS permissions and release proof cannot be accepted.
- Live image/vision proof for multimodal requires a configured provider key or local OCR/vision runtime.
- Full Kubernetes/DNS/ingress proof remains unaccepted.
- Full remote CI/CD proof remains unaccepted.

## 4. Gate Binding

The following gates enforce this workflow-machine view:

- `scripts/sakina/final-advanced-technologies-gate.sh`
- `scripts/sakina/final-brain-workflow-gate.sh`
- `scripts/sakina/final-security-performance-gate.sh`
- `scripts/sakina/final-end-to-end-product-gate.sh`
- `scripts/sakina/final-wiring-gate.sh`
- `scripts/sakina/final-new-technologies-gate.sh`
- `scripts/sakina/final-closed-beta-gate.sh`

If any of these gates fail, the final verdict remains NOT READY - REAL BLOCKERS REMAIN.
