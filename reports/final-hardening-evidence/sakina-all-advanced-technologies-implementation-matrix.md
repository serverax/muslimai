# Sakina Advanced Technologies Implementation Matrix

This matrix enforces the restricted advanced technologies order. A technology is not accepted unless it is proven through the full Sakina workflow: Flutter frontend, backend API, auth/JWT/RLS, Brain/AIA, retrieval or service layer, DB/Qdrant/cache/storage/outbox, audit/observability, frontend rendering, CI/CD, Docker, Kubernetes, and release APK/AAB evidence.

Status values in this file are intentionally strict. `COMPLETE - END-TO-END INTEGRATED AND PROVEN` is reserved only for technologies with all required positive, negative, CI, Docker, Kubernetes, and release evidence.

## Brain Mother Algorithm / Central Orchestrator

Technology: Brain Mother Algorithm / Central Orchestrator  
Workflow position: Backend user-facing AI route -> Brain -> AIA/RAG/Safety/DB -> response  
Frontend files: `sakina-frontend/lib/services/api_service.dart`, chat/ask screens  
Backend files: `sakina-backend/src/services/brain*`, `sakina-backend/src/services/aia_orchestrator.rs`, handlers in `sakina-backend/src/handlers`  
DB tables/functions/triggers: `sakina_ai.brain_decision_traces`, audit tables  
Qdrant/cache/storage objects: semantic cache and retrieval traces where used  
Brain/AIA stages: request intake, intent, risk, entitlement, retrieval planner, validation, final trace  
Security controls: JWT, user ownership, RLS, safety validators  
Positive proof script: `scripts/sakina/tech-brain-orchestrator-proof.sh`  
Negative proof script: required in full workflow gates; bypass proof not yet accepted end to end  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/300-tech-brain-orchestrator-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## AIA / Agentic AI Workflow Engine

Technology: AIA / Agentic AI Workflow Engine  
Workflow position: Brain -> controlled agents -> retrieval/reasoning/validation -> Brain final response  
Frontend files: API-backed chat/ask flows  
Backend files: `sakina-backend/src/services/aia_orchestrator.rs`, `sakina-backend/src/services/brain*`  
DB tables/functions/triggers: brain traces, audit events  
Qdrant/cache/storage objects: Qdrant and cache where retrieval agents execute  
Brain/AIA stages: agent routing, allowed tools, audit trace  
Security controls: no direct tool bypass, JWT/RLS inherited from route  
Positive proof script: `scripts/sakina/tech-agentic-workflow-proof.sh`  
Negative proof script: required by `final-brain-workflow-gate.sh`  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/310-tech-agentic-workflow-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## RAG for Islamic Sources

Technology: RAG for Islamic Sources  
Workflow position: Brain retrieval planner -> hybrid/vector/source retrieval -> citation validation -> answer  
Frontend files: chat/ask result rendering with citations  
Backend files: `sakina-backend/src/services/rag*`, `sakina-backend/src/services/hybrid_rag.rs`, `sakina-backend/src/services/qdrant_client.rs`  
DB tables/functions/triggers: Islamic source/document/chunk tables and traces  
Qdrant/cache/storage objects: Qdrant Islamic chunks collection, semantic cache  
Brain/AIA stages: retrieval planner, source trust, context compression, validators  
Security controls: authenticated route, user-scoped traces, no fake citations  
Positive proof script: `scripts/sakina/tech-rag-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/320-tech-rag-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Graph RAG / Islamic Knowledge Graph

Technology: Graph RAG / Islamic Knowledge Graph  
Workflow position: Brain retrieval planner -> graph traversal -> hybrid context -> validators  
Frontend files: related concepts/citation rendering where exposed  
Backend files: `sakina-backend/src/services/graph_rag.rs`, RAG services  
DB tables/functions/triggers: `sakina_ai.knowledge_graph_entities`, `sakina_ai.knowledge_graph_edges`  
Qdrant/cache/storage objects: Qdrant context combined with graph evidence  
Brain/AIA stages: graph relationship agent, retrieval planner, trace  
Security controls: source-backed graph expansion, no static graph result accepted  
Positive proof script: `scripts/sakina/tech-graph-rag-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/330-tech-graph-rag-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Hybrid Search

Technology: Hybrid Search  
Workflow position: Brain retrieval planner -> vector plus lexical retrieval -> rerank -> context  
Frontend files: chat/ask flow  
Backend files: `sakina-backend/src/services/hybrid_rag.rs`, RAG services  
DB tables/functions/triggers: Islamic chunk/source tables and retrieval traces  
Qdrant/cache/storage objects: Qdrant vector collection plus DB keyword search  
Brain/AIA stages: retrieval planner and source ranking  
Security controls: source trust and citation validators  
Positive proof script: `scripts/sakina/tech-hybrid-search-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/340-tech-hybrid-search-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Islamic Source Trust Ranking

Technology: Islamic Source Trust Ranking  
Workflow position: RAG results -> source trust rank -> compressed context -> validators  
Frontend files: citation/source display  
Backend files: RAG/source ranking services  
DB tables/functions/triggers: source registry and citation metadata tables  
Qdrant/cache/storage objects: chunk payload metadata with source trust fields  
Brain/AIA stages: source trust ranking agent/stage  
Security controls: reject unsupported or untrusted source claims  
Positive proof script: `scripts/sakina/tech-source-trust-ranking-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/580-tech-source-trust-ranking-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Citation Validator

Technology: Citation Validator  
Workflow position: Draft answer -> citation support check -> final or blocked answer  
Frontend files: citation rendering and error/caveat state  
Backend files: citation validation services, evaluation services  
DB tables/functions/triggers: citation validation trace/audit rows  
Qdrant/cache/storage objects: retrieved chunks and metadata  
Brain/AIA stages: citation verifier agent/stage  
Security controls: blocks hallucinated citations  
Positive proof script: `scripts/sakina/tech-citation-hallucination-validator-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/480-tech-citation-hallucination-validator-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Hallucination Validator

Technology: Hallucination Validator  
Workflow position: Draft answer -> unsupported claim check -> safety gate  
Frontend files: caveat/refusal rendering  
Backend files: evaluation and citation validation services  
DB tables/functions/triggers: evaluation result and audit tables  
Qdrant/cache/storage objects: retrieved source evidence  
Brain/AIA stages: hallucination reviewer agent/stage  
Security controls: blocks unsupported religious claims  
Positive proof script: `scripts/sakina/tech-citation-hallucination-validator-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/480-tech-citation-hallucination-validator-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Islamic Safety Guard / Policy-as-Code

Technology: Islamic Safety Guard / Policy-as-Code  
Workflow position: Draft/final answer -> Islamic policy validation -> final response or caveat/refusal  
Frontend files: answer/caveat display  
Backend files: safety/evaluation/policy services  
DB tables/functions/triggers: safety trace and audit events  
Qdrant/cache/storage objects: source evidence where religious claims are validated  
Brain/AIA stages: Islamic safety reviewer agent/stage  
Security controls: extremist misuse refusal, sensitive fatwa caveat, citation support  
Positive proof script: `scripts/sakina/tech-policy-as-code-proof.sh` and `scripts/sakina/islamic-safety-regression.sh`  
Negative proof script: Islamic safety regression negative cases  
CI proof: covered by required proof script evidence and final CI gate remains separate in full gate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/470-tech-policy-as-code-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Context Compression

Technology: Context Compression  
Workflow position: retrieved evidence -> compressed context preserving citations -> LLM/router  
Frontend files: trace/dev evidence only if exposed  
Backend files: `sakina-backend/src/services/context*` or RAG compression services  
DB tables/functions/triggers: brain trace fields and retrieval metadata  
Qdrant/cache/storage objects: retrieved chunks before compression  
Brain/AIA stages: context compression stage  
Security controls: citation preservation and token budget enforcement  
Positive proof script: `scripts/sakina/tech-context-compression-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/370-tech-context-compression-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## AI Router / Model Router

Technology: AI Router / Model Router  
Workflow position: Brain/cost governor -> provider/model selection -> LLM call or fail closed  
Frontend files: no direct provider access  
Backend files: `sakina-backend/src/services/aia_orchestrator.rs`, AI router services  
DB tables/functions/triggers: brain trace provider/model fields  
Qdrant/cache/storage objects: semantic cache interacts before/after provider call  
Brain/AIA stages: cost governor, AI router, provider result  
Security controls: environment driven provider config; no mock fallback in production  
Positive proof script: `scripts/sakina/tech-ai-router-proof.sh`  
Negative proof script: provider missing/fail-closed proof required by gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/380-tech-ai-router-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Evaluation AI / Islamic Quality Gate

Technology: Evaluation AI / Islamic Quality Gate  
Workflow position: answer draft -> quality/safety evaluation -> final response  
Frontend files: caveat/blocked-state rendering  
Backend files: evaluation services  
DB tables/functions/triggers: evaluation results and brain traces  
Qdrant/cache/storage objects: retrieved evidence for grounding  
Brain/AIA stages: hallucination reviewer and Islamic safety reviewer  
Security controls: blocks weak or unsafe answers  
Positive proof script: `scripts/sakina/tech-evaluation-ai-proof.sh`  
Negative proof script: evaluation failure dataset  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/390-tech-evaluation-ai-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Semantic Cache

Technology: Semantic Cache  
Workflow position: Brain/cache lookup -> safe hit or miss -> route result  
Frontend files: no direct cache access  
Backend files: semantic cache services  
DB tables/functions/triggers: semantic cache entries/metadata  
Qdrant/cache/storage objects: cache persistence and invalidation metadata  
Brain/AIA stages: semantic cache check/update  
Security controls: user/source-version safe keying, no private leakage  
Positive proof script: `scripts/sakina/tech-semantic-cache-proof.sh`  
Negative proof script: cross-user/no-leak cache proof required by gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/350-tech-semantic-cache-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Redis / Valkey Performance Cache

Technology: Redis / Valkey Performance Cache  
Workflow position: backend cache/queue performance layer  
Frontend files: no direct access  
Backend files: cache clients/config where present  
DB tables/functions/triggers: DB remains source of truth  
Qdrant/cache/storage objects: Redis/Valkey service  
Brain/AIA stages: cache/performance stage where used  
Security controls: no private data leakage, TTLs, auth if deployed  
Positive proof script: `scripts/sakina/tech-redis-valkey-cache-proof.sh`  
Negative proof script: cache outage/fail-closed proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/590-tech-redis-valkey-cache-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## WASM Module

Technology: WASM Module  
Workflow position: mobile/backend local computation where applicable -> Brain/prayer/qibla/policy validation  
Frontend files: Flutter WASM integration if exposed  
Backend files: WASM modules/bindings if backend uses them  
DB tables/functions/triggers: trace/audit for WASM-derived decisions  
Qdrant/cache/storage objects: none unless cached  
Brain/AIA stages: WASM validation/calculation stage where required  
Security controls: deterministic local validation, no unsafe native code path  
Positive proof script: `scripts/sakina/tech-wasm-proof.sh`  
Negative proof script: required by advanced gate  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/420-tech-wasm-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## MCP / Connector Layer

Technology: MCP / Connector Layer  
Workflow position: Brain-gated external connector calls only  
Frontend files: no direct connector access  
Backend files: MCP connector registry/service  
DB tables/functions/triggers: audit and connector invocation logs  
Qdrant/cache/storage objects: none by default  
Brain/AIA stages: connector permission and tool execution stage  
Security controls: disabled unless configured, audit logs, no direct mobile access  
Positive proof script: `scripts/sakina/tech-mcp-connectors-proof.sh`  
Negative proof script: direct access and disabled-state proof  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/400-tech-mcp-connectors-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Event Bus / Queue / Outbox

Technology: Event Bus / Queue / Outbox  
Workflow position: backend side effects -> durable outbox/queue -> workers/audit/notifications  
Frontend files: notification/status surfaces if exposed  
Backend files: outbox/event services  
DB tables/functions/triggers: outbox tables/functions/triggers  
Qdrant/cache/storage objects: queue broker if used  
Brain/AIA stages: human review, audit, async side effects  
Security controls: idempotency, ownership, audit trail  
Positive proof script: `scripts/sakina/tech-event-outbox-proof.sh`  
Negative proof script: retry/idempotency proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate  
Evidence file: `reports/final-hardening-evidence/440-tech-event-outbox-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## OpenTelemetry Observability

Technology: OpenTelemetry Observability  
Workflow position: trace ID across frontend -> backend -> Brain -> DB/RAG/provider -> response  
Frontend files: request ID generation/propagation where present  
Backend files: telemetry/middleware/health observability handlers  
DB tables/functions/triggers: audit events and traces  
Qdrant/cache/storage objects: retrieval/provider trace references  
Brain/AIA stages: trace IDs around each stage  
Security controls: no sensitive data in logs  
Positive proof script: `scripts/sakina/tech-observability-stack-proof.sh`  
Negative proof script: sensitive log leakage proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/490-tech-observability-stack-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## OWASP API Security Gate

Technology: OWASP API Security Gate  
Workflow position: request ingress -> auth/rate/CORS/BOLA/security checks -> route  
Frontend files: error handling for auth/security responses  
Backend files: middleware, auth, handlers  
DB tables/functions/triggers: audit events for security events  
Qdrant/cache/storage objects: none directly  
Brain/AIA stages: prompt/security guard where AI route  
Security controls: JWT, invalid/expired/revoked token, rate limit, BOLA, CORS  
Positive proof script: `scripts/sakina/security-regression.sh` and `scripts/sakina/tech-owasp-api-security-proof.sh`  
Negative proof script: `scripts/sakina/security-regression.sh`  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/600-tech-owasp-api-security-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## OWASP MASVS Mobile Security Gate

Technology: OWASP MASVS Mobile Security Gate  
Workflow position: Flutter secure storage/config/release permissions/build hardening  
Frontend files: Flutter lib, Android, iOS project files  
Backend files: auth/session endpoints used by mobile  
DB tables/functions/triggers: session/token/audit tables  
Qdrant/cache/storage objects: none directly  
Brain/AIA stages: no direct mobile AI bypass  
Security controls: secure token storage, no static tokens, release permission minimization  
Positive proof script: `scripts/sakina/tech-owasp-masvs-mobile-proof.sh`  
Negative proof script: fake token/static config scanner  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/610-tech-owasp-masvs-mobile-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## SAST / SCA / Secret / Container Scanning

Technology: SAST / SCA / Secret / Container Scanning  
Workflow position: CI/CD pre-release security gates  
Frontend files: dependency manifests  
Backend files: Rust dependency manifests and source  
DB tables/functions/triggers: migration scans where applicable  
Qdrant/cache/storage objects: container images  
Brain/AIA stages: no direct stage  
Security controls: SAST, dependency, secret, container scans fail CI  
Positive proof script: `scripts/sakina/tech-sast-sca-container-proof.sh`  
Negative proof script: secret leak fixture/gate proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/620-tech-sast-sca-container-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Kubernetes Restricted / Admission Policy Gate

Technology: Kubernetes Restricted / Admission Policy Gate  
Workflow position: deployment admission -> restricted runtime -> readiness proof  
Frontend files: release config/endpoints only  
Backend files: deployment manifests and env config  
DB tables/functions/triggers: migration jobs and DB connectivity  
Qdrant/cache/storage objects: Kubernetes services/PVCs/secrets  
Brain/AIA stages: deployed runtime traces  
Security controls: restricted pods, no missing secrets, TLS/ingress  
Positive proof script: `scripts/sakina/tech-kubernetes-restricted-proof.sh`  
Negative proof script: policy rejection proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/630-tech-kubernetes-restricted-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Prompt Injection / Jailbreak Guard

Technology: Prompt Injection / Jailbreak Guard  
Workflow position: Brain pre-check and retrieval-source injection validation  
Frontend files: chat/ask flow  
Backend files: prompt guard/safety/evaluation services  
DB tables/functions/triggers: safety/audit traces  
Qdrant/cache/storage objects: retrieved source injection validation  
Brain/AIA stages: prompt injection guard before retrieval/model call  
Security controls: unsafe prompt refusal/caveat  
Positive proof script: `scripts/sakina/tech-prompt-injection-proof.sh`  
Negative proof script: jailbreak and RAG source injection cases  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/640-tech-prompt-injection-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## PII Detection and Redaction

Technology: PII Detection and Redaction  
Workflow position: upload/input/logging/trace -> PII redaction -> Brain/provider/audit  
Frontend files: upload/chat flows  
Backend files: redaction/privacy services, multimodal service  
DB tables/functions/triggers: audit/log tables without sensitive leakage  
Qdrant/cache/storage objects: stored private assets and redacted text  
Brain/AIA stages: privacy guard before provider/trace  
Security controls: no PII/secrets in logs, private storage  
Positive proof script: `scripts/sakina/tech-pii-redaction-proof.sh`  
Negative proof script: PII leak tests  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/650-tech-pii-redaction-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Data Retention and Account Deletion Engine

Technology: Data Retention and Account Deletion Engine  
Workflow position: frontend account deletion/export -> backend -> DB/storage/Qdrant/cache cleanup -> audit  
Frontend files: settings/account screens  
Backend files: profile/settings/account deletion handlers/services  
DB tables/functions/triggers: delete/export request tables and user-owned data tables  
Qdrant/cache/storage objects: private assets, cache entries, vector references  
Brain/AIA stages: not an AI stage, but audit/ownership enforced  
Security controls: authenticated user only, irreversible deletion audit, no cross-user delete  
Positive proof script: `scripts/sakina/tech-data-retention-deletion-proof.sh`  
Negative proof script: cross-user delete denied proof  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/660-tech-data-retention-deletion-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Backup and Disaster Recovery

Technology: Backup and Disaster Recovery  
Workflow position: DB/storage/Qdrant backup -> restore drill -> verified runtime  
Frontend files: no direct feature  
Backend files: operational scripts/manifests  
DB tables/functions/triggers: all critical schemas  
Qdrant/cache/storage objects: vector and private storage backup where required  
Brain/AIA stages: restored traces must remain valid  
Security controls: encrypted backup, restore access control  
Positive proof script: `scripts/sakina/tech-backup-disaster-recovery-proof.sh`  
Negative proof script: restore failure/verification proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/670-tech-backup-disaster-recovery-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Load Testing / Performance Budget

Technology: Load Testing / Performance Budget  
Workflow position: E2E runtime under expected beta load -> latency/error budgets  
Frontend files: no direct feature  
Backend files: load test targets and performance-critical services  
DB tables/functions/triggers: query performance and indexes  
Qdrant/cache/storage objects: Qdrant/cache under load  
Brain/AIA stages: routing and cost/latency metrics  
Security controls: rate limits remain enforced under load  
Positive proof script: `scripts/sakina/tech-load-performance-proof.sh`  
Negative proof script: budget failure proof required  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/680-tech-load-performance-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Canary / Feature Rollout

Technology: Canary / Feature Rollout  
Workflow position: feature flag/rollout -> backend/mobile behavior -> metrics/audit  
Frontend files: feature flag consumption in visible features  
Backend files: feature flag/entitlement services  
DB tables/functions/triggers: feature flag and entitlement tables  
Qdrant/cache/storage objects: cache invalidation for flags  
Brain/AIA stages: feature flag/entitlement check  
Security controls: closed beta access and fail-closed hidden unavailable features  
Positive proof script: `scripts/sakina/tech-canary-rollout-proof.sh`  
Negative proof script: disabled cohort denied/hidden proof  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/690-tech-canary-rollout-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Crash Reporting

Technology: Crash Reporting  
Workflow position: mobile/backend crash -> report -> trace/audit/alerting  
Frontend files: Flutter crash reporting initialization  
Backend files: error logging/observability handlers  
DB tables/functions/triggers: audit/error events where persisted  
Qdrant/cache/storage objects: none directly  
Brain/AIA stages: failures include trace ID  
Security controls: no sensitive data in crash reports  
Positive proof script: `scripts/sakina/tech-crash-reporting-proof.sh`  
Negative proof script: sensitive crash payload rejection/redaction proof  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/700-tech-crash-reporting-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Cost Governor

Technology: Cost Governor  
Workflow position: Brain -> quota/cost check -> AI router/provider call or denial  
Frontend files: error/quota state where exposed  
Backend files: cost governor/model router services  
DB tables/functions/triggers: usage/quota/audit tables  
Qdrant/cache/storage objects: semantic cache reduces repeated provider cost  
Brain/AIA stages: cost governor before model call  
Security controls: abuse prevention, no unlimited provider calls  
Positive proof script: `scripts/sakina/tech-cost-governor-proof.sh`  
Negative proof script: quota exceeded denial proof  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/710-tech-cost-governor-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Human Review Queue

Technology: Human Review Queue  
Workflow position: high-risk Brain/safety result -> queue -> admin/audit workflow -> user-safe response  
Frontend files: high-risk caveat/status display  
Backend files: safety/human review queue services  
DB tables/functions/triggers: human review queue and audit tables  
Qdrant/cache/storage objects: source evidence linked to review item  
Brain/AIA stages: human review escalation stage  
Security controls: PII minimized, admin-only access, audit logs  
Positive proof script: `scripts/sakina/tech-human-review-queue-proof.sh`  
Negative proof script: normal user admin access denied proof  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/720-tech-human-review-queue-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

## Multimodal AI

Technology: Multimodal AI  
Workflow position: Flutter upload -> backend upload/JWT/RLS/private storage -> OCR/vision/audio provider -> Brain/RAG/safety -> frontend answer  
Frontend files: `sakina-frontend/lib/screens/multimodal_analysis_screen.dart`, `sakina-frontend/lib/services/api_service.dart`, Android manifest  
Backend files: `sakina-backend/src/handlers/multimodal.rs`, `sakina-backend/src/services/multimodal.rs`, `sakina-backend/src/main.rs`  
DB tables/functions/triggers: `sakina_ai.multimodal_assets`, brain traces, audit events  
Qdrant/cache/storage objects: private storage directory, Qdrant RAG when extracted text requires sources  
Brain/AIA stages: multimodal route, Brain/AIA routing, RAG, citation/safety validation  
Security controls: JWT required, ignores body user_id, type/size validation, private owner-scoped access, cross-user denial  
Positive proof script: `scripts/sakina/tech-multimodal-ai-proof.sh`  
Negative proof script: `scripts/sakina/multimodal-security-proof.sh`  
CI proof: covered by required proof script evidence and final CI gate remains separate  
Docker proof: covered by required proof script evidence where applicable and final Docker gate remains separate  
Kubernetes proof: covered by required proof script evidence where applicable and final deployment gate remains separate  
Release APK/AAB proof: covered by required proof script evidence where applicable and final mobile release gate remains separate
Evidence file: `reports/final-hardening-evidence/410-tech-multimodal-ai-proof.sh.txt`  
Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN
Remaining blocker: none for this advanced technology proof; final closed-beta product and deployment gates remain separate acceptance checks.

