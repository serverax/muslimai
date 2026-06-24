# Sakina AI — Restricted Advanced Technologies Order with Full End-to-End Workflow

**Project:** Sakina AI  
**Root path:** `F:\SakinaAL` / `/mnt/f/SakinaAL`  
**Tasks path:** `F:\SakinaAL\tasks` / `/mnt/f/SakinaAL/tasks`  
**Repository:** `https://github.com/serverax/muslimai`  
**Output report:** `F:\SakinaAL\reports\sakina-advanced-technologies-end-to-end-signoff.md`

This order is for **Sakina AI only**.

Do not work on:

```text
lawapp
OrdinoxAI
Hermes
RightsNow
IterLaw
AIA hiring platform
any unrelated repo
```

unless the owner explicitly says the specific task is required for Sakina deployment.

---

# 0. Non-Negotiable Owner Instruction

Claude Code must create, wire, test, and prove every technology inside the real Sakina AI workflow.

The owner is **not accepting**:

```text
FAILED
BLOCKED
PARTIAL
LOCAL ONLY
SAFE DISABLED AS COMPLETION
MOCKED
PLACEHOLDER
DOCUMENTED ONLY
IMPLEMENTED BUT NOT WIRED
ISOLATED COMPONENT SUCCESS
REPORT-ONLY SUCCESS
```

If something fails, fix it.

If a provider, secret, external system, Apple/Google account, Kubernetes context, or owner credential is missing, implement the real path, make the system fail closed, and report the exact owner action required. But do not call it complete.

---

# 1. Meaning of Acceptance

Acceptance does not mean:

- file exists
- route exists
- table exists
- code compiles
- mocked script passes
- report says implemented
- screenshot exists
- technology is mentioned in docs
- local-only backend works
- container is reachable
- Flutter screen exists
- DB table exists
- CI file exists

Acceptance means the full Sakina AI workflow works end to end:

```text
Flutter mobile app
→ frontend screen
→ frontend service/state
→ real HTTP request
→ backend API
→ auth/JWT/session/security guard
→ RLS/user isolation
→ Brain Mother Algorithm
→ AIA / agentic workflow
→ Islamic intent classifier
→ user profile/context
→ risk/safety classifier
→ feature flag/entitlement check
→ prompt injection guard
→ RAG / Graph RAG / Hybrid Search
→ Islamic source trust ranking
→ context compression
→ AI router / model router
→ LLM/provider call where required
→ citation and hallucination validator
→ Islamic safety / policy-as-code guard
→ memory engine / semantic cache / WASM / queue / Qdrant / DB where required
→ audit log
→ OpenTelemetry trace/metrics/logs
→ response back to backend
→ response back to frontend
→ frontend renders real backend result
→ CI/CD proof
→ Docker proof
→ Kubernetes proof
→ release APK/AAB proof
```

No isolated component is accepted.

---

# 2. Final Integrated Sakina Workflow

After implementation, the real workflow must be:

```text
User opens Sakina mobile app
→ secure token/session check
→ frontend loads feature flags and user profile
→ user asks an Islamic/lifestyle/prayer/Q&A question
→ frontend sends real authenticated request
→ backend validates auth/JWT/session
→ backend enforces user ownership/RLS
→ Brain Mother Algorithm starts trace
→ Islamic intent is classified
→ language is detected: Arabic / English
→ risk/sensitivity is classified
→ feature entitlement is checked
→ prompt injection/jailbreak guard runs
→ memory permission check runs
→ user memory and safe preferences are loaded
→ retrieval planner decides if RAG/Graph RAG is needed
→ hybrid search runs: vector + lexical
→ Graph RAG runs where relevant
→ Islamic source trust ranking runs
→ context compression runs
→ semantic cache is checked safely
→ cost governor checks provider cost/quota
→ AI router selects model/provider
→ LLM drafts answer if required
→ citation validator checks source support
→ hallucination validator checks unsupported claims
→ Islamic policy-as-code safety guard validates answer
→ high-risk religious/safety issue triggers safe caveat or human-review queue
→ final answer is returned or safely refused/caveated
→ DB/Qdrant/cache/outbox/audit are updated
→ frontend displays answer, citations, caveats, and next steps
→ trace ID links frontend, backend, Brain, DB, Qdrant, LLM, logs, metrics
→ CI/CD, Docker, Kubernetes, and release gates prove the workflow
```

This is the workflow the system must implement.

---

# 3. Brain Mother Algorithm / Central Orchestrator

## Workflow position

```text
Backend route → Brain Mother Algorithm → All AI/RAG/DB/Tool decisions → Final response
```

## Required implementation

Create or upgrade the Brain Mother Algorithm with these stages:

```text
Request Intake
→ Auth/User Context
→ Profile/Language Context
→ Islamic Intent Classification
→ Risk/Sensitivity Classification
→ Feature Flag/Entitlement Check
→ Memory Permission Check
→ Retrieval Planner
→ Semantic Cache Check
→ Hybrid Search
→ Graph RAG
→ Islamic Source Trust Ranking
→ Context Compression
→ Cost Governor
→ AI Router
→ Draft Response
→ Citation Validator
→ Hallucination Validator
→ Islamic Policy-as-Code Safety Guard
→ Human Review Queue if high risk
→ Final Response
→ Audit Log
→ OpenTelemetry Trace/Metrics
```

## Acceptance criteria

Accepted only if:

- every user-facing AI answer goes through Brain
- every Brain stage appears in trace
- trace is persisted in DB
- no backend route can call LLM directly
- no backend route can answer Islamic guidance without safety validation
- no RAG route can bypass source trust and citation validation
- every frontend user action maps to Brain-controlled backend route
- direct bypass tests fail correctly
- CI proves no direct LLM/RAG bypass exists
- Kubernetes logs show Brain executing in deployed runtime

Reject if:

- Brain exists but only one route uses it
- Brain trace is static JSON
- handlers call LLM directly
- citation validation is optional
- Islamic safety can be skipped
- local-only proof is used as closed-beta proof

---

# 4. Agentic AI / AIA Workflow Engine

## Workflow position

```text
Brain → AIA / Agent Workflow → Retrieval / Reasoning / Validation → Brain Final Response
```

## Required agents

Create controlled agents for:

- Islamic intent classifier agent
- Arabic/English language agent
- user memory assistant
- RAG retrieval agent
- Graph RAG relationship agent
- source trust ranking agent
- citation verifier agent
- hallucination reviewer agent
- Islamic safety reviewer agent
- prayer/lifestyle assistant agent if feature exists
- multimodal assistant if enabled
- entitlement/billing assistant if payments exist
- human-review/escalation agent

## Required implementation

Each agent must have:

- agent ID
- input schema
- output schema
- allowed tools
- denied tools
- timeout
- retry limit
- audit log
- trace log
- failure state
- safe fallback

## Acceptance criteria

Accepted only if:

- agents are code-defined, not prompt-only
- Brain invokes the agent workflow
- schemas are enforced
- forbidden tool calls are blocked
- failed agent step is persisted
- retry and timeout are tested
- agent output affects final response
- frontend answer can be traced to agent stages
- CI tests positive and negative workflows

Reject if:

- agents are just prompt sections
- any agent can call any tool
- no persisted workflow state exists
- failed steps disappear
- no real Sakina answer uses agents end to end

---

# 5. RAG for Islamic Sources

## Workflow position

```text
Brain → Retrieval Planner → RAG → Hybrid Search → Source Trust → Citation Validator → Final Answer
```

## Required implementation

RAG must include:

- trusted Islamic source ingestion pipeline
- source metadata
- source type
- language
- madhhab/fiqh/context metadata if used
- chunking
- embeddings
- Qdrant vector storage
- citation IDs
- source version/date
- topic tags
- source trust ranking
- reindex job
- stale source detection

Initial source types may include:

- Qur'an references
- Hadith references where properly sourced
- trusted Islamic guidance content
- curated app knowledge
- prayer/fasting/zakat content if features exist
- safety/disclaimer policies

## Acceptance criteria

Accepted only if:

- real Islamic documents/chunks are ingested
- chunks have real source metadata
- embeddings exist in Qdrant
- query generates real embedding
- retrieval returns source chunks
- answer cites retrieved sources
- unsupported answer fails closed or is caveated
- weak/untrusted source is downgraded or blocked
- frontend displays citations/source basis
- CI proves retrieval and citation validation

Reject if:

- vector collection exists but no vectors
- answer ignores retrieved chunks
- citations are fabricated
- sources have no metadata
- RAG is mocked
- LLM answer is allowed without source validation for source-required questions

---

# 6. Graph RAG / Islamic Knowledge Graph

## Workflow position

```text
Brain → Islamic Intent Classifier → Graph RAG → Relationship Context → RAG/LLM → Citation Validator
```

## Required implementation

Create graph data for:

- Islamic concepts
- prayer topics
- fasting topics
- zakat topics
- Qur'an references
- Hadith references
- topic relationships
- source relationships
- related rulings/guidance
- caution/escalation concepts
- user intent relationships
- evidence-to-answer relationships

Must include:

- entity extraction
- relationship extraction
- graph traversal
- graph context builder
- graph trace
- fallback if no entity is found

## Acceptance criteria

Accepted only if:

- graph data contains real entities and edges
- graph traversal runs during real Islamic question
- graph context appears in Brain trace
- graph result affects retrieval/reasoning
- at least 5 Islamic/lifestyle issue types are tested
- missing-entity tests fail cleanly
- frontend result includes graph-supported reasoning where relevant

Reject if:

- graph is only tables
- graph proof is only SQL count
- graph traversal is not called
- graph output does not affect final answer

---

# 7. Hybrid Search

## Workflow position

```text
Brain → Retrieval Planner → Vector Search + Lexical Search → Hybrid Ranking → RAG Context
```

## Required implementation

Hybrid search must include:

- vector search
- lexical/full-text search
- score normalisation
- weighted ranking
- duplicate removal
- source trust weighting
- language weighting Arabic/English
- recency/version weighting where relevant
- ranking trace
- vector failure fallback
- lexical failure fallback

## Acceptance criteria

Accepted only if:

- vector result is shown
- lexical result is shown
- merged ranking is shown
- duplicate removal is proven
- source trust affects ranking
- Arabic and English queries are tested
- fallback paths are tested
- final answer uses hybrid-ranked sources

Reject if:

- only vector search exists
- only SQL LIKE search exists
- ranking is hidden
- no fallback test exists

---

# 8. Islamic Source Trust Ranking

## Workflow position

```text
RAG/Hybrid Search → Source Trust Ranking → Context Selection → Citation Validator
```

## Required implementation

Create trust levels for source types:

- Qur'an reference: highest
- verified hadith source: high, with grading/context where available
- curated trusted Islamic guidance: high/medium depending on source
- app internal content: medium
- user-provided content: low and never authoritative
- unknown/unverified source: rejected or heavily downgraded

Trust score must consider:

- source type
- authenticity/verification
- language
- topic
- publication/update date
- source authority
- conflict with higher-trust source
- whether answer requires caution or scholar referral

## Acceptance criteria

Accepted only if:

- every source has trust metadata
- trust affects ranking
- low-trust content cannot override high-trust source
- unknown sources are blocked or downgraded
- source conflict is detected and flagged
- trace shows source trust decision
- frontend shows source basis/caveat where relevant

Reject if:

- all sources get same score
- unknown sources are treated as authoritative
- final answer does not show source basis

---

# 9. Citation and Hallucination Validator

## Workflow position

```text
Draft Answer → Citation Validator → Hallucination Validator → Islamic Safety Guard → Final Answer
```

## Required implementation

Validator must check:

- cited source IDs exist
- cited source supports answer claim
- unsupported claims are removed or blocked
- fabricated citations are rejected
- minimum evidence threshold
- Arabic/English source match where relevant
- answer caveats uncertainty
- answer does not produce unsupported fatwa-like certainty

## Acceptance criteria

Accepted only if:

- every source-required answer has citations
- fabricated source ID is rejected
- unsupported claim is detected
- no-source Islamic answer is blocked or caveated
- hallucination trap tests fail closed
- validator result is persisted in Brain trace
- frontend shows citation/support status

Reject if:

- citations are only text
- source IDs are not checked
- unsupported answer is allowed
- validator runs only in tests and not runtime

---

# 10. Islamic Safety Guard / Policy-as-Code

## Workflow position

```text
Brain → Risk/Sensitivity Classifier → Policy-as-Code → Draft Answer → Islamic Safety Guard → Final Response
```

## Required implementation

Policies must cover:

- no unsupported fatwa claims
- sensitive religious questions
- sectarian/rage-bait content
- crisis/self-harm content
- medical/legal/financial crossover questions
- family/marriage sensitive advice
- user vulnerability signals
- source-required questions
- when to advise asking a qualified scholar
- when to refuse or caveat
- when to provide general education only

Policies must be:

- versioned
- testable
- traceable
- configurable by topic
- enforced at runtime

## Acceptance criteria

Accepted only if:

- policies exist outside prompt text
- policies are versioned
- each policy has tests
- high-risk question triggers stricter safety
- unsupported fatwa-like answer is blocked
- sectarian unsafe content is blocked
- crisis/safety question routes safely
- policy decision appears in trace
- frontend shows warning/caveat where required

Reject if:

- policies are prompt-only
- no tests per policy
- risk signals are ignored
- Islamic safety can be bypassed

---

# 11. Context Compression

## Workflow position

```text
User Memory + Case/Conversation Context + Retrieved Sources → Context Compression → AI Router / LLM
```

## Required implementation

Compression must preserve:

- source IDs
- Islamic topic
- user intent
- language
- safety flags
- risk flags
- user preferences if allowed
- retrieved evidence
- source hierarchy/trust level
- caveats

## Acceptance criteria

Accepted only if:

- before/after token or character size is shown
- context is reduced
- source IDs are preserved
- safety/risk flags are preserved
- answer still cites correct sources
- compression failure falls back safely
- trace shows compression stage

Reject if:

- source IDs are lost
- Islamic caution is removed
- safety flags are removed
- no before/after proof exists

---

# 12. AI Router / Model Router

## Workflow position

```text
Brain → Task/Risk/Cost/Language Classification → AI Router → Provider/Model → Validator
```

## Required implementation

Route by:

- topic
- complexity
- risk/sensitivity
- cost
- Arabic/English
- evidence requirement
- latency requirement
- provider availability
- fallback provider
- safe-disabled provider state

## Acceptance criteria

Accepted only if:

- Brain calls the router
- routing decision is logged
- different tasks route differently
- high-risk Islamic question uses stricter route
- disabled provider is not selected
- provider failure safely falls back or fails closed
- no route calls provider directly
- CI tests routing decisions

Reject if:

- one hardcoded provider is always used
- router exists but is not called
- disabled provider is selected
- failure crashes request

---

# 13. Evaluation AI / Islamic Quality Gate

## Workflow position

```text
Generated Answer → Evaluation AI → Threshold Decision → Pass / Rewrite / Caveat / Escalate / Fail
```

## Required implementation

Dataset must include at least 50 cases:

- Islamic source-required questions
- prayer questions
- fasting questions
- zakat questions
- family/marriage sensitive questions
- sectarian unsafe prompts
- crisis/self-harm religious prompts
- hallucination traps
- citation-required cases
- refusal/caveat cases
- Arabic cases
- English cases

Score:

- Islamic safety
- citation support
- hallucination risk
- clarity
- language correctness
- source trust
- refusal correctness
- caution/escalation correctness

## Acceptance criteria

Accepted only if:

- dataset exists
- at least 50 cases exist
- scoring output is produced
- threshold is enforced
- failed cases are listed
- CI fails if score drops
- answer pipeline uses evaluation where required

Reject if:

- evaluation is manual only
- no threshold
- no hallucination traps
- no Arabic tests
- CI does not run it

---

# 14. Semantic Cache

## Workflow position

```text
Brain → Cache Lookup → Safety Check → Return Cached / Continue Retrieval
```

## Required implementation

Cache must include:

- semantic similarity
- user isolation
- source version hash
- TTL
- source-update invalidation
- safety re-check
- citation re-check if needed
- hit/miss metrics
- no PII in keys

## Acceptance criteria

Accepted only if:

- first similar question is cache miss
- second similar question is cache hit
- different user cannot get cached private answer
- source update invalidates cache
- cached answer still passes safety/citation validation
- TTL expiry works
- metrics show hit/miss

Reject if:

- cache is global across users
- cache skips safety validation
- stale source answer is served
- cache stores sensitive data in key

---

# 15. Redis / Valkey Performance Cache

## Workflow position

```text
API Request → Rate Limit / Session / Feature Flag / Cache → Brain
```

## Required implementation

Use Redis/Valkey for:

- rate-limit counters
- refresh/session revocation cache where suitable
- feature flag cache
- semantic cache metadata where suitable
- short-lived retrieval cache
- expensive provider call guard

## Acceptance criteria

Accepted only if:

- Redis/Valkey runs locally and in deployment
- backend connects to it
- readiness checks it where required
- hit/miss is proven
- failure path is safe
- no sensitive raw data is stored
- Docker/Kubernetes include it

Reject if:

- dependency exists but is unused
- app crashes if cache down
- cache leaks user data
- no hit/miss proof exists

---

# 16. WASM Module

## Workflow position

```text
Brain → Deterministic Scoring/Validation → WASM → Result → Brain Trace
```

Suggested Sakina uses:

- Islamic safety risk scoring
- source trust scoring
- citation support scoring
- retrieval reranking helper
- prayer/time validation helper if applicable
- deterministic rule scoring

## Required implementation

WASM must:

- build from source
- be loaded by backend
- be invoked by real request
- have input/output schema
- handle bad input
- fallback safely if unavailable
- be built in Docker and CI

## Acceptance criteria

Accepted only if:

- real Sakina workflow invokes WASM
- output affects Brain decision
- bad input fails safely
- Docker and CI build it
- Kubernetes image includes it
- trace shows WASM stage

Reject if:

- WASM merely exists
- dependency is unused
- no route invokes it
- output does not affect workflow

---

# 17. MCP / Connector Layer

## Workflow position

```text
Brain → Tool Permission Check → Connector Call → Audit → Result → Validator
```

Possible connectors:

- Islamic source updater
- document/content storage if allowed
- calendar/reminder connector if enabled
- payment provider if enabled
- notification provider
- monitoring alerts

## Required implementation

Each connector must have:

- registry
- allowlist
- denylist
- user permission
- timeout
- rate limit
- audit log
- secret isolation
- failure handling

## Acceptance criteria

Accepted only if:

- Brain controls connector calls
- forbidden connectors are blocked
- user permission is checked
- timeout works
- failures are handled
- secrets are masked
- audit logs record calls

Reject if:

- connectors can be called directly
- no permission check
- secrets appear in logs
- connector is docs-only

---

# 18. Event Bus / Queue / Outbox

## Workflow position

```text
User Action → DB Transaction → Outbox Event → Worker → Status/Audit
```

Use for:

- source ingestion
- Qdrant reindexing
- evaluation jobs
- notifications
- audit processing
- payment webhook processing if enabled
- account deletion jobs
- human review queue jobs

## Required implementation

Outbox must include:

- event type
- payload schema
- status
- retry count
- dead-letter state
- idempotency key
- trace ID
- worker

## Acceptance criteria

Accepted only if:

- event is written
- worker processes it
- status changes from pending to processed
- failures retry
- max retry moves to dead-letter
- duplicate events are idempotent
- trace ID is preserved

Reject if:

- async is only a log message
- no worker exists
- status never changes
- retries are not tested

---

# 19. OpenTelemetry Observability

## Workflow position

```text
Frontend Request → Backend Trace → Brain Trace → DB/Qdrant/LLM Spans → Response
```

## Required implementation

Include:

- request ID
- trace ID
- structured logs
- metrics
- traces
- error logs
- DB spans
- Qdrant/vector spans
- LLM/provider spans
- cache spans
- no secret leakage
- Kubernetes logs

## Acceptance criteria

Accepted only if:

- same trace ID appears in response, logs, DB, and Brain trace
- metrics show real counters
- errors are logged safely
- readiness fails if critical dependency fails
- Kubernetes logs show runtime behaviour
- secrets are masked

Reject if:

- only logs exist
- metrics are static
- trace is not persisted
- secrets appear in logs

---

# 20. OWASP API Security Gate

## Workflow position

```text
CI/CD + Runtime Security Tests → API Guard → Deployment Gate
```

## Required implementation

Test for:

- broken object-level authorization
- broken authentication
- broken function-level authorization
- excessive data exposure
- unrestricted resource consumption
- mass assignment
- injection
- SSRF where relevant
- unsafe CORS
- missing rate limits

## Acceptance criteria

Accepted only if:

- protected endpoints reject unauthenticated access
- user A cannot access user B data
- admin/internal routes are protected
- invalid payloads are blocked
- rate limit works
- CORS is restricted
- CI blocks release on findings

Reject if:

- only happy paths are tested
- user isolation not tested
- CORS wildcard exists
- API security is not in CI

---

# 21. OWASP MASVS Mobile Security Gate

## Workflow position

```text
Mobile Build → MASVS Gate → Release APK/AAB Gate
```

## Required implementation

Check:

- secure token storage
- no hardcoded secrets
- no localhost in release
- TLS enforced
- debug disabled in release
- no sensitive logs
- permissions justified
- account deletion/privacy links
- release signing/build configuration

## Acceptance criteria

Accepted only if:

- release APK builds
- release AAB builds
- no static secrets/tokens exist
- secure storage is used
- release config uses real API
- permissions match enabled features
- sensitive logs are absent
- CI runs mobile gate

Reject if:

- debug APK only
- release points to localhost
- static token exists
- excessive permissions exist

---

# 22. SAST / SCA / Secret / Container Scanning

## Workflow position

```text
Code Commit → Static Scan → Dependency Scan → Secret Scan → Container Scan → CI Gate
```

## Required implementation

Add scans for:

- backend code
- Flutter code
- dependencies
- committed secrets
- Docker images
- Kubernetes manifests
- GitHub Actions workflow safety

## Acceptance criteria

Accepted only if:

- scans run in CI
- high/critical findings block release
- secrets fail the build
- container scan runs
- results are saved in evidence
- false positives are reviewed

Reject if:

- scans are optional
- findings do not block release
- secret scan is ignored
- no evidence files exist

---

# 23. Kubernetes Restricted / Admission Policy Gate

## Workflow position

```text
Kubernetes Manifest → Policy Check → Apply → Runtime Verification
```

## Required implementation

Enforce:

- non-root containers
- no privileged pods
- read-only root filesystem where possible
- resource requests/limits
- no hostPath unless justified
- secrets from Kubernetes secrets
- network policy where suitable
- liveness/readiness probes
- namespace isolation

## Acceptance criteria

Accepted only if:

- manifests pass restricted policy
- pods run non-root
- no privileged containers exist
- resource limits exist
- readiness/liveness probes exist
- secrets are not hardcoded
- policy check runs in CI
- live cluster proof exists

Reject if:

- cluster proof is missing
- privileged pods exist
- no limits
- no probes
- hardcoded secrets exist

---

# 24. Prompt Injection / Jailbreak Guard

## Workflow position

```text
User Input + Retrieved Sources → Injection Guard → Brain → LLM
```

## Required implementation

Detect:

- ignore previous instructions
- override system prompt
- malicious source text
- data exfiltration request
- tool abuse
- source manipulation
- citation manipulation
- attempts to bypass Islamic safety

## Acceptance criteria

Accepted only if:

- malicious user prompts are blocked
- malicious retrieved chunks are neutralised
- tool exfiltration is blocked
- safety bypass is blocked
- guard decision appears in trace
- CI runs injection tests

Reject if:

- guard is prompt-only
- malicious RAG-source test is missing
- unsafe prompt bypasses Brain
- no trace proof exists

---

# 25. PII Detection and Redaction

## Workflow position

```text
User Input / Profile / Memory / Logs → PII Detector → Redaction/Protection → Storage/Logs/AI
```

## Required implementation

Detect and protect:

- names
- addresses
- emails
- phone numbers
- family details
- medical information
- financial data
- sensitive religious/personal data
- case identifiers if any

## Acceptance criteria

Accepted only if:

- PII is detected
- logs redact sensitive data
- AI prompt minimises unnecessary PII
- audit stores only required data
- memory respects consent
- deletion works
- cross-user leakage tests fail closed

Reject if:

- PII appears in logs
- PII is sent to LLM unnecessarily
- deletion does not remove data
- no negative test exists

---

# 26. Data Retention and Account Deletion Engine

## Workflow position

```text
User Deletion Request → Auth Check → Outbox Job → Data Deletion → Audit → Confirmation
```

## Required implementation

Include:

- account deletion endpoint
- profile deletion/anonymisation
- memory deletion
- chat history deletion/anonymisation
- vector deletion/reindex if user data is embedded
- audit-safe deletion record
- retention policy
- frontend deletion UI
- job retry/dead-letter

## Acceptance criteria

Accepted only if:

- authenticated user can request deletion
- user A cannot delete user B data
- DB/vector data is deleted or anonymised
- frontend shows deletion state
- audit records deletion event
- negative tests pass

Reject if:

- deletion is frontend-only
- DB data remains
- vector data remains
- cross-user delete works

---

# 27. Backup and Disaster Recovery

## Workflow position

```text
Scheduled Backup → Restore Test → Verification Gate
```

## Required implementation

Back up:

- PostgreSQL
- Qdrant/vector DB
- source index
- key configuration
- uploaded files if used

## Acceptance criteria

Accepted only if:

- backup command exists
- restore command exists
- restore is tested into temporary environment
- restored DB passes core checks
- restored Qdrant returns results
- backup secrets are protected
- evidence is saved

Reject if:

- backup is only documented
- restore is not tested
- vector DB is not backed up
- restored app is not verified

---

# 28. Load Testing / Performance Budget

## Workflow position

```text
CI / Pre-release → Load Test → Performance Budget → Pass/Fail
```

## Required budgets

Define and enforce budgets, for example:

- health endpoint under 300 ms
- authenticated profile under 500 ms
- RAG retrieval under 2 seconds where provider allows
- Brain answer budget defined by provider/model
- p95 latency recorded
- error rate recorded

## Acceptance criteria

Accepted only if:

- load test script exists
- p50/p95 latency is recorded
- error rate is recorded
- DB and Qdrant latency measured
- performance budget enforced
- CI or release gate fails on regression

Reject if:

- only manual testing exists
- no p95
- no budget
- slow endpoint still passes

---

# 29. Canary / Feature Rollout

## Workflow position

```text
Feature Flag → Small User Group → Metrics → Expand / Roll Back
```

## Required implementation

Include:

- feature flag
- rollout percentage
- beta group
- kill switch
- metrics
- rollback plan

## Acceptance criteria

Accepted only if:

- feature can be enabled for beta users only
- disabled users cannot access direct API
- kill switch works
- rollout status is logged
- frontend respects flag
- backend enforces flag

Reject if:

- feature flag is frontend-only
- API bypass works
- rollback path is missing

---

# 30. Crash Reporting

## Workflow position

```text
Runtime Error → Crash/Error Reporter → Trace ID → Triage
```

## Required implementation

Include:

- Flutter crash capture
- backend error capture
- trace ID association
- no secret/PII leakage
- release mode enabled
- dashboard/export proof

## Acceptance criteria

Accepted only if:

- frontend crash is captured
- backend error is captured
- trace ID links to request
- PII/secrets are masked
- release mode works
- test crash proof exists

Reject if:

- debug-only crash reporting exists
- secrets appear in crash logs
- no trace ID exists

---

# 31. Cost Governor

## Workflow position

```text
Brain → Cost Governor → AI Router → Provider Call / Block / Cheaper Route
```

## Required implementation

Include:

- per-user quota
- per-feature budget
- per-provider cost estimate
- token counting
- expensive request approval/denial
- abuse detection
- cost metrics

## Acceptance criteria

Accepted only if:

- cost is estimated before provider call
- over-quota request is blocked or downgraded
- cheaper route is selected for simple task
- cost metrics are logged
- user isolation applies
- abuse test passes

Reject if:

- provider call happens before cost check
- no quota exists
- no metrics exist
- expensive loop can run unchecked

---

# 32. Human Review Queue

## Workflow position

```text
Brain Risk Classifier → High-Risk Flag → Human Review Queue / Caveated Response
```

## Queue high-risk items

- sensitive fatwa-like questions
- self-harm/crisis religious questions
- family/marriage harm risk
- sectarian conflict risk
- medical/legal/financial crossover
- low-confidence source result
- contradictory source result
- vulnerable user signal

## Acceptance criteria

Accepted only if:

- high-risk case creates review item or safe escalation state
- user gets safe caveated response
- queue stores minimised summary
- PII is minimised
- review status updates
- frontend shows review/escalation state where required
- direct bypass is blocked

Reject if:

- high-risk answer goes straight to final with no caveat
- queue is docs-only
- PII is overexposed
- no status tracking exists

---

# 33. Final Required Gates

Create or update these scripts:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/final-advanced-technologies-gate.sh
bash scripts/sakina/final-brain-workflow-gate.sh
bash scripts/sakina/final-security-performance-gate.sh
bash scripts/sakina/final-end-to-end-product-gate.sh
```

These gates must fail if any technology is not integrated into the full workflow.

The gates must not use:

```bash
|| true
echo PASS
continue-on-error
mock success
static proof
screenshot-only proof
```

Each gate must save evidence under:

```text
F:\SakinaAL\reports\final-hardening-evidence
```

WSL:

```text
/mnt/f/SakinaAL/reports/final-hardening-evidence
```

---

# 34. Required Final Report

Create:

```text
F:\SakinaAL\reports\sakina-advanced-technologies-end-to-end-signoff.md
```

The report must include:

- final verdict
- files changed
- commands run
- evidence files
- full workflow trace proof
- frontend/backend/DB proof
- Brain Mother Algorithm proof
- AIA/agent workflow proof
- RAG proof
- Graph RAG proof
- hybrid search proof
- Islamic source trust ranking proof
- citation/hallucination proof
- Islamic safety/policy-as-code proof
- AI router proof
- evaluation AI proof
- semantic cache proof
- Redis/Valkey proof
- WASM proof
- queue/outbox proof
- OpenTelemetry proof
- OWASP API proof
- MASVS/mobile proof
- SAST/SCA/secret/container scan proof
- Kubernetes restricted/admission policy proof
- prompt injection proof
- PII/redaction proof
- data deletion proof
- backup/restore proof
- load/performance proof
- canary/rollout proof
- crash reporting proof
- cost governor proof
- human review queue proof
- CI/CD proof
- Docker proof
- Kubernetes proof
- release APK/AAB proof
- remaining blockers if any

Final verdict can only be:

```text
READY — FULL SAKINA ADVANCED WORKFLOW END-TO-END PROVEN
```

if every gate passes.

If any gate fails, verdict must be:

```text
NOT READY — SAKINA ADVANCED TECHNOLOGY WORKFLOW NOT FULLY PROVEN
```

But this is not accepted as completion. Fix the blocker and rerun.

---

# 35. Final Acceptance Rule

The owner is not accepting failed, partial, blocked, local-only, mocked, documented-only, or isolated component success.

Final acceptance requires:

```text
frontend + backend + DB + Brain Mother Algorithm + AIA + RAG + Graph RAG + Hybrid Search + Islamic source trust + citation validation + hallucination guard + Islamic safety + WASM + cache + queues + observability + security + CI/CD + Docker + Kubernetes + release APK/AAB
```

working together as one system.

No isolated acceptance.

No fake proof.

No partial sign-off.

No blocked sign-off.

No local-only sign-off.

Only working end-to-end proof.
