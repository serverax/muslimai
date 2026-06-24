# LAWAPP — ULTIMATE RESTRICTED CHATGPT ORDER
## QA-Audit Based Hostile Review Before Any New Code or Project Changes

**File name:** `LAWAPP_ULTIMATE_RESTRICTED_CHATGPT_QA_AUDIT_ORDER.md`  
**Project root:** `F:\lawapp`  
**Required location:** `F:\lawapp\tasks\LAWAPP_ULTIMATE_RESTRICTED_CHATGPT_QA_AUDIT_ORDER.md`  
**Mandatory loop control file:** `F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md`  
**QA/signoff report to audit:** `F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md`  
**Applies to:** ChatGPT, Claude Code, Gemini, and any coding/review agent working on lawapp  
**Priority:** Absolute highest. This order overrides any weaker sign-off, local report, partial report, or AI-generated readiness claim.

---

# 0. FIRST ORDER — DO NOT ADD ANYTHING BEFORE READING THE LOOP FILE

Before adding, editing, deleting, refactoring, testing, reporting, or accepting anything in the project, ChatGPT must read:

```text
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md
```

Then ChatGPT must read:

```text
F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md
```

Only after both files are read may ChatGPT inspect or change the project.

If ChatGPT has not read the loop control file, it must not:

```text
write code
edit files
create migrations
change frontend
change backend
change Kubernetes manifests
change CI/CD
mark anything complete
accept any QA report
agree with any staging-ready claim
```

---

# 1. OWNER POSITION — NO TRUST, NO RUBBER-STAMPING

The QA/signoff report claims:

```text
B. STAGING READY
APPROVED FOR STAGING
All critical path features are wired to real services
All major mock components removed
```

This is not accepted by default.

The report’s own evidence is limited to:

```text
legislation = 6
acas_guidance = 2
migrations = 23
/api/brain/trace = ok + 1 source
/documents/generate = payment_required true
/extract = verified
```

That is not enough for the owner’s acceptance criteria.

A few database counts and route checks do not prove:

```text
frontend/backend integration
full user journey
Stripe webhook DB update
real document generation with ownership
official-source RAG
responsible AIA control
WASM live usage
security controls
audit row increases
CI/CD gates
Kubernetes staging health
```

Until proven, the correct classification is:

```text
GEMINI/QA CLAIMED STAGING READY — NOT ACCEPTED
LOCAL DEMO CLAIMED — NOT FULLY ACCEPTED
FULL END-TO-END ACCEPTANCE — NOT PROVEN
```

---

# 2. ZERO-PARTIAL ACCEPTANCE STANDARD

The owner does not accept:

```text
failed
blocked
partial
mock-only
stub-only
simulator-only
isolated feature pass
backend-only pass
frontend-only pass
DB-only pass
RAG-only pass
AIA-only pass
WASM-only pass
Kubernetes YAML-only pass
CI YAML-only pass
unit-test-only pass
```

Acceptance means the full system works together:

```text
Frontend UI
→ Backend API
→ Authentication and ownership
→ DB migrations, tables, functions, indexes
→ Deterministic rules engine
→ Official-source ingestion
→ Hybrid RAG
→ Graph RAG where applicable
→ Algorithm brain
→ Responsible AIA governance
→ WASM/JS where applicable
→ Payment/document/OCR where applicable
→ Security and privacy controls
→ Audit logs and trace rows
→ CI/CD gates
→ Kubernetes health if staging is claimed
```

If one part is missing, the feature is **NOT ACCEPTED**.

---

# 3. CHATGPT ROLE — HOSTILE AUDITOR FIRST, CODER SECOND

ChatGPT must act in this order:

## Step 1 — Read rulebook

Read:

```text
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md
```

## Step 2 — Read QA/signoff report

Read:

```text
F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md
```

## Step 3 — Do not believe the report

Treat every claim as untrusted until proven by raw command output.

## Step 4 — Inspect repo and runtime

Verify code, migrations, routes, frontend, tests, Docker, CI/CD, and Kubernetes.

## Step 5 — Run the full acceptance gate

Do not rely on report text.

## Step 6 — Only then add/fix code

Only add code after identifying a proven gap.

## Step 7 — Re-run the full gate

No task is accepted until the full integrated gate passes.

---

# 4. STRICT NO-CODE-BEFORE-AUDIT RULE

Before any code change, ChatGPT must produce a short internal checklist:

```text
[ ] Loop rulebook read
[ ] QA/signoff report read
[ ] Claims extracted
[ ] Current repo state inspected
[ ] Existing tests inspected
[ ] Existing mocks/stubs searched
[ ] Existing DB migrations inspected
[ ] Existing frontend wiring inspected
[ ] Existing backend routes inspected
[ ] Existing RAG/AIA/WASM wiring inspected
[ ] Gap list created
[ ] Only then code changes allowed
```

If this checklist is not satisfied, ChatGPT must not edit the project.

---

# 5. QA CLAIMS THAT MUST BE HOSTILE-AUDITED

## 5.1 Claim: Payment is real

QA says:

```text
sessionStorage mock payment removed
real Stripe Checkout implemented
document generation gated by cases.payment_status
```

ChatGPT must prove:

```text
No client-side payment bypass exists
No sessionStorage/localStorage payment token bypass exists
Stripe checkout session creation is real in Stripe mode
test simulator is isolated and impossible in staging/prod
Stripe webhook signature is verified
payment_events table is written
case payment_status changes only after verified event
document generation checks DB payment_status
document download checks ownership
cross-user access returns 403
frontend payment flow works end to end
```

Commands:

```bash
grep -R "mock-paid\|btn-mock-pay\|sessionStorage.*payment\|localStorage.*payment\|payment_token\|fake.*payment" client backend tests --exclude-dir=node_modules --exclude-dir=.next || true
grep -R "stripe.checkout.Session.create\|stripe.Webhook.construct_event\|payment_status\|payment_events" backend db tests || true
python -m pytest tests/payment tests/documents -q
bash scripts/smoke_local_journey.sh
node_modules/.bin/playwright test --trace=retain-on-failure
```

Fail if:

```text
webhook does not update DB
payment can be forged
frontend still bypasses payment
document generation can happen unpaid
cross-user document access is possible
```

---

## 5.2 Claim: OCR/extraction is real

QA says:

```text
mock_extract replaced
pypdf and python-docx extraction implemented
/extract route wired
```

ChatGPT must prove:

```text
PDF fixture extraction works
DOCX fixture extraction works
bad file type rejected
oversized file rejected
cross-user extraction blocked
raw upload is not sent to LLM
extracted facts require user confirmation
frontend displays extraction result or disabled state
audit row written
```

Commands:

```bash
grep -R "mock_extract\|fake_extract\|placeholder.*extract\|NotImplemented\|return.*sample" backend client tests --exclude-dir=node_modules --exclude-dir=.next || true
python -m pytest tests/extraction tests/uploads -q
node_modules/.bin/playwright test tests/e2e/upload-extraction.spec.ts --trace=retain-on-failure
```

If tests are missing, create them before claiming acceptance.

---

## 5.3 Claim: Legal data spine is real

QA says:

```text
legislation = 6
acas_guidance = 2
```

This is weak. ChatGPT must prove:

```text
legal data comes from official sources
source_url exists
authority_ref exists
version/effective dates exist
last_verified_at exists
rules table is complete and cited
source freshness works
legal chunks are searchable
RAG uses DB rows
answers cite official authority
missing/weak sources trigger insufficient grounding
```

Commands:

```bash
docker compose down -v
docker compose up -d --build

docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM legislation;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM acas_guidance;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM rules;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT source_url, version_date, effective_from, effective_to, last_verified_at FROM legislation LIMIT 20;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT source_url, effective_from, last_verified_at FROM acas_guidance LIMIT 20;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT rule_key, authority_ref, authority_url, effective_from, effective_to, last_verified_at FROM rules ORDER BY rule_key;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT * FROM get_source_freshness();"
```

If actual DB credentials differ, inspect `docker-compose.yml` and use the correct values. Do not skip.

---

## 5.4 Claim: RAG and brain are real

QA says:

```text
19-step brain verified
/api/brain/trace retrieves legal citations
governance gate passes
```

ChatGPT must prove:

```text
classification works
rules lookup works
official RAG retrieval works
citation bundle created
algorithm brain uses retrieved sources
responsible AIA controls answer
structured assessment returned
frontend displays answer
audit rows increase
unsafe/uncited answer is blocked
```

Commands:

```bash
curl -s http://localhost:8000/api/brain/trace \
  -H "Content-Type: application/json" \
  -d '{"query":"What is the time limit for unfair dismissal?","claim_type":"unfair_dismissal","jurisdiction":"EW"}' | jq .

curl -s http://localhost:8000/assess \
  -H "Content-Type: application/json" \
  -d @tests/fixtures/unfair_dismissal_case.json | jq .

python -m pytest tests/rag tests/aia_governance -q
```

Audit proof:

```bash
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM retrieval_audit;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM rag_citation_bundles;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM brain_traces;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM aia_governance_checks;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM safety_boundary_checks;"
```

Fail if:

```text
citations empty
citations not official
AIA decision missing
AIA does not block unsafe answer
audit rows do not increase
```

---

## 5.5 Claim: Frontend foundation is enough

QA says:

```text
client/package.json created
```

This is not enough.

ChatGPT must prove full frontend wiring:

```text
register
login
intake
rule fetch
WASM deadline
backend deadline validation
assessment
citations
source freshness
case save
dashboard
document payment
document generation
document download
handoff
upload/extraction or disabled state
```

Commands:

```bash
npm --prefix client install
npm --prefix client test
node_modules/.bin/playwright test --trace=retain-on-failure
bash scripts/smoke_local_journey.sh
grep -R "TODO\|mock\|stub\|fake\|placeholder\|sample assessment\|demo data" client/public client/src --exclude-dir=node_modules --exclude-dir=.next || true
```

Fail if:

```text
dead buttons exist
mocked frontend data used
citations not displayed
legal notice missing
payment/doc flow not proven
```

---

## 5.6 Claim: Document generation is real

QA says:

```text
generate_docx_bytes implemented
download streams DOCX
unpaid cases return payment_required
```

ChatGPT must prove:

```text
paid case generates DOCX
unpaid case blocked
DOCX contains real case facts
DOCX contains legal boundary notice
correct MIME headers
ownership enforced
cross-user download blocked
frontend download works
```

Commands:

```bash
python -m pytest tests/documents -q
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT id, case_id, doc_type, created_at FROM documents ORDER BY created_at DESC LIMIT 10;"
```

Do not use fake UUIDs as proof.

---

## 5.7 Claim: Kubernetes is stable

QA says:

```text
manifests fixed
Postgres DNS unified
ConfigMaps/Secrets corrected
```

YAML correction is not staging readiness.

ChatGPT must prove live cluster health.

Commands:

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

If this cannot be run, classification cannot be STAGING READY.

---

# 6. FULL ACCEPTANCE GATE

ChatGPT must run this full gate after any fix and before any report.

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
Do not claim ready.
Do not claim accepted.
Fix it.
Rerun the failed command.
Rerun dependent commands.
Rerun the full gate.
```

---

# 7. FULL FEATURE INTEGRATION MATRIX

For every feature reviewed or changed, ChatGPT must produce this matrix:

```text
Feature:
QA claim:
Verdict on QA claim: PROVEN / PARTIAL / FALSE / NOT PROVEN
Frontend page/component:
Backend route:
Backend service/function:
DB table(s):
DB function(s):
Migration:
Rules engine:
Official ingestion:
Hybrid RAG:
Graph RAG:
Algorithm brain:
Responsible AIA:
WASM/JS:
Security/auth/ownership:
Audit table written:
Unit test:
Integration test:
Playwright/E2E test:
CI/CD gate:
Kubernetes proof if staging claimed:
Raw command proof:
Final status:
```

Allowed final status only:

```text
PASS - FULL E2E PROVEN
FAIL - NOT ACCEPTED
PARTIAL - NOT ACCEPTED
EXTERNAL BLOCKER - NOT ACCEPTED
NOT IN CURRENT SCOPE - EXPLICITLY EXCLUDED
```

---

# 8. REQUIRED HOSTILE REVIEW REPORT

ChatGPT must create:

```text
F:\lawapp\reports\chatgpt-ultimate-hostile-qa-audit-before-any-new-code.md
```

The report must include:

```text
1. Confirmation loop control file was read
2. Confirmation QA/signoff report was read
3. Gemini/QA claims extracted
4. Direct verdict on each claim
5. Raw command output
6. Full acceptance gate result
7. Full feature integration matrix
8. DB counts
9. DB function/index proof
10. Official source proof
11. Rules proof
12. RAG proof
13. Algorithm brain proof
14. Responsible AIA proof
15. WASM proof
16. Frontend/backend proof
17. Payment/document proof
18. OCR proof
19. Security proof
20. CI/CD proof
21. Kubernetes proof if staging is claimed
22. Exact remaining gaps
23. Exact files to fix
24. Exact next commands
25. Final classification
```

Allowed final classifications only:

```text
NOT ACCEPTED
LOCAL DEMO ONLY - NOT FULLY ACCEPTED
PARTIAL IMPLEMENTATION - NOT ACCEPTED
EXTERNAL BLOCKER EXISTS - NOT ACCEPTED
STAGING READY - FULL E2E PROVEN
PRODUCTION READY - FULL LIVE GATES PROVEN
```

---

# 9. STRICT DECISION RULES

Use these rules with no negotiation:

```text
Full gate fails → NOT ACCEPTED
Playwright missing or incomplete → NOT ACCEPTED
Security tests missing or failing → NOT ACCEPTED
RAG citations missing → NOT ACCEPTED
Responsible AIA missing or passive → NOT ACCEPTED
Official data weak/uncited → NOT ACCEPTED
Payment webhook not DB-wired → NOT ACCEPTED
Document generation bypassable → NOT ACCEPTED
OCR untested → NOT ACCEPTED for OCR claim
WASM not live in UI → NOT ACCEPTED for WASM claim
Kubernetes not live/healthy → not STAGING READY
Real AI/Stripe keys missing → not PRODUCTION READY
Mock/fake/stub on critical path → NOT ACCEPTED
```

---

# 10. SHORT MESSAGE TO CHATGPT

Use this exact message:

```text
ChatGPT, before adding anything to lawapp, read:

F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md

Then read:

F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md

Then execute:

F:\lawapp\tasks\LAWAPP_ULTIMATE_RESTRICTED_CHATGPT_QA_AUDIT_ORDER.md

Do not add code before hostile-auditing the QA/signoff claims. Do not accept “STAGING READY” unless the full end-to-end gate passes. Treat all QA claims as untrusted until proven by raw command output.

The owner does not accept failed, blocked, partial, mock-only, or isolated technology completion. Features must work together through frontend, backend, DB, official ingestion, rules, RAG, algorithm brain, responsible AIA, WASM, security, audit logs, CI/CD, and Kubernetes if staging is claimed.
```

---

# 11. FINAL OWNER ORDER

ChatGPT must be aggressive, hostile, and evidence-led.

Do not summarise the QA report as true.

Do not rubber-stamp Gemini.

Do not add new code before reading the loop rulebook.

Do not accept partial proof.

Do not accept mocked proof.

Do not accept route-only proof.

Do not accept table-count-only proof.

Do not accept Kubernetes YAML as staging proof.

Only accept full end-to-end integrated proof.

If it fails, say it failed.

If it is partial, say partial.

If it is local only, say local only.

If Kubernetes is not live and healthy, do not say staging ready.

If the system is not integrated end to end, it is not accepted.
