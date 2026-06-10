# Gemini Order: Sakina AI QA, Backend Repair, Wiring, Then Go Live

Project directory:

```text
F:\sakinaal
```

WSL path:

```bash
cd /mnt/f/sakinaal
```

Primary control file to follow:

```text
sakina-ai-qa-audit-repair-wire-order.md
```

## Important Rule

Do not start "go live" work until the QA audit, backend repair, backend wiring, Kubernetes proof, Ollama proof, LLM isolation proof, citation proof, and frontend/mobile Ask AI Shaikh workflow proof have passed.

The work must happen in two stages:

```text
Stage 1: QA audit, repair backend, wire services, prove product workflow.
Stage 2: Finish Sakina, production hardening, and go-live readiness.
```

No fake PASS.
No placeholder services.
No mock-only proof.
No full readiness claim without command output.

## Current Accepted Status

Treat the current status as:

```text
ASK AI SHAIKH CORE WORKFLOW: PROVEN IN TALOS STAGING
FULL SAKINA PRODUCT READINESS: PARTIAL
```

Do not downgrade the proven checkpoint.
Do not overclaim beyond it.

## Stage 1 - QA, Repair Backend, And Wire Everything

First, open and follow:

```text
F:\sakinaal\sakina-ai-qa-audit-repair-wire-order.md
```

If the file is not in the repo root, search for it and use the latest version.

Required Stage 1 work:

1. Audit the full Sakina codebase before coding.
2. Find fake, mock, placeholder, stub, unused, or broken services.
3. Find direct Ollama calls outside the LLM gateway.
4. Find external LLM usage.
5. Find backend endpoints not wired to real services.
6. Find frontend/mobile routes not wired to the backend.
7. Find Kubernetes workloads that are stale, placeholder, unhealthy, or unused.
8. Repair the backend.
9. Wire backend API to the Brain / Mother Algorithm.
10. Wire Brain to rules engine first.
11. Wire Brain to RAG / GraphRAG second.
12. Wire Brain to LLM gateway last resort only.
13. Wire LLM gateway to Ollama only.
14. Wire citation guard before final answer.
15. Wire scholar review for high-risk fatwa.
16. Wire audit, trace, learning, PII redaction, user isolation, and workspace isolation.
17. Wire mobile/frontend Ask AI Shaikh to the real backend API.
18. Repair tests and proof scripts.
19. Repair Kubernetes manifests.
20. Repair GitHub Actions gates.

Required Stage 1 architecture:

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

Strict rules:

- Mobile/frontend must call only `sakina-backend-api`.
- Backend API must call `sakina-brain` for Ask AI Shaikh.
- Brain must control the route decision.
- Rules engine must run before RAG.
- RAG/GraphRAG must run before LLM.
- LLM gateway must be last resort only.
- Only LLM gateway may call Ollama.
- Citation guard must validate before final answer.
- High-risk fatwa must go to scholar review.
- Out-of-scope requests must block before LLM.
- Fabricated religious claims must fail closed.
- PII must be redacted before LLM and before learning.
- User/workspace isolation must be enforced on every user data path.

## Stage 1 Required Commands

Run first:

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
```

Then run Kubernetes proof:

```bash
kubectl -n sakina-mobile-staging get deploy,ds,sts,pods,svc -o wide
kubectl -n sakina-mobile-staging get endpoints -o wide
kubectl -n sakina-mobile-staging get events --sort-by=.lastTimestamp | tail -100
```

Then prove Ollama:

```bash
kubectl -n sakina-mobile-staging get ds ollama-inference -o wide
kubectl -n sakina-mobile-staging get pods -l app=ollama-inference -o wide
kubectl -n sakina-mobile-staging get svc,endpoints ollama-inference -o wide
```

Then prove only the LLM gateway can call Ollama:

```bash
grep -RIn "OLLAMA_BASE_URL\|ollama-inference\|11434" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.dart_tool \
  --exclude-dir=.gradle
```

## Stage 1 Acceptance Gates

Stage 1 is complete only when all are proven:

- backend API works
- backend API is wired to Brain
- Brain is the only workflow controller
- rules-first path works
- RAG/GraphRAG-second path works
- LLM gateway last-resort path works
- only LLM gateway calls Ollama
- citations are validated
- fake citation fails
- missing citation fails
- high-risk fatwa creates scholar review
- PII redaction works
- anonymous learning metadata works
- User B cannot access User A trace/review/document/learning rows
- frontend/mobile Ask AI Shaikh calls the real backend
- Kubernetes workloads are healthy
- CI/CD passes

If any gate fails, do not start Stage 2.

Stage 1 final decision must be one of:

```text
PASS
PARTIAL
FAIL
BLOCKED
```

## Stage 2 - Finish Sakina And Prepare Go Live

Start Stage 2 only after Stage 1 is PASS.

Goal:

```text
Finish Sakina AI and prepare it for controlled go-live.
```

Stage 2 required work:

1. Finish all remaining user-facing mobile/frontend screens.
2. Finish Ask AI Shaikh UI states:
   - normal answer
   - Arabic answer
   - blocked answer
   - fail-closed answer
   - scholar review pending
   - network error
   - auth expired
3. Finish scholar review admin/reviewer workflow.
4. Finish user account/auth flow.
5. Finish onboarding for new Muslims.
6. Finish safe Islamic content browsing.
7. Finish citation display and source explanation.
8. Finish privacy/consent screens.
9. Finish error handling and support contact path.
10. Finish monitoring and alerting.
11. Finish backup/restore proof.
12. Finish security hardening.
13. Finish rate limiting and abuse protection.
14. Finish performance/load test.
15. Finish deployment rollback plan.
16. Finish production environment config.
17. Finish go-live checklist.

## Stage 2 Production Gates

Do not claim go-live readiness unless these pass:

- all critical tests pass
- no fake/mock/placeholder product path
- no external LLM
- no direct Ollama access outside gateway
- auth and workspace isolation pass
- citation guard pass
- scholar review pass
- PII redaction pass
- Kubernetes rollout pass
- monitoring available
- logs include trace IDs
- backup and restore tested
- rollback tested
- secrets are not in repo
- CI/CD is green
- mobile/frontend core flows proven

## Final Go-Live Report Required

Return:

```text
SAKINA AI GO-LIVE READINESS CHECKPOINT

Branch:
Commit:
GitHub Actions run:
Workflow conclusion:
Talos context:

Stage 1 result:
Stage 2 result:

Backend status:
Brain status:
Rules status:
RAG/GraphRAG status:
Citation guard status:
LLM gateway status:
Ollama fabric status:
Scholar review status:
Frontend/mobile status:
Auth/isolation status:
Monitoring status:
Backup/restore status:
Security status:
Performance status:
Rollback status:

Exact test output:
[paste output]

Exact Kubernetes output:
[paste output]

Exact CI/CD output:
[paste output]

Remaining blockers:
[list exact blockers]

Final decision:
ASK AI SHAIKH CORE WORKFLOW: PASS/PARTIAL/FAIL/BLOCKED
DISTRIBUTED SERVICES: PASS/PARTIAL/FAIL/BLOCKED
FRONTEND/MOBILE: PASS/PARTIAL/FAIL/BLOCKED
SCHOLAR REVIEW: PASS/PARTIAL/FAIL/BLOCKED
SECURITY: PASS/PARTIAL/FAIL/BLOCKED
GO-LIVE READINESS: PASS/PARTIAL/FAIL/BLOCKED
```

Only use `GO-LIVE READINESS: PASS` if every required gate has command output proof.

If anything important remains incomplete, use:

```text
GO-LIVE READINESS: PARTIAL
```

## Final Instruction

First execute:

```text
sakina-ai-qa-audit-repair-wire-order.md
```

Then repair and wire the backend.

Then prove the full Ask AI Shaikh product workflow.

Only after that, start finishing Sakina and preparing go-live.

No fake PASS. No shortcuts. No production claim without proof.
