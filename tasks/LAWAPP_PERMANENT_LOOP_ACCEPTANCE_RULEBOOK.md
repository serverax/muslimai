# LAWAPP — PERMANENT LOOP ACCEPTANCE RULEBOOK
## Zero Partial, Zero Mock-Only, Full End-to-End Integration Required

**File name:** `LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md`  
**Project root:** `F:\lawapp`  
**Required location:** `F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md`  
**Applies to:** Every Claude Code task, every fix, every feature, every report, every audit, every CI/CD/deployment claim  
**Priority:** Highest. This overrides any weaker instruction, previous report, task note, acceptance summary, or local demo claim.

---

# 0. OWNER POSITION — NO NEGOTIATION

The owner does **not** accept:

- failed work,
- blocked work,
- partial work,
- isolated technology work,
- mock-only work,
- stub-only work,
- frontend-only work,
- backend-only work,
- DB-only work,
- script-only work,
- local-only work presented as full completion,
- “it works in a unit test” as acceptance,
- “the route exists” as acceptance,
- “the table exists” as acceptance,
- “the technology was added” as acceptance,
- “the feature is structurally ready” as acceptance,
- “waiting for later phase” unless it is explicitly excluded from the current acceptance claim,
- “blocked” unless the blocker is external, proven, and all code-side work is complete.

**Acceptance means the complete lawapp system works together end to end.**

A feature is accepted only when the real integrated chain works:

```text
Frontend UI
→ Backend API
→ Authentication and ownership
→ Database tables, functions, migrations, indexes
→ Deterministic rules engine
→ Official-source ingestion
→ Hybrid RAG
→ Graph RAG where applicable
→ Algorithm brain
→ Responsible AIA governance
→ WASM/JS where applicable
→ Security and data protection controls
→ Audit logs and trace rows
→ User-facing result with citations
→ End-to-end tests
→ CI/CD gates
→ Kubernetes proof if staging is claimed
```

If any link in that chain is missing, the feature is **NOT ACCEPTED**.

---

# 1. PERMANENT LOOP RULE

Claude must apply this loop for **every single task**.

## 1.1 Before starting any task

Claude must read this file first:

```text
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md
```

Then Claude must state internally and obey:

```text
No isolated PASS.
No mock-only PASS.
No partial PASS.
No blocked PASS.
Only integrated end-to-end proof counts.
```

## 1.2 During the task

For every file changed, Claude must ask:

```text
Does this connect to frontend?
Does this connect to backend?
Does this connect to DB?
Does this connect to rules/RAG/algorithm/AIA if relevant?
Does this connect to WASM if relevant?
Does this enforce auth/security?
Does this write audit proof?
Does this have tests?
Does this work after clean Docker rebuild?
```

If the answer is no, Claude must continue working.

## 1.3 Before reporting completion

Claude must re-read this file and verify:

```text
Did I prove the full integrated chain?
Did I avoid mocks/stubs in the acceptance path?
Did I run the required command gate?
Did I include raw command output?
Did I clearly state any remaining external blocker?
Did I avoid false “ready/complete/done” language?
```

If not, Claude must not report completion.

## 1.4 After any failed command

Claude must not stop at failure.

Claude must:

1. identify the root cause,
2. fix the code/config/test/data issue,
3. rerun the failed command,
4. rerun any dependent commands,
5. update the report only after the rerun passes.

A failed command is not a final answer.

---

# 2. HARD DEFINITIONS

## 2.1 “Feature exists” is not accepted

A feature exists when code is present.

That is not acceptance.

## 2.2 “Feature works alone” is not accepted

A feature working through a direct function call or mock test is not acceptance.

## 2.3 “Feature accepted” means full integration

A feature is accepted only when:

```text
User can trigger it from the real UI
Frontend calls the real backend route
Backend uses real DB state
DB has migration from clean start
Rules/RAG/algorithm/AIA are connected where needed
WASM is connected where needed
Security/ownership is enforced
Audit rows are written
Citations are returned where legal content exists
Tests prove success and failure paths
Clean Docker rebuild still passes
```

## 2.4 “Blocked” is not accepted

A blocker may be recorded only if:

```text
It is outside Claude’s control
The code-side fallback is implemented
The system fails closed
The UI shows a clear state
The DB logs the blocker
The tests prove the blocker path
The report gives exact rerun commands
```

Example acceptable external blockers:

```text
Real Stripe keys not supplied
Real Anthropic key not supplied
Find Case Law computational-analysis licence not granted
Kubernetes kubeconfig not available
External official API outage
```

But even then, Claude must build the code path, validation, fail-closed behaviour, audit log, and tests.

---

# 3. FORBIDDEN COMPLETION CLAIMS

Claude must not use these words unless the full end-to-end gate has passed:

```text
complete
completed
done
finished
ready
accepted
sign-off
fully wired
fully integrated
production ready
staging ready
all fixed
all working
final
```

Allowed honest classifications only:

```text
NOT ACCEPTED
LOCAL DEMO ONLY - NOT FULLY ACCEPTED
PARTIAL IMPLEMENTATION - NOT ACCEPTED
EXTERNAL BLOCKER EXISTS - NOT ACCEPTED
STAGING READY - FULL E2E PROVEN
PRODUCTION READY - FULL LIVE GATES PROVEN
```

---

# 4. MOCKS, STUBS, SIMULATORS, PLACEHOLDERS

## 4.1 Mock-only acceptance is forbidden

Mock, stub, fake, fixture, simulator, placeholder, or demo code can be used for unit tests only.

It cannot prove real acceptance.

## 4.2 Production path cannot use hidden mocks

If production/staging config is missing, the system must fail closed.

Examples:

```text
No AI key in real AI mode → controlled unavailable response, not fake legal reasoning
No Stripe webhook secret in Stripe mode → 503 fail closed
No official RAG sources → insufficient_grounding, not invented answer
No OCR engine → route disabled or 501 with clear UI state, not fake extraction
No case law licence → no bulk case law ingestion, with licence gate audit
```

## 4.3 Mandatory mock audit

Claude must run:

```bash
grep -R "mock\|stub\|fake\|placeholder\|simulator\|TODO\|NotImplemented" backend client ingestion shared scripts tests .github --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.next || true
```

Acceptance:

- Every result must be explained.
- Any mock in acceptance path = FAIL.
- Any hidden fake data = FAIL.
- Any user-facing placeholder presented as real = FAIL.

---

# 5. FULL SYSTEM ACCEPTANCE MATRIX

For every feature Claude touches, Claude must complete this matrix.

```text
Feature:
Frontend page/component:
Frontend action/button:
Backend route:
Backend service/function:
DB table(s):
DB function(s):
Migration file:
Rules engine involvement:
Official ingestion involvement:
Hybrid RAG involvement:
Graph RAG involvement:
Algorithm brain involvement:
Responsible AIA involvement:
WASM/JS involvement:
Security/auth/ownership:
Audit table written:
Success test:
Failure-path test:
Playwright/E2E test:
CI/CD gate:
Kubernetes proof if staging claimed:
Raw command output:
Status:
```

Status can only be:

```text
PASS - FULL E2E PROVEN
FAIL - NOT ACCEPTED
EXTERNAL BLOCKER - NOT ACCEPTED
NOT IN SCOPE - EXPLICITLY EXCLUDED
```

No other status is allowed.

---

# 6. REQUIRED END-TO-END FEATURE GROUPS

Claude must apply this rulebook to all of these feature groups.

## 6.1 User and auth

```text
register
login
JWT token
auth/me
logout/session handling
cross-user protection
```

Acceptance chain:

```text
UI → backend → users table → JWT → protected route → audit/security test → Playwright
```

## 6.2 Intake and assessment

```text
guided intake
claim classification
jurisdiction selection
rule fetch
assessment submit
honesty/weakness display
source citation display
```

Acceptance chain:

```text
UI → backend /assess → rules DB → official RAG → algorithm brain → responsible AIA → structured assessment → citations → frontend render → audit rows
```

## 6.3 Official legal data and RAG

```text
legislation ingestion
ACAS ingestion
GOV.UK/HMCTS/Judiciary ingestion
Find Case Law licence-gated ingestion
source freshness
hybrid search
citation bundle
graph RAG
```

Acceptance chain:

```text
official source → ingestion run → parser → DB row → chunk → embedding/index → search → citation bundle → answer → frontend
```

## 6.4 Deterministic rules

```text
unfair dismissal deadline
ACAS Early Conciliation stop-clock
qualifying period
compensation cap
week's pay cap
basic award formula
ACAS uplift/reduction
```

Acceptance chain:

```text
rules table → DB function → backend route → WASM/JS → backend validation → assessment → document → citation shown
```

## 6.5 WASM

```text
deadline calculation
EC pause calculation
client validation
document preview if implemented
JS fallback
```

Acceptance chain:

```text
backend rules → frontend → WASM → result → backend validation → UI display → Playwright proof
```

## 6.6 Responsible AIA

```text
legal boundary
citation coverage
confidence
grounding
PII boundary
reserved activity blocking
weakness disclosure
human handoff trigger
```

Acceptance chain:

```text
candidate answer → AIA check → allow/block/downgrade → audit row → frontend status display
```

## 6.7 Documents and payment

```text
payment session
payment webhook
payment_events
case payment status
document generation
document download
ownership check
```

Acceptance chain:

```text
UI → payment route → payment DB → webhook verification → case status → document generation → document table → download route → frontend
```

## 6.8 Upload/OCR

If enabled:

```text
upload
file validation
storage
OCR
extracted facts
user confirmation
case update
audit
```

If not enabled:

```text
route returns 501 or disabled state
frontend clearly says not enabled
not claimed as complete
```

## 6.9 CI/CD and Kubernetes

```text
GitHub Actions
local push/deploy script
Docker build
migration test
Kubernetes manifests
namespaces
rollout status
pod health
service health
ingress health
```

Acceptance chain:

```text
local clean test → commit → CI → image build → deploy → namespace → pod → health → logs
```

---

# 7. OFFICIAL LEGAL ANSWER ACCEPTANCE

No legal answer is accepted unless it includes:

```text
claim_type
jurisdiction
answer_status
deterministic_rules_used
official citations
source freshness
grounding score
confidence score
responsible AIA decision
legal boundary notice
audit trace id
```

Required response shape:

```json
{
  "claim_type": "unfair_dismissal",
  "jurisdiction": "EW",
  "answer_status": "answered | insufficient_grounding | blocked | human_review",
  "deterministic_rules_used": [],
  "citations": [],
  "source_freshness": [],
  "grounding_score": 0.0,
  "confidence_score": 0.0,
  "responsible_aia_decision": {
    "decision": "allow | block | downgrade | human_review",
    "reasons": []
  },
  "legal_boundary_notice": "Information and self-help drafting only. Not legal advice. Not a law firm.",
  "audit_trace_id": "uuid"
}
```

If citations are missing, the answer must be:

```text
insufficient_grounding
blocked
human_review
```

It must not be a confident answer.

---

# 8. DB ACCEPTANCE — TABLES ARE NOT ENOUGH

DB is accepted only when it is used by the live system.

Required proof:

```bash
docker compose exec -T db psql -U lawapp -d lawapp -c "\dt"
docker compose exec -T db psql -U lawapp -d lawapp -c "\df"
docker compose exec -T db psql -U lawapp -d lawapp -c "\di"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT * FROM get_source_freshness();"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT * FROM get_current_rules('unfair_dismissal','EW',CURRENT_DATE);"
docker compose exec -T db psql -U lawapp -d lawapp -c "EXPLAIN ANALYZE SELECT * FROM search_legal_chunks('unfair dismissal time limit','unfair_dismissal','EW',CURRENT_DATE,10);"
```

Acceptance:

```text
DB functions exist
DB functions are called by backend
backend results are shown in frontend
RAG uses DB chunks
algorithm uses DB rules
AIA audits are written to DB
audit rows increase after user journey
```

---

# 9. AUDIT ROW INCREASE TEST

Before and after a full assessment, Claude must prove audit rows increase.

```bash
BEFORE_RETRIEVAL=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM retrieval_audit;")
BEFORE_BUNDLES=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM rag_citation_bundles;")
BEFORE_TRACES=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM brain_traces;")
BEFORE_AIA=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM aia_governance_checks;")
BEFORE_SAFETY=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM safety_boundary_checks;")

curl -s http://localhost:8000/assess \
  -H "Content-Type: application/json" \
  -d @tests/fixtures/unfair_dismissal_case.json | jq .

AFTER_RETRIEVAL=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM retrieval_audit;")
AFTER_BUNDLES=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM rag_citation_bundles;")
AFTER_TRACES=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM brain_traces;")
AFTER_AIA=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM aia_governance_checks;")
AFTER_SAFETY=$(docker compose exec -T db psql -U lawapp -d lawapp -tAc "SELECT COUNT(*) FROM safety_boundary_checks;")

echo "retrieval_audit: $BEFORE_RETRIEVAL -> $AFTER_RETRIEVAL"
echo "rag_citation_bundles: $BEFORE_BUNDLES -> $AFTER_BUNDLES"
echo "brain_traces: $BEFORE_TRACES -> $AFTER_TRACES"
echo "aia_governance_checks: $BEFORE_AIA -> $AFTER_AIA"
echo "safety_boundary_checks: $BEFORE_SAFETY -> $AFTER_SAFETY"
```

Acceptance:

- all relevant counts increase,
- no audit row = no acceptance,
- no trace id = no acceptance.

---

# 10. FULL COMMAND GATE

Claude must run this after every major task before reporting completion:

```bash
set -euo pipefail

docker compose down -v
docker compose up -d --build

docker compose run --rm ingestion python -m ingestion.legislation.ingest --strict --claim-type unfair_dismissal
docker compose run --rm ingestion python -m ingestion.acas.ingest --strict
docker compose run --rm ingestion python -m ingestion.govuk.ingest --strict --topic employment_tribunal

python -m pytest -q
python -m pytest tests/security -q
python -m pytest tests/aia_governance -q
python -m pytest tests/rag -q
python -m pytest tests/ingestion -q
python -m pytest tests/payment tests/documents -q

bash scripts/rebuild-wasm.sh
npm --prefix client test
node_modules/.bin/playwright test --trace=retain-on-failure

bash scripts/smoke_local_journey.sh
bash scripts/security-regression.sh
bash scripts/push-and-deploy.sh --dry-run
```

If any command fails:

```text
Do not report completion.
Do not call it accepted.
Fix the issue.
Rerun the failed command.
Rerun the dependent commands.
Then rerun the full gate.
```

---

# 11. DB COUNT GATE

After the full command gate, Claude must run:

```bash
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM legislation;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM legislation_chunks;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM acas_guidance;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM govuk_guidance;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM rules;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM retrieval_audit;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM rag_citation_bundles;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM brain_traces;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM aia_governance_checks;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM safety_boundary_checks;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT * FROM get_source_freshness();"
```

Acceptance:

- required official legal tables must not be empty after strict ingestion,
- rules must be populated and cited,
- audit tables must prove real use,
- source freshness must work.

---

# 12. KUBERNETES LOOP IF STAGING IS CLAIMED

Claude cannot claim staging-ready without Kubernetes proof.

Required namespaces:

```text
lawapp-ai
lawapp-rag
lawapp-api
lawapp-monitoring
lawapp-security
```

Required proof:

```bash
kubectl config current-context
kubectl get ns | grep lawapp
kubectl -n lawapp-api get deploy,po,svc,ingress,cm,secret
kubectl -n lawapp-rag get deploy,po,svc,cm,secret
kubectl -n lawapp-ai get deploy,po,svc,cm,secret
kubectl -n lawapp-monitoring get deploy,po,svc,cm,secret
kubectl -n lawapp-security get deploy,po,svc,cm,secret
kubectl -n lawapp-api rollout status deploy/lawapp-backend --timeout=180s
kubectl -n lawapp-api exec deploy/lawapp-backend -- curl -s http://localhost:8000/health
kubectl -n lawapp-api logs deploy/lawapp-backend --tail=100
```

Acceptance:

- no CrashLoopBackOff,
- no Pending pods,
- no missing secrets,
- no wrong namespace,
- no stale project name,
- backend health passes inside pod,
- ingress proof if external staging URL is claimed.

---

# 13. FINAL REPORT FORMAT

Claude must create or update:

```text
reports/claude-lawapp-permanent-loop-e2e-acceptance-proof.md
```

The report must include:

```text
1. Statement that this rulebook was read and applied
2. Commit hash
3. Branch
4. Clean Docker proof
5. Official ingestion proof
6. DB schema/function/index proof
7. Rules proof
8. RAG proof
9. Algorithm brain proof
10. Responsible AIA proof
11. WASM proof
12. Frontend/backend wiring proof
13. Audit row increase proof
14. Security proof
15. Payment/document proof
16. CI/CD proof
17. Kubernetes proof if staging claimed
18. Full system acceptance matrix
19. Failed commands and fixes, if any
20. Remaining external blockers only, if any
21. Final classification
```

Allowed final classifications:

```text
NOT ACCEPTED
LOCAL DEMO ONLY - NOT FULLY ACCEPTED
PARTIAL IMPLEMENTATION - NOT ACCEPTED
EXTERNAL BLOCKER EXISTS - NOT ACCEPTED
STAGING READY - FULL E2E PROVEN
PRODUCTION READY - FULL LIVE GATES PROVEN
```

No other wording is allowed.

---

# 14. CLAUDE TASK LOOP TEMPLATE

Claude must use this template at the start of every task:

```text
I have read:
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md

For this task I will not accept isolated feature completion.
I will wire the work through frontend, backend, DB, rules/RAG/algorithm/AIA/WASM where applicable.
I will run the relevant full proof gates.
I will not claim completion if any command fails.
```

Claude must use this template before every completion report:

```text
I re-read:
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md

I checked the task against the full end-to-end chain.
I am reporting only what passed with raw command proof.
Any missing part is marked NOT ACCEPTED.
```

---

# 15. FINAL OWNER ORDER

Claude, from now on, this file is not optional.

Before every task, read it.

During every task, apply it.

Before every report, re-read it.

The owner does not accept failed, blocked, partial, mock-only, or isolated technology completion.

Acceptance means the whole lawapp system works together end to end:

```text
frontend
backend
DB
official ingestion
rules
RAG
algorithm brain
responsible AIA
WASM
security
audit
CI/CD
Kubernetes if staging is claimed
```

If it does not work together, it is not accepted.

Fix it, rerun, and prove it.
