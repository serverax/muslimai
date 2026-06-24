# LAWAPP — RESTRICTED AGGRESSIVE CHATGPT REVIEW ORDER
## Based on Gemini QA / Final Sign-off Claim

**File name:** `LAWAPP_CHATGPT_RESTRICTED_GEMINI_QA_REVIEW_ORDER.md`  
**Project root:** `F:\lawapp`  
**Required location:** `F:\lawapp\tasks\LAWAPP_CHATGPT_RESTRICTED_GEMINI_QA_REVIEW_ORDER.md`  
**Mandatory loop rulebook:** `F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md`  
**Gemini report to review:** `F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md`  
**Applies to:** ChatGPT, Claude Code, Gemini, or any AI agent reviewing or continuing lawapp  
**Priority:** Highest. This order overrides Gemini’s “APPROVED FOR STAGING” wording unless proven by the full end-to-end gate.

---

# 0. FIRST COMMAND — READ THE LOOP CONTROL FILE

Before touching code, before agreeing with Gemini, before writing any report, read this file:

```text
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md
```

Then read Gemini’s report:

```text
F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md
```

You must not accept Gemini’s “STAGING READY” or “final sign-off” claim until the loop rulebook criteria are proven.

---

# 1. OWNER POSITION — GEMINI CLAIM IS NOT ACCEPTED BY DEFAULT

Gemini claims:

```text
B. STAGING READY
APPROVED FOR STAGING
All critical path features are wired
All blockers resolved except owner keys
```

This claim is **not accepted** until independently proven.

The uploaded Gemini report gives only a small set of evidence:

```text
legislation = 6
acas_guidance = 2
migrations = 23
POST /api/brain/trace = ok + 1 source
POST /documents/generate = payment_required true
/extract = verified
```

This is not enough for acceptance.

A report with a few route checks is not full system proof.

A report without the full loop rulebook gate is not sign-off.

A report without frontend, backend, DB, RAG, AIA, WASM, security, CI/CD, and Kubernetes proof is not staging proof.

---

# 2. IMMEDIATE RECLASSIFICATION UNTIL PROVEN

Until the full gate passes, classify the current state as:

```text
LOCAL DEMO CLAIMED BY GEMINI — NOT ACCEPTED
STAGING READY CLAIMED — NOT PROVEN
PRODUCTION READY — NOT PROVEN
```

Do not use:

```text
approved
accepted
complete
final
staging ready
production ready
sign-off
```

unless the full proof passes.

---

# 3. GEMINI REPORT — HOSTILE REVIEW FINDINGS TO VERIFY

You must verify every claim in Gemini’s report directly from the repository and runtime.

## 3.1 Payment claim

Gemini says:

```text
sessionStorage mock-payment removed
real Stripe Checkout session creation implemented
document generation gated by cases.payment_status
```

You must prove:

```text
frontend has no mock payment bypass
backend creates real Stripe Checkout session only in Stripe mode
test simulator is clearly isolated
payment webhook verifies Stripe signature
payment event is written to DB
case payment_status is updated by verified webhook
document generation checks DB payment_status
cross-user document access is blocked
Playwright proves paid document flow
```

Required commands:

```bash
grep -R "mock-paid\|btn-mock-pay\|sessionStorage.*payment\|payment_token" client backend --exclude-dir=node_modules --exclude-dir=.next || true
grep -R "stripe.checkout.Session.create\|stripe.Webhook.construct_event\|payment_status\|payment_events" backend db tests || true
python -m pytest tests/payment tests/documents -q
bash scripts/smoke_local_journey.sh
```

PASS requires all commands to pass and raw output in the report.

---

## 3.2 OCR/extraction claim

Gemini says:

```text
mock_extract replaced with real extraction interface using pypdf and python-docx
/extract route wired to real document_extractor
```

You must prove:

```text
mock_extract is gone from production path
PDF extraction works with a real PDF fixture
DOCX extraction works with a real DOCX fixture
bad file type is rejected
oversized file is rejected
cross-user extraction is blocked
raw uploaded file is not sent to LLM
extracted facts require user confirmation before use
frontend shows extraction result or clear disabled state
```

Required commands:

```bash
grep -R "mock_extract\|fake_extract\|placeholder.*extract\|NotImplemented" backend client tests --exclude-dir=node_modules --exclude-dir=.next || true
python -m pytest tests/extraction tests/uploads -q
node_modules/.bin/playwright test tests/e2e/upload-extraction.spec.ts --trace=retain-on-failure
```

If `tests/e2e/upload-extraction.spec.ts` does not exist, that is a gap. Create it or mark NOT ACCEPTED.

---

## 3.3 Legal data spine claim

Gemini says:

```text
022_seed_legislation.sql and 023_seed_acas.sql seed ERA 1996 and ACAS guidance
legislation = 6
acas_guidance = 2
```

This is weak evidence.

The acceptance standard is not “6 legislation sections and 2 ACAS rows exist.”

You must prove:

```text
official source allowlist exists
source URLs are official
source freshness works
legal rows have citations, source_url, version/effective dates, last_verified_at
rules table is effective-dated and cited
legal chunks are searchable
RAG uses those rows
answers cite those rows
stale or missing source downgrades answer
```

Required commands:

```bash
docker compose down -v
docker compose up -d --build

docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM legislation;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM acas_guidance;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM rules;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT source_url, version_date, effective_from, effective_to, last_verified_at FROM legislation LIMIT 10;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT source_url, effective_from, last_verified_at FROM acas_guidance LIMIT 10;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT rule_key, authority_ref, authority_url, effective_from, effective_to, last_verified_at FROM rules ORDER BY rule_key LIMIT 50;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT * FROM get_source_freshness();"
```

If DB user/db name differs, first inspect `docker-compose.yml` and use the real credentials. Do not silently skip.

---

## 3.4 Brain/RAG/AIA claim

Gemini says:

```text
19-step brain verified
/api/brain/trace retrieves legal citations from seeded database and passes governance gate
```

You must prove the full chain:

```text
user request
→ classify
→ rules lookup
→ official RAG retrieval
→ citation bundle
→ algorithm brain
→ responsible AIA governance
→ structured assessment
→ frontend display
→ audit rows written
```

Required commands:

```bash
curl -s http://localhost:8000/api/brain/trace \
  -H "Content-Type: application/json" \
  -d '{"query":"What is the time limit for unfair dismissal?","claim_type":"unfair_dismissal","jurisdiction":"EW"}' | jq .

curl -s http://localhost:8000/assess \
  -H "Content-Type: application/json" \
  -d @tests/fixtures/unfair_dismissal_case.json | jq .

docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM retrieval_audit;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM rag_citation_bundles;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM brain_traces;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM aia_governance_checks;"
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT COUNT(*) FROM safety_boundary_checks;"
```

Acceptance:

```text
citations not empty
citations from official DB rows
rules used list not empty
responsible AIA decision present
audit counts increase after request
low/no-source question is blocked or downgraded
```

---

## 3.5 Frontend foundation claim

Gemini says:

```text
client/package.json created with build and test scripts
```

That is not frontend acceptance.

You must prove:

```text
all user journeys are wired
no dead buttons
no hidden mock API
frontend displays real backend assessment
frontend displays citations
frontend displays legal boundary notice
payment path is real or clearly test-only
document download works
upload/extraction works or disabled honestly
```

Required commands:

```bash
npm --prefix client install
npm --prefix client test
node_modules/.bin/playwright test --trace=retain-on-failure
bash scripts/smoke_local_journey.sh
grep -R "TODO\|mock\|stub\|fake\|placeholder" client/public client/src --exclude-dir=node_modules --exclude-dir=.next || true
```

If Playwright does not cover the full journey, create tests. Do not claim frontend accepted.

---

## 3.6 Document generation claim

Gemini says:

```text
generate_docx_bytes implemented
download endpoint streams actual .docx
documents/generate returns payment_required true for unpaid cases
```

You must prove:

```text
paid case can generate DOCX
unpaid case cannot generate DOCX
DOCX contains real case facts
DOCX contains legal boundary notice
download requires owner
cross-user download returns 403
binary headers correct
frontend can download
```

Required commands:

```bash
python -m pytest tests/documents -q
curl -I http://localhost:8000/api/documents/REPLACE_WITH_REAL_DOC_ID/download
docker compose exec -T db psql -U lawapp -d lawapp -c "SELECT id, case_id, doc_type, created_at FROM documents ORDER BY created_at DESC LIMIT 10;"
```

Do not use fake document IDs as proof. Create a real case and real document in the test.

---

## 3.7 Kubernetes claim

Gemini says:

```text
Kubernetes manifests fixed
cross-namespace ConfigMap/Secret errors resolved
Postgres DNS unified
```

This is not staging proof.

You must prove live Kubernetes, not YAML existence.

Required commands:

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

```text
no CrashLoopBackOff
no Pending pods
no missing secrets
no wrong namespace references
backend health passes inside pod
external ingress health proven if staging URL is claimed
```

If kubeconfig is unavailable, classify as:

```text
LOCAL DEMO ONLY - KUBERNETES NOT PROVEN
```

Do not claim staging ready.

---

# 4. FULL LOOP RULEBOOK GATE MUST BE RUN

After verifying Gemini’s claims, run the mandatory full gate from:

```text
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md
```

Minimum command gate:

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
Do not claim complete.
Do not claim staging ready.
Do not claim accepted.
Fix it.
Rerun the failed command.
Rerun dependent commands.
Rerun the full gate.
```

---

# 5. FULL INTEGRATION ACCEPTANCE MEANS FEATURES WORK TOGETHER

You must not accept isolated technology.

For each feature, prove this full chain:

```text
Frontend page/component
→ Backend route
→ DB migration/table/function
→ Rules/RAG/algorithm/AIA where applicable
→ WASM where applicable
→ Security/ownership
→ Audit rows
→ User-facing result
→ Playwright/smoke proof
```

A feature cannot pass if:

```text
backend works but frontend does not call it
frontend exists but calls mocked data
DB table exists but backend does not use it
RAG exists but does not cite official sources
AIA exists but does not control answers
WASM exists but is not used in the live flow
payment exists but webhook does not update DB
document generation exists but payment gate is bypassable
Kubernetes YAML exists but pods are not proven healthy
```

---

# 6. REQUIRED HOSTILE OUTPUT REPORT

Create a new report:

```text
F:\lawapp\reports\chatgpt-hostile-review-of-gemini-final-signoff.md
```

The report must include:

```text
1. Confirmation that LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md was read
2. Summary of Gemini’s claims
3. Direct verdict on each Gemini claim: PROVEN / NOT PROVEN / FALSE / PARTIAL
4. Raw command output
5. Full feature integration matrix
6. DB table counts
7. DB function/index proof
8. Official source and citation proof
9. RAG proof
10. Algorithm brain proof
11. Responsible AIA proof
12. WASM proof
13. Frontend/backend wiring proof
14. Payment/document proof
15. OCR proof
16. Security proof
17. CI/CD proof
18. Kubernetes proof if staging is claimed
19. Remaining gaps with exact files and commands
20. Final classification
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

# 7. STRICT FINAL DECISION RULES

Use these rules:

```text
If full command gate fails → NOT ACCEPTED
If Playwright full journey fails/missing → NOT ACCEPTED
If security tests fail/missing → NOT ACCEPTED
If RAG citations missing → NOT ACCEPTED
If AIA governance does not block unsafe answers → NOT ACCEPTED
If official legal tables are empty/weak and not properly cited → NOT ACCEPTED
If payment webhook does not update DB → NOT ACCEPTED
If document generation bypasses payment → NOT ACCEPTED
If Kubernetes not proven → not STAGING READY
If real Stripe/AI keys missing → not PRODUCTION READY
If any critical path uses mock/fake/stub → NOT ACCEPTED
```

---

# 8. SHORT COMMAND TO CHATGPT

Use this instruction exactly:

```text
ChatGPT, read this first:
F:\lawapp\tasks\LAWAPP_PERMANENT_LOOP_ACCEPTANCE_RULEBOOK.md

Then hostile-review Gemini’s final sign-off report:
F:\lawapp\reports\lawapp-final-completion-and-signoff-proof.md

Do not accept Gemini’s “STAGING READY” claim unless the full end-to-end loop gate passes. Treat every claim as untrusted until proven by raw command output. Features must work together through frontend, backend, DB, official RAG, algorithm brain, responsible AIA, WASM, security, audit logs, CI/CD, and Kubernetes if staging is claimed. Mock-only, isolated, partial, blocked, or failed work is NOT ACCEPTED.
```

---

# 9. FINAL OWNER ORDER

ChatGPT must act as a hostile reviewer, not a friendly summariser.

Do not rubber-stamp Gemini.

Do not accept “final sign-off” wording.

Read the loop rulebook.

Run the proof.

If it fails, say it failed.

If it is partial, say it is partial.

If it is local only, say local only.

If it is not deployed and healthy in Kubernetes, do not say staging ready.

If the system does not work end to end with all technologies integrated, it is not accepted.
