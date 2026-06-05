# Sakina AI — Mandatory Loop Control Rules

**Project:** Sakina AI  
**Project path:** `F:\SakinaAL` / `/mnt/f/SakinaAL`  
**Tasks path:** `F:\SakinaAL\tasks`  
**Main order file:** `F:\SakinaAL\tasks\sakina-ultimate-hard-execution-order.md`

This file is mandatory. Claude Code must read it before every task, every code change, every test, every gate, and every report update.

---

## 1. Mandatory Loop

Before every task, Claude must follow this loop:

```text
READ THIS LOOP FILE
→ READ THE MAIN ORDER MD FILE
→ SELECT ONE TASK
→ CHECK ITS ACCEPTANCE CRITERIA
→ IMPLEMENT
→ WIRE END TO END
→ RUN REAL COMMAND PROOF
→ RUN NEGATIVE TEST
→ SAVE EVIDENCE
→ UPDATE MATRIX
→ CHECK IF CLAIM IS ALLOWED
→ IF NOT FULLY PROVEN, DO NOT SAY DONE
→ RETURN TO READ THIS LOOP FILE AGAIN
```

No task is complete until this loop is completed.

---

## 2. Required Start of Every Work Cycle

At the start of every work cycle, run:

```bash
cd /mnt/f/SakinaAL || exit 1

cat /mnt/f/SakinaAL/tasks/sakina-loop-control-rules.md
cat /mnt/f/SakinaAL/tasks/sakina-ultimate-hard-execution-order.md | head -120
```

Claude must then apply these rules before doing any work:

```text
I have re-read the loop rules.
I have re-read the main order.
I will not reduce the acceptance criteria.
I will not report partial work as complete.
I will only claim DONE when the full integrated proof passes.
```

---

## 3. Non-Negotiable Completion Standard

The owner is not accepting these as completion:

```text
FAILED
BLOCKED
PARTIAL
SAFE DISABLED
IMPLEMENTED BUT NOT WIRED
LOCAL ONLY
MOCKED
PLACEHOLDER
DOCUMENTED ONLY
```

These statuses may only be reported as blockers.

The only accepted completion status is:

```text
COMPLETE — END-TO-END INTEGRATED AND PROVEN
```

or:

```text
READY FOR CLOSED BETA — HARD EVIDENCE PASSED
```

---

## 4. Meaning of Acceptance Criteria

Acceptance criteria do not mean:

- file exists
- route exists
- table exists
- code compiles
- UI screen appears
- test script prints PASS
- screenshot exists
- report says implemented
- technology is mentioned in documentation

Acceptance criteria mean the feature works end to end in the real Sakina system.

Required chain:

```text
Flutter mobile app
→ frontend screen
→ frontend service/state
→ real HTTP request
→ backend API route
→ auth/JWT/session validation
→ RLS/user isolation
→ backend handler
→ backend service/function
→ Brain Mother Algorithm / AIA
→ required technology:
   RAG / Graph RAG / Hybrid Search / Memory / AI Router / Safety /
   Semantic Cache / WASM / Qdrant / Payments / Multimodal / Outbox
→ DB / Qdrant / storage / functions / triggers
→ response returned to backend
→ response returned to frontend
→ frontend parses real response
→ frontend state updates from backend result
→ trace ID created
→ audit log written
→ metrics/logs generated
→ CI/CD proof
→ Kubernetes/server proof where required
→ release mobile proof where required
```

If this full chain is not proven, the feature is not complete.

---

## 5. No Isolated Technology Acceptance

No technology is accepted alone.

These are not enough:

```text
Brain file exists
AIA folder exists
RAG collection exists
Qdrant container is reachable
Graph table exists
WASM builds
DB migration exists
Flutter screen exists
Backend route returns 200
CI file exists
Kubernetes YAML exists
```

Every technology must be wired into the real user journey.

Technologies include:

- Brain Mother Algorithm
- AIA / Agentic Workflow
- RAG
- Graph RAG
- Hybrid Search
- Qdrant
- Semantic Cache
- Memory Engine
- Context Compression
- AI Router
- Evaluation AI
- MCP / connectors if enabled
- Multimodal if enabled
- WASM
- Payments / subscriptions / entitlements if enabled
- Feature flags
- Policy-as-code
- Citation / hallucination validator
- Observability
- Secrets management
- Zero-trust API guard
- Arabic-English / RTL
- Store compliance
- CI/CD
- Kubernetes
- frontend/backend/DB wiring

Each must be either:

```text
LIVE, WIRED, TESTED, OBSERVABLE, AND PROVEN
```

or:

```text
HIDDEN, FAILS CLOSED, AND REPORTED AS NOT COMPLETE
```

---

## 6. Anti-Fake Rules

Claude must never use:

- fake PASS
- fake report
- fake user
- fake token
- fake payment success
- fake RAG answer
- fake citation
- fake embedding
- fake Graph RAG traversal
- fake WASM invocation
- fake frontend success
- fake DB proof
- mock provider
- demo bootstrap
- placeholder route
- static JSON pretending to be runtime
- hardcoded success response
- screenshot-only evidence
- `echo PASS` as proof
- `|| true` to hide failure
- `continue-on-error: true` in required CI

Any occurrence in production paths is a blocker.

---

## 7. Mandatory Proof Pattern for Every Task

For every task, Claude must create evidence using this pattern:

```text
Task name:
Files changed:
Commands run:
Positive proof:
Negative proof:
Frontend proof:
Backend proof:
DB proof:
Brain/AIA proof:
Technology proof:
Security proof:
Trace/audit proof:
CI proof:
Kubernetes proof:
Release/mobile proof:
Result:
Remaining blocker:
```

If a category is not applicable, explain why.

Do not leave it blank.

---

## 8. Before Saying DONE

Before saying DONE, Claude must ask:

```text
Did the frontend call the backend?
Did the backend route call the handler?
Did the handler call the service/function?
Did the service/function touch the real DB/Qdrant/storage/provider?
Did RLS/user isolation apply?
Did the Brain/AIA control the decision?
Did the required technology run in the real path?
Did the result return to the frontend?
Did the frontend parse and display the real response?
Did the positive test pass?
Did the negative test pass?
Did the cross-user test pass?
Did trace/audit/metrics prove it?
Did CI run it?
Did Kubernetes/server prove it where required?
Did release mobile build prove it where required?
```

If any answer is no, the task is not DONE.

---

## 9. Required Stop Conditions

Stop claiming progress and report a blocker if:

- Kubernetes cannot be reached
- remote CI cannot be run
- release AAB cannot be built
- Docker API image cannot build
- live LLM/embedding provider is missing for live AI features
- frontend feature is visible but backend is disabled
- backend route exists but DB/function is not wired
- DB object exists but runtime does not use it
- Brain/AIA does not control the path
- WASM exists but is not invoked by real request
- RAG exists but answer does not cite retrieved chunks
- Graph RAG exists but graph traversal is not in trace
- security negative tests fail
- RLS isolation fails
- payment/multimodal feature is visible but not live
- app store release build is missing
- any proof script hides failure

The report must show the exact failed command and evidence file.

---

## 10. Required Gates

Claude must run these gates repeatedly after relevant changes:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/final-wiring-gate.sh
bash scripts/sakina/final-new-technologies-gate.sh
bash scripts/sakina/final-closed-beta-gate.sh
```

These gates must fail on the first real blocker.

They must not use:

```bash
|| true
echo PASS
continue-on-error
```

---

## 11. Gate Behaviour

Each gate must:

1. read this loop file
2. read the main order file
3. run the required checks
4. stop on failure
5. save evidence
6. print exact failed command
7. print exact evidence file
8. print final status

A gate is invalid if it only creates a report.

A gate is invalid if it skips real runtime checks.

A gate is invalid if it passes while a blocker exists.

---

## 12. Required Evidence Folder

All evidence must go here:

```text
F:\SakinaAL\reports\final-hardening-evidence
```

WSL path:

```text
/mnt/f/SakinaAL/reports/final-hardening-evidence
```

No evidence means no acceptance.

---

## 13. Required Matrix Updates

After every task, update the relevant matrix:

```text
230-frontend-backend-wiring-matrix.md
240-backend-route-handler-db-matrix.md
250-db-function-wiring-matrix.md
560-new-technologies-master-matrix.md
```

If the matrix is not updated, the task is not complete.

---

## 14. Required Report Language

Do not write:

```text
mostly done
implemented locally
should work
appears to work
ready except
blocked but acceptable
safe disabled but complete
partial sign-off
```

Use only factual status:

```text
PASS
FAIL
BLOCKER
NOT IMPLEMENTED
PARTIAL — NOT ACCEPTED
SAFE DISABLED — NOT ACCEPTED AS COMPLETE
COMPLETE — END-TO-END INTEGRATED AND PROVEN
```

---

## 15. Final Verdict Rules

The final verdict can only be:

```text
READY FOR CLOSED BETA — HARD EVIDENCE PASSED
```

if all of these pass:

- Docker API build
- Kubernetes/server namespace proof
- remote CI/CD
- release APK
- release AAB
- backend/frontend/DB wiring
- DB functions/triggers
- empty DB migration
- RLS/user isolation
- auth/JWT/refresh/logout
- Brain/AIA routing
- RAG or safe-hidden disabled mode
- Graph RAG or safe-hidden disabled mode
- LLM/embedding or safe-hidden disabled mode
- Islamic safety
- security hardening
- WASM integration
- new technologies gate
- wiring gate
- final closed-beta gate
- anti-fake scan

If any one fails, verdict must be:

```text
NOT READY — REAL BLOCKERS REMAIN
```

If wiring fails:

```text
NOT READY — BACKEND/FRONTEND/DB WIRING BLOCKERS REMAIN
```

If new technology integration fails:

```text
NOT READY — NEW TECHNOLOGY WIRING BLOCKERS REMAIN
```

---

## 16. Owner Instruction

The owner is not accepting failed, blocked, partial, or disabled work as completion.

Claude must keep working through the order, fixing blockers one by one.

If a blocker requires owner access or credentials, report:

```text
BLOCKER:
FAILED COMMAND:
EVIDENCE FILE:
WHY IT BLOCKS CLOSED BETA:
OWNER ACTION REQUIRED:
NEXT TASK AFTER OWNER ACTION:
```

Do not replace implementation with excuses.

Do not replace proof with a report.

Do not replace end-to-end integration with isolated tests.

---

## 17. Mandatory Re-Read Before Every Claim

Before writing any status line, Claude must re-read this rule:

```text
A feature is accepted only when it works through the complete integrated chain:
Flutter → backend → auth/RLS → Brain/AIA → required technology → DB/Qdrant/storage/functions/WASM → response → frontend → trace/audit/metrics → CI/Kubernetes/release proof.
```

If that full chain is not proven, do not call it complete.

---

## 18. Final Reminder

The purpose is not to make the report look good.

The purpose is to expose the truth and force Sakina AI to become a real closed-beta-ready mobile app.

No fake completion.

No isolated component success.

No partial sign-off.

No blocked sign-off.

Only integrated, end-to-end, hard evidence.
