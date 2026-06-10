# Sakina AI QA, Audit, Repair, and Wiring Order

Use this order inside:

```text
F:\sakinaal
```

or in WSL:

```bash
cd /mnt/f/sakinaal
```

## Operating Rule

Do a real QA audit first. Do not start by guessing. Do not create placeholder services. Do not claim PASS unless command output proves it.

Current accepted status:

```text
ASK AI SHAIKH CORE WORKFLOW: PROVEN IN TALOS STAGING
FULL SAKINA PRODUCT: PARTIAL
```

Your job is to audit, repair, and wire the remaining system until the distributed product workflow is real end to end.

## Strict Scope

Review and repair the full Sakina AI directory:

```text
F:\sakinaal
```

Include:

- backend
- mobile/frontend
- Ask AI Shaikh workflow
- Mother Algorithm / Brain
- rules engine
- RAG retrieval
- GraphRAG
- citation guard
- LLM gateway
- Ollama CPU inference
- scholar review
- auth/JWT
- user isolation
- workspace isolation
- learning/audit tables
- database migrations
- Kubernetes manifests
- GitHub Actions CI/CD
- tests and proof scripts

## Hard No-Fake Rules

- No fake PASS.
- No placeholder services.
- No mock APIs.
- No fake citations.
- No fake UUIDs.
- No external LLM.
- No direct frontend-to-Ollama calls.
- No direct backend-to-Ollama calls.
- No direct RAG-to-Ollama calls.
- No hardcoded secrets.
- No localhost dependency between Kubernetes pods.
- No closed-beta readiness claim unless every product gate passes.
- No full product readiness claim unless all workflows are proven end to end.

## Required Architecture

The real product workflow must be:

```text
mobile/frontend
  -> sakina-backend-api
  -> sakina-brain / Mother Algorithm
  -> sakina-rules-engine first
  -> sakina-rag-retrieval / GraphRAG second
  -> sakina-llm-gateway last resort only
  -> ollama-inference only through llm-gateway
  -> sakina-citation-guard before final answer
  -> audit/trace/learning DB
  -> final response to user
```

Only `sakina-llm-gateway` may call Ollama.

## Phase 1 - Full QA Audit Before Coding

Run a complete read-only audit first.

Report:

- current branch and commit
- exact files reviewed
- current services found
- current workflows found
- current Kubernetes manifests found
- current CI/CD workflows found
- real components
- fake/placeholder components
- broken or unused components
- direct Ollama access
- direct external LLM access
- missing health/ready endpoints
- missing JWT/workspace validation
- missing citation validation
- missing frontend/mobile wiring
- failing tests
- missing tests

Required commands:

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

find . -path "*/infra/*" -o -path "*/k8s/*" -o -path "*/.github/workflows/*" | sort
```

Do not code until this audit is complete.

## Phase 2 - Repair Distributed Services

Every service must be real and used by the working product workflow.

Required services:

1. `sakina-backend-api`
2. `sakina-brain`
3. `sakina-rules-engine`
4. `sakina-rag-retrieval`
5. `sakina-rag-ingestion`
6. `sakina-citation-guard`
7. `sakina-llm-gateway`
8. `sakina-crawler`
9. `sakina-document-service`
10. `sakina-worker`
11. `ollama-inference`
12. `sakina-postgres`
13. `sakina-redis` or approved queue

Each service must have:

- real entry point
- real route or worker function
- Dockerfile or proven image build path
- Kubernetes manifest
- `/health`
- `/ready`
- structured logs
- `trace_id` propagation
- environment from ConfigMap/Secret
- tests
- proof it is called by a real workflow, where applicable

Delete stale placeholder workloads only if they are not part of the real system. If they are needed, wire them properly.

## Phase 3 - LLM Gateway and Ollama Isolation

Repair the LLM path so:

- only `sakina-llm-gateway` has `OLLAMA_BASE_URL`
- only `sakina-llm-gateway` calls `ollama-inference`
- backend, brain, RAG, crawler, worker, frontend, and mobile do not call Ollama directly
- gateway rejects requests without `trace_id`
- gateway rejects requests without `workspace_id`
- gateway logs model, latency, route, token usage, `trace_id`, and `workspace_id`

Required proof:

```bash
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
Only sakina-llm-gateway may contain live Ollama endpoint config or direct Ollama call logic.
```

## Phase 4 - Brain / Mother Algorithm Wiring

Repair the Ask AI Shaikh workflow so `sakina-brain` controls the route decision.

Required route order:

1. validate JWT/auth context
2. enforce user/workspace isolation
3. de-identify PII
4. risk/safety classification
5. rules engine first
6. RAG/GraphRAG second
7. LLM gateway last resort only
8. citation guard before final response
9. save trace, audit, learning metadata
10. return final answer

Acceptance tests:

- deterministic wudu/salah answer uses rules/local DB and `llm_used=false`
- Arabic new Muslim answer returns Arabic with citation and `llm_used=false` if grounded
- controlled LLM path uses `llm_used=true` only after rules/RAG insufficient
- out-of-scope request blocked before LLM
- fabricated ritual fails closed
- high-risk fatwa escalates to scholar review and does not call LLM

## Phase 5 - Citation Guard

Repair citation validation so every final religious answer requiring citation is checked against approved local corpus/source registry.

Acceptance:

```text
valid local citation passes
fake citation fails
missing citation fails
unknown external source fails
final answer fails closed if citation guard fails
```

Required tests:

- `quran:5:6` valid
- `quran:2:286` valid
- fake UUID invalid
- missing citation invalid
- external unknown source invalid

## Phase 6 - Scholar Review Workflow

Prove scholar review is operational, not just a DB row.

Required:

- high-risk fatwa creates review row
- review row includes `trace_id`, `workspace_id`, user context, risk level, and status
- user receives safe pending response
- reviewer/admin path can list pending reviews
- reviewer/admin path can approve, reject, or keep pending
- user cannot access another user's review
- LLM never answers high-risk fatwa directly

## Phase 7 - Frontend/Mobile Wiring

The mobile/frontend must call only `sakina-backend-api`.

Required:

- real Ask AI Shaikh screen calls real backend endpoint
- no mobile/frontend direct Ollama call
- no mobile/frontend direct RAG call
- no mobile/frontend direct DB call
- frontend/mobile parses:
  - `trace_id`
  - `answer`
  - `citations`
  - `safety_state`
  - `source_path`
  - `llm_used`
  - `model_provider`
  - `llm_model`
  - blocked/fail-closed responses

Acceptance:

```text
real frontend/mobile request reaches backend-api
backend-api reaches brain
brain route decision is logged
final response is rendered correctly
```

## Phase 8 - Kubernetes Audit and Repair

Target namespace:

```text
sakina-mobile-staging
```

Required Kubernetes objects:

```text
Deployments:
sakina-backend-api
sakina-brain
sakina-rules-engine
sakina-rag-retrieval
sakina-rag-ingestion
sakina-citation-guard
sakina-llm-gateway
sakina-crawler or CronJob
sakina-document-service
sakina-worker

DaemonSet:
ollama-inference

StatefulSets:
sakina-postgres
sakina-redis
```

Every workload must include:

- readiness probe
- liveness probe
- resource requests
- resource limits
- labels: `app`, `component`, `part-of=sakina`
- no hardcoded secrets
- internal DNS service calls
- no pod-to-pod localhost calls

Required proof:

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

## Phase 9 - Ollama CPU Inference Fabric

Prove Ollama is actually running and usable from inside the cluster.

Required:

- `ollama-inference` DaemonSet exists
- pods are running
- service endpoints exist
- model exists on every pod
- generation works from inside cluster
- only LLM gateway calls it

Required proof:

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

## Phase 10 - Database Proof

Prove DB tables support real workflow.

Required DB proof:

- users exist
- workspaces exist
- traces exist
- Ask AI trace belongs to correct user/workspace
- citations exist in local approved corpus/source registry
- learning metadata is anonymized
- raw PII is not saved
- scholar review row exists for high-risk question
- User B cannot read User A trace/review/document/learning row

Required output:

```text
SQL query
SQL result
PASS/FAIL decision
```

No DB proof by summary only.

## Phase 11 - CI/CD Gates

Repair GitHub Actions so the workflow fails when the product is unsafe.

CI must fail if:

- tests fail
- placeholder services exist
- direct Ollama access exists outside `sakina-llm-gateway`
- missing `trace_id` is accepted
- missing `workspace_id` is accepted
- fake citation is accepted
- missing citation is accepted when required
- high-risk fatwa reaches LLM
- frontend/mobile calls Ollama directly
- Kubernetes manifests use wrong service names
- large binaries, secrets, model files, `.local-bin`, `node_modules`, build caches, or `.env` are committed

Required proof:

- GitHub Actions run ID
- workflow conclusion
- exact failing/passing gate output
- image tags deployed
- rollout proof

## Phase 12 - Final Product Workflow Proof

Run the full Ask AI Shaikh workflow end to end.

Required test cases:

1. Register User A.
2. Register User B.
3. User A asks wudu question.
4. Prove DB/rules/RAG path with `llm_used=false`.
5. User A asks Arabic new Muslim question.
6. Prove Arabic answer with valid citation.
7. User A asks ambiguous allowed question.
8. Prove controlled LLM path with gateway trace.
9. User A asks out-of-scope question.
10. Prove block before LLM.
11. User A submits PII.
12. Prove redaction and anonymous-only learning.
13. User A asks high-risk fatwa.
14. Prove scholar review row and no LLM answer.
15. User A asks fabricated ritual.
16. Prove fail-closed.
17. User B tries to access User A trace.
18. Prove 403/404.
19. User B tries to access User A scholar review.
20. Prove 403/404.
21. Frontend/mobile renders the result correctly.

## Final Report Format

Return exactly this checkpoint report:

```text
SAKINA AI QA/AUDIT/REPAIR CHECKPOINT

Branch:
Commit:
GitHub Actions run:
Workflow conclusion:
Talos context:

Files reviewed:
Files changed:

Services found:
Services repaired:
Services deleted:
Services still missing:

Kubernetes proof:
[paste exact kubectl output]

Ollama proof:
[paste exact command output]

LLM isolation proof:
[paste exact grep/test output]

Ask AI Shaikh workflow proof:
[paste exact command/test output]

Frontend/mobile proof:
[paste exact test/output]

Citation proof:
[paste exact DB/test output]

Scholar review proof:
[paste exact DB/API/test output]

Workspace isolation proof:
[paste exact output]

CI/CD proof:
[paste exact output]

Remaining blockers:
[list exact blockers only]

Final decision:
ASK AI SHAIKH CORE WORKFLOW:
DISTRIBUTED SERVICES:
OLLAMA FABRIC:
FRONTEND/MOBILE:
SCHOLAR REVIEW:
FULL PRODUCT READINESS:
```

Allowed final decisions:

```text
PASS
PARTIAL
FAIL
BLOCKED
```

Do not use any other wording.

## Acceptance

The checkpoint can only pass if:

- Ask AI Shaikh works end to end from frontend/mobile to backend to brain
- LLM is last resort only
- only LLM gateway can call Ollama
- citations are validated before final answer
- fake/missing citations fail
- high-risk fatwa escalates to scholar review
- PII is redacted and not saved raw
- User B cannot access User A data
- Kubernetes workloads are healthy
- CI/CD passes with hard safety gates

If any item is missing, final status must be:

```text
PARTIAL
```

not PASS.
