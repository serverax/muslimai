# Sakina AI Detailed Handoff

Project directory:

```text
F:\sakinaal
```

WSL path:

```bash
/mnt/f/sakinaal
```

Working branch from latest checkpoint:

```text
qa-security-hardening
```

Latest proven commit from checkpoint:

```text
ba3903df2c8ab02003bdae32cd624c0bb828af35
```

Latest GitHub Actions run from checkpoint:

```text
27068987009
```

Workflow:

```text
Sakina Deploy
```

Latest reported workflow conclusion:

```text
success
```

Talos context used by CI:

```text
admin@ordinox-talos
```

## Current Honest Status

Accepted checkpoint:

```text
ASK AI SHAIKH CORE WORKFLOW: PROVEN IN TALOS STAGING
FULL SAKINA PRODUCT READINESS: PARTIAL
```

Do not claim:

```text
closed beta ready
full product ready
all distributed services ready
all frontend/mobile workflows ready
full scholar workflow ready
full ingestion/crawler ready
full security ready
```

unless each is proven by command output.

## What Has Been Proven

The latest checkpoint proves the core Ask AI Shaikh product workflow in Talos staging.

Proven items:

- GitHub Actions deployment completed successfully.
- Staging rollout/pod health passed.
- No unhealthy staging pods were detected by the deployment gate.
- LLM gateway readiness passed.
- LLM gateway rejected a request missing `trace_id` with HTTP 400.
- User A and User B registration worked through the live backend.
- User A and User B both received access and refresh tokens.
- DB-first wudu path returned a real trace.
- DB-first path checked local DB, RAG, and GraphRAG.
- DB-first path returned `llm_used=false`.
- DB-first answer cited `quran:5:6`.
- Arabic New Muslim flow returned Arabic answer.
- Arabic answer cited `quran:2:286`.
- Controlled LLM path returned `llm_used=true`.
- Controlled LLM path used `model_provider=ollama`.
- Controlled LLM path used `llm_model=qwen2.5:3b`.
- Controlled LLM path returned `safety_state=ALLOWED_WITH_GUARDRAILS`.
- Gateway logs proved same `trace_id` reached the LLM gateway.
- Gateway logs included `workspace_id`, route, model, and token usage.
- Out-of-scope request blocked before LLM.
- PII redaction stored redacted text only.
- Learning metadata recorded anonymous-only learning.
- Raw user message was not saved.
- High-risk fatwa escalated to scholar review.
- High-risk fatwa did not call LLM.
- Scholar review DB row was created with pending/high state.
- Fabricated ritual failed closed.
- User B could not access User A trace and received HTTP 404.
- Frontend API service includes `askSakina`.
- Frontend parser handles safety state, source path, citations, provider, model, and blocked responses.
- Frontend parser tests cover citations, source path, safety state, and blocked response parsing.

## Key Trace Proof From Latest Checkpoint

DB-first wudu trace:

```text
trace_id: 12ec7b11-9d42-47ea-b1eb-63d4b27ae97f
source_path.local_db_checked=true
rag_checked=true
graph_rag_checked=true
llm_used=false
citation=quran:5:6
```

Controlled LLM trace:

```text
trace_id: fe587b61-0f93-4dcf-b931-386bf55459c0
answer_source=llm_generation_with_controlled_context
rag_checked=true
graph_rag_checked=true
llm_used=true
model_provider=ollama
llm_model=qwen2.5:3b
safety_state=ALLOWED_WITH_GUARDRAILS
```

Gateway log proof:

```text
trace_id=fe587b61-0f93-4dcf-b931-386bf55459c0
workspace_id=2477556a-2cd8-441e-a03e-eddfae363a1c
route=generate
model=qwen2.5:3b
token usage logged
```

High-risk fatwa proof:

```text
safety_state=ESCALATED_TO_HUMAN
answer_source=scholar_review_required
llm_used=false
scholar review DB row=pending | high | Sakina ask high-risk fatwa escalation
```

PII proof:

```text
stored text: my name is [REDACTED_NAME] and i live at [REDACTED_ADDRESS]...
anonymous_only=true
model_learning=false
private_memory=false
raw_user_message_saved=false
```

## Main Risk Now

The core workflow is proven, but the system may still have:

- stale placeholder distributed-service workloads
- services that exist in manifests but are not wired into the real workflow
- services with `/health` but no real business route
- CI cleanup hiding stale workloads instead of repairing them
- partial frontend/mobile proof only through parser tests
- limited scholar-review workflow proof
- incomplete queue/worker proof
- incomplete crawler/ingestion proof
- incomplete full distributed service proof
- incomplete full security proof
- incomplete performance/load proof

The next work must prove the architecture is real, not just that the main happy path works.

## Immediate Priority

Next checkpoint name:

```text
SAKINA DISTRIBUTED SERVICES + OLLAMA FABRIC CHECKPOINT
```

Goal:

```text
Prove every required service is real, deployed, reachable, and wired into a real product workflow.
```

Do not start a large rewrite. Audit first, then repair in controlled order.

## Required Target Runtime Design

The real product route must be:

```text
mobile/frontend
  -> sakina-backend-api
  -> sakina-brain
  -> sakina-rules-engine
  -> sakina-rag-retrieval / GraphRAG
  -> sakina-llm-gateway
  -> ollama-inference
  -> sakina-citation-guard
  -> audit/trace/learning DB
  -> final response
```

Rules:

- Mobile/frontend calls only `sakina-backend-api`.
- Backend API calls `sakina-brain` for Ask AI Shaikh.
- Brain controls the route decision.
- Rules engine is checked first.
- RAG/GraphRAG is checked second.
- LLM gateway is called last resort only.
- Only LLM gateway may call Ollama.
- Citation guard validates before final response.
- High-risk fatwa must go to scholar review.
- Out-of-scope must block before LLM.
- Fabricated religious claims must fail closed.
- PII must be redacted before LLM and before learning.
- User/workspace isolation must be enforced on every user data path.

## Required Services

The project must end with these real services or a documented reason why a service is intentionally deferred.

```text
sakina-backend-api
sakina-brain
sakina-rules-engine
sakina-rag-retrieval
sakina-rag-ingestion
sakina-citation-guard
sakina-llm-gateway
sakina-crawler
sakina-document-service
sakina-worker
ollama-inference
sakina-postgres
sakina-redis or approved queue
```

Every real service must have:

- real entry point
- Dockerfile or proven image build path
- Kubernetes workload
- Kubernetes Service where needed
- `/health`
- `/ready`
- structured logs
- `trace_id` propagation
- resource requests and limits
- readiness/liveness probes
- ConfigMap/Secret based config
- tests
- workflow proof if user-facing or workflow-facing

## Work Order For Claude Code

Paste this into Claude Code:

```text
You are working in F:\sakinaal.

Do not claim full product readiness.
Current accepted status is:
ASK AI SHAIKH CORE WORKFLOW PROVEN IN TALOS STAGING.
FULL PRODUCT READINESS IS PARTIAL.

Your task is to produce the next checkpoint:
SAKINA DISTRIBUTED SERVICES + OLLAMA FABRIC CHECKPOINT.

First, perform a full QA audit. Do not code until the audit is complete.

Audit:
1. Map all backend services.
2. Map all frontend/mobile calls.
3. Map all Ask AI Shaikh routes.
4. Map all Kubernetes manifests.
5. Map all GitHub Actions workflows.
6. Map all DB migrations/tables used by Ask AI Shaikh.
7. Find all placeholder/fake/stub/mock code.
8. Find all direct Ollama access.
9. Find all external LLM access.
10. Find all services that have health endpoints but no real workflow.
11. Find all services deployed in Kubernetes but not wired into the product.
12. Find all tests that only test mocks instead of real workflow.

After the audit, repair in this order:

Phase 1:
Remove or properly wire stale placeholder distributed workloads.
Do not only clean them up in CI. If a service is required, make it real. If it is not required, remove it from repo and cluster manifests.

Phase 2:
Prove Ollama CPU inference fabric.
Ollama must run as ollama-inference.
Only sakina-llm-gateway may call Ollama.
No backend, brain, RAG, worker, frontend, or mobile direct Ollama calls.

Phase 3:
Repair sakina-llm-gateway.
It must require trace_id and workspace_id.
It must log trace_id, workspace_id, route, model, latency, and token usage where available.
It must expose /health, /ready, and generate route.

Phase 4:
Repair sakina-brain as the only Mother Algorithm controller.
Backend API must call brain for Ask AI Shaikh.
Brain must call rules first, RAG/GraphRAG second, LLM gateway last resort only, then citation guard.

Phase 5:
Repair citation guard.
Fake citation must fail.
Missing citation must fail.
Unknown external source must fail.
Valid local Quran/Hadith/source citation must pass.
No answer requiring citation may return if citation guard fails.

Phase 6:
Repair scholar review.
High-risk fatwa must create a scholar review row.
Reviewer/admin path must list pending review.
Reviewer/admin path must approve, reject, or keep pending.
User must receive safe pending response.
LLM must not answer high-risk fatwa.

Phase 7:
Prove frontend/mobile live Ask AI Shaikh call.
Parser tests are not enough.
Prove a real mobile/frontend call reaches backend, brain, rules/RAG/LLM gateway if needed, citation guard, and final response.

Phase 8:
Repair Kubernetes manifests.
Every workload must have probes, resources, services where needed, labels, config, and no hardcoded secrets.

Phase 9:
Repair CI/CD gates.
CI must fail on placeholders, direct Ollama access outside gateway, fake citation acceptance, missing trace_id acceptance, missing workspace isolation, and failing tests.

Phase 10:
Run full proof tests and report exact output.

No fake PASS.
No placeholder services.
No mock-only proof.
No summaries without command output.
No closed-beta claim.
No full product readiness claim unless every gate passes.
```

## Commands Claude Must Run First

```bash
cd /mnt/f/sakinaal

git status --short
git branch --show-current
git rev-parse HEAD

find . -maxdepth 4 -type f | sort > /tmp/sakina-files.txt

grep -RIn "TODO\|FIXME\|placeholder\|mock\|fake\|stub\|not implemented\|coming soon" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.dart_tool \
  --exclude-dir=.gradle \
  || true

grep -RIn "OPENAI\|ANTHROPIC\|GEMINI\|MISTRAL\|DEEPSEEK\|openrouter\|api.openai\|api.anthropic\|OLLAMA_BASE_URL\|ollama\|11434" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.dart_tool \
  --exclude-dir=.gradle \
  || true

find . \( -path "*/infra/*" -o -path "*/k8s/*" -o -path "*/.github/workflows/*" -o -path "*/scripts/proof/*" \) -type f | sort
```

## Kubernetes Proof Required

Namespace:

```text
sakina-mobile-staging
```

Commands:

```bash
kubectl -n sakina-mobile-staging get deploy,ds,sts,pods,svc -o wide
kubectl -n sakina-mobile-staging get endpoints -o wide
kubectl -n sakina-mobile-staging get events --sort-by=.lastTimestamp | tail -100

kubectl -n sakina-mobile-staging rollout status deploy/sakina-backend-api --timeout=10m
kubectl -n sakina-mobile-staging rollout status deploy/sakina-brain --timeout=10m
kubectl -n sakina-mobile-staging rollout status deploy/sakina-rules-engine --timeout=10m
kubectl -n sakina-mobile-staging rollout status deploy/sakina-rag-retrieval --timeout=10m
kubectl -n sakina-mobile-staging rollout status deploy/sakina-citation-guard --timeout=10m
kubectl -n sakina-mobile-staging rollout status deploy/sakina-llm-gateway --timeout=10m
kubectl -n sakina-mobile-staging rollout status ds/ollama-inference --timeout=10m
```

If any deployment does not exist, report:

```text
MISSING WORKLOAD: <name>
```

Do not hide missing workloads.

## Ollama Fabric Proof Required

```bash
kubectl -n sakina-mobile-staging get ds ollama-inference -o wide
kubectl -n sakina-mobile-staging get pods -l app=ollama-inference -o wide
kubectl -n sakina-mobile-staging get svc,endpoints ollama-inference -o wide

for pod in $(kubectl -n sakina-mobile-staging get pods -l app=ollama-inference -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  echo "===== $pod ====="
  kubectl -n sakina-mobile-staging exec "$pod" -- ollama list
done

kubectl -n sakina-mobile-staging run ollama-proof \
  --rm -i \
  --restart=Never \
  --image=curlimages/curl:latest \
  -- sh -c '
    curl -s http://ollama-inference:11434/api/tags;
    echo;
    curl -s http://ollama-inference:11434/api/generate \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"qwen2.5:3b\",\"stream\":false,\"prompt\":\"Return JSON only: {\\\"status\\\":\\\"ok\\\"}\"}";
    echo
  '
```

Acceptance:

```text
ollama-inference exists
pods running
service endpoints exist
model available
generation works
only llm-gateway can call Ollama
```

## LLM Isolation Proof Required

```bash
cd /mnt/f/sakinaal

grep -RIn "OLLAMA_BASE_URL\|ollama-inference\|11434" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.dart_tool \
  --exclude-dir=.gradle
```

Acceptance:

```text
Only sakina-llm-gateway may contain live Ollama endpoint config or direct Ollama call code.
```

## Ask AI Shaikh Proof Required

Run proof for these cases:

1. Wudu deterministic local DB/rules answer.
2. Arabic New Muslim answer.
3. Controlled LLM allowed answer.
4. Out-of-scope blocked answer.
5. PII redaction answer.
6. High-risk fatwa scholar review answer.
7. Fabricated ritual fail-closed answer.
8. User B cannot access User A trace.
9. User B cannot access User A scholar review.
10. User B cannot access User A learning/audit rows.

Each proof must show:

```text
HTTP status
trace_id
workspace_id
answer_source
safety_state
source_path
citations
llm_used
model_provider if used
llm_model if used
DB row proof where relevant
```

## Citation Proof Required

Required cases:

```text
valid quran:5:6 passes
valid quran:2:286 passes
fake UUID fails
missing citation fails
unknown external citation fails
final answer blocked when citation guard fails
```

Every proof must include:

```text
test command
actual output
PASS/FAIL decision
```

## Scholar Review Proof Required

Required cases:

```text
high-risk fatwa creates scholar review row
review row contains trace_id and workspace_id
review row has status pending
review row has risk high
reviewer/admin can list pending reviews
reviewer/admin can approve/reject/keep pending
User B cannot access User A review
LLM not called
```

## Frontend/Mobile Proof Required

Parser tests are useful but not enough.

Required:

```text
real mobile/frontend Ask AI Shaikh request
request reaches backend API
backend API reaches brain
brain logs route decision
rules/RAG/LLM/citation route is visible
response renders in UI layer
blocked response renders safely
Arabic answer renders correctly
citations render correctly
```

## Database Proof Required

Show SQL proof for:

- users
- workspaces
- traces
- citations/source registry
- scholar review
- learning metadata
- PII redaction
- audit logs
- user isolation
- workspace isolation

Output format:

```text
SQL:
<query>

Result:
<actual result>

Decision:
PASS/PARTIAL/FAIL
```

## CI/CD Proof Required

Required:

- workflow run ID
- workflow conclusion
- image tags built
- image tags deployed
- tests passed
- safety gates passed
- deployment gate passed

CI must fail if:

- placeholder services are present
- direct Ollama access exists outside LLM gateway
- fake citation is accepted
- missing citation is accepted
- missing `trace_id` is accepted
- missing `workspace_id` is accepted
- high-risk fatwa reaches LLM
- frontend/mobile calls Ollama directly
- tests fail
- secrets or large binaries are committed

## Final Checkpoint Format

Claude must return:

```text
SAKINA DISTRIBUTED SERVICES + OLLAMA FABRIC CHECKPOINT

Branch:
Commit:
GitHub Actions run:
Workflow conclusion:
Talos context:

Files reviewed:
Files changed:

Audit findings:
- Real components:
- Placeholder/fake components:
- Broken wiring:
- Direct Ollama/external LLM findings:
- Missing tests:

Services:
- backend-api:
- brain:
- rules-engine:
- rag-retrieval:
- rag-ingestion:
- citation-guard:
- llm-gateway:
- crawler:
- document-service:
- worker:
- ollama-inference:
- postgres:
- redis/queue:

Kubernetes proof:
[exact output]

Ollama proof:
[exact output]

LLM isolation proof:
[exact output]

Ask AI Shaikh proof:
[exact output]

Frontend/mobile proof:
[exact output]

Citation proof:
[exact output]

Scholar review proof:
[exact output]

Workspace/user isolation proof:
[exact output]

CI/CD proof:
[exact output]

Remaining blockers:
[exact blockers]

Final decision:
ASK AI SHAIKH CORE WORKFLOW: PASS/PARTIAL/FAIL/BLOCKED
DISTRIBUTED SERVICES: PASS/PARTIAL/FAIL/BLOCKED
OLLAMA FABRIC: PASS/PARTIAL/FAIL/BLOCKED
FRONTEND/MOBILE: PASS/PARTIAL/FAIL/BLOCKED
SCHOLAR REVIEW: PASS/PARTIAL/FAIL/BLOCKED
CITATION GUARD: PASS/PARTIAL/FAIL/BLOCKED
WORKSPACE ISOLATION: PASS/PARTIAL/FAIL/BLOCKED
FULL PRODUCT READINESS: PASS/PARTIAL/FAIL/BLOCKED
```

## Acceptance Decision Rules

Use:

```text
PASS
```

only if command output proves the item works end to end.

Use:

```text
PARTIAL
```

if the item is implemented but not fully proven, or only parser/unit tests exist.

Use:

```text
FAIL
```

if the item is broken, unsafe, or missing.

Use:

```text
BLOCKED
```

only if an external blocker prevents proof, such as missing cluster access, missing secret, or failed registry access.

## Most Important Next Instruction

Do not improve random features first.

First prove:

```text
distributed services are real
Ollama fabric works
only LLM gateway reaches Ollama
brain controls the workflow
citation guard blocks bad output
frontend/mobile live call works
scholar review workflow is usable
workspace isolation is enforced everywhere
```

Until those are proven, final status remains:

```text
FULL PRODUCT READINESS: PARTIAL
```
