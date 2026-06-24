# Sakina AI — Ultimate Hard Execution Order

**Project:** Sakina AI  
**Repository:** `https://github.com/serverax/muslimai`  
**Project directory:** `F:\SakinaAL` / `/mnt/f/SakinaAL`  
**Branch:** `qa-security-hardening`  
**Known commit from previous sign-off:** `7d0d0372de3d45daff0dba91492821962f1d65a0`  
**Current classification from previous sign-off:** `NOT READY — REAL BLOCKERS REMAIN`

This document merges the three previous orders into one execution file:

1. Final hard execution order with aggressive anti-fake acceptance criteria.
2. Backend ↔ frontend ↔ DB/function wiring order.
3. New technologies implementation order with restrictive acceptance criteria.

This is not a reporting task. This is an execution task.

The agent must finish Sakina AI to real closed-beta readiness, or prove with hard evidence why it remains blocked.

---

## 0. Absolute Rules

The agent must obey these rules.

1. Work only on Sakina AI.
2. Do not work on lawapp.
3. Do not work on OrdinoxAI except where Sakina deployment or infrastructure directly requires it.
4. Do not change unrelated repositories.
5. Do not report any task as complete unless it is proven by command output.
6. Do not use screenshots as the only evidence.
7. Do not use fake responses, placeholder files, diagrams, or static reports as proof.
8. Do not mark disabled features as complete.
9. Do not hide blockers.
10. Do not use `|| true` in proof commands.
11. Do not use `continue-on-error: true` in required CI jobs.
12. Do not use `echo PASS` as proof.
13. Do not hardcode secrets.
14. Do not use demo users, demo tokens, fake sessions, mock providers, or placeholder providers in production paths.
15. Every visible frontend feature must have real backend and DB/function wiring.
16. Every backend route must have a handler, service/function, tests, and DB/provider proof where applicable.
17. Every DB table/function/trigger/policy must be mapped to real runtime use or marked unused.
18. Every new technology must be either `LIVE AND PROVEN` or `SAFE DISABLED, HIDDEN, AND FAILS CLOSED`.
19. If Kubernetes cannot be verified, the project is not closed-beta ready.
20. If LLM/embedding provider is disabled, live AI/RAG answer generation is not closed-beta ready.
21. If only debug APK exists, mobile closed beta is not ready.
22. If remote CI/CD was not run, deployment automation is not ready.

Allowed status values:

```text
COMPLETE AND LIVE
COMPLETE BUT LOCAL ONLY
LIVE AND PROVEN
SAFE DISABLED
PARTIAL
FAILED
NOT IMPLEMENTED
```

Final verdict must be one of:

```text
READY FOR CLOSED BETA — HARD EVIDENCE PASSED
```

or:

```text
NOT READY — REAL BLOCKERS REMAIN
```

or, if wiring fails:

```text
NOT READY — BACKEND/FRONTEND/DB WIRING BLOCKERS REMAIN
```

or, if new technologies fail:

```text
NOT READY — NEW TECHNOLOGY WIRING BLOCKERS REMAIN
```

---

# Part 1 — Final Hard Execution Order

## 1. Clean Evidence Baseline

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

mkdir -p reports/final-hardening-evidence

date -Is | tee reports/final-hardening-evidence/00-date.txt
git branch --show-current | tee reports/final-hardening-evidence/01-branch.txt
git rev-parse HEAD | tee reports/final-hardening-evidence/02-commit.txt
git status --short | tee reports/final-hardening-evidence/03-git-status-before.txt
git diff --stat | tee reports/final-hardening-evidence/04-git-diff-stat-before.txt
```

### Acceptance Criteria

PASS only if:

- evidence folder exists
- branch is recorded
- commit is recorded
- dirty worktree is recorded before changes
- no unrelated repo appears in proof
- command outputs are saved

FAIL if:

- dirty files are hidden
- branch is not confirmed
- command output is missing

---

## 2. Kubernetes / Namespace / Server Access

The previous report failed Kubernetes because the AKS DNS/API endpoint could not resolve. This is a hard closed-beta blocker.

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

kubectl config current-context | tee reports/final-hardening-evidence/10-kube-current-context.txt
kubectl config get-contexts | tee reports/final-hardening-evidence/11-kube-contexts.txt
kubectl cluster-info | tee reports/final-hardening-evidence/12-cluster-info.txt
kubectl get nodes -o wide | tee reports/final-hardening-evidence/13-nodes.txt
kubectl get ns | tee reports/final-hardening-evidence/14-namespaces.txt
kubectl get ns | grep -i sakina | tee reports/final-hardening-evidence/15-sakina-namespaces.txt
```

After namespace is identified:

```bash
export SAKINA_NS=<real-sakina-namespace>

kubectl get all -n "$SAKINA_NS" -o wide | tee reports/final-hardening-evidence/16-sakina-all.txt
kubectl get ingress -n "$SAKINA_NS" -o wide | tee reports/final-hardening-evidence/17-sakina-ingress.txt
kubectl get secrets -n "$SAKINA_NS" | tee reports/final-hardening-evidence/18-sakina-secrets-list.txt
kubectl get configmap -n "$SAKINA_NS" | tee reports/final-hardening-evidence/19-sakina-configmaps.txt
kubectl get events -n "$SAKINA_NS" --sort-by=.lastTimestamp | tail -100 | tee reports/final-hardening-evidence/20-sakina-events.txt
```

### Acceptance Criteria

PASS only if:

- `kubectl cluster-info` exits `0`
- nodes are visible
- Sakina namespace is identified
- backend/API pods are visible
- no `CrashLoopBackOff`
- no `ImagePullBackOff`
- no `ErrImagePull`
- ingress/service endpoint exists
- readiness/liveness probes pass
- all evidence files exist

FAIL if:

- DNS lookup fails
- context points to wrong project
- namespace is missing
- only local proof is provided
- server proof is unavailable

---

## 3. Docker Compose API Image Build

The previous report says the API image build timed out. This must be fixed.

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

docker compose -f sakina-infra/docker-compose.yml config | tee reports/final-hardening-evidence/30-compose-config.txt

docker compose -f sakina-infra/docker-compose.yml build --no-cache api 2>&1 | tee reports/final-hardening-evidence/31-compose-api-build.txt

docker compose -f sakina-infra/docker-compose.yml up -d 2>&1 | tee reports/final-hardening-evidence/32-compose-up.txt

docker compose -f sakina-infra/docker-compose.yml ps | tee reports/final-hardening-evidence/33-compose-ps.txt

docker compose -f sakina-infra/docker-compose.yml logs --tail=200 api | tee reports/final-hardening-evidence/34-compose-api-logs.txt

curl -fsS http://localhost:8000/health | tee reports/final-hardening-evidence/35-compose-health.txt
curl -fsS http://localhost:8000/health/ready | tee reports/final-hardening-evidence/36-compose-ready.txt
curl -fsS http://localhost:8000/health/observability | tee reports/final-hardening-evidence/37-compose-observability.txt
```

### Acceptance Criteria

PASS only if:

- image builds from scratch with `--no-cache`
- no timeout
- API container starts
- health, readiness, and observability endpoints pass
- logs show no panic, crash, missing env, or fake fallback
- compose does not depend on local WSL-only runtime

FAIL if:

- build times out
- cached-only build is used
- API works only outside Docker
- readiness is faked
- logs hide errors

---

## 4. Auth / JWT / Refresh Token

Refresh tokens were previously issued but no refresh endpoint was implemented. This must be fixed.

Required endpoints:

```text
POST /auth/refresh
POST /api/auth/refresh
```

Required behaviour:

- issue access token and refresh token
- rotate refresh token
- revoke old refresh token after refresh
- reject reused refresh token
- reject expired refresh token
- reject logout-revoked token
- update Flutter client to use refresh safely
- use secure token storage only

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/auth-live-proof.sh 2>&1 | tee reports/final-hardening-evidence/40-auth-live-proof-after-refresh.txt
bash scripts/sakina/auth-refresh-proof.sh 2>&1 | tee reports/final-hardening-evidence/41-auth-refresh-proof.txt
```

### Acceptance Criteria

PASS only if:

- refresh endpoint exists
- token rotation works
- old refresh token cannot be reused
- invalid refresh token returns `401`
- logout-revoked token returns `401`
- frontend uses refresh flow
- tokens are not stored insecurely
- DB proves revocation/rotation

FAIL if:

- refresh token is issued but unused
- same refresh token remains valid forever
- endpoint returns static success
- only happy path is tested

---

## 5. LLM and Embedding Provider

Choose one path.

### Path A — Live AI Enabled

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/llm-provider-live-proof.sh 2>&1 | tee reports/final-hardening-evidence/50-llm-provider-live-proof.txt
bash scripts/sakina/embedding-provider-live-proof.sh 2>&1 | tee reports/final-hardening-evidence/51-embedding-provider-live-proof.txt
bash scripts/sakina/rag-live-answer-proof.sh 2>&1 | tee reports/final-hardening-evidence/52-rag-live-answer-proof.txt
```

PASS only if:

- real provider request succeeds
- real embedding vector is produced
- vector dimension matches Qdrant collection
- answer is generated using retrieved sources
- answer includes source/citation IDs
- Islamic safety validates final answer
- no mock/stub/fallback provider is used

### Path B — AI Disabled

If no provider is available, mark:

```text
LLM: SAFE DISABLED
EMBEDDINGS: SAFE DISABLED
RAG ANSWERS: SAFE DISABLED
AI CHAT: SAFE DISABLED
```

PASS only if:

- frontend hides live AI claims
- backend fails closed
- app does not advertise unavailable AI features

FAIL if:

- provider is disabled but AI is reported complete
- static text is presented as live generation
- citations are fabricated

---

## 6. RAG / Qdrant / Hybrid Search

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

curl -fsS http://localhost:6333/collections | tee reports/final-hardening-evidence/60-qdrant-collections.txt

bash scripts/sakina/qdrant-vector-proof.sh 2>&1 | tee reports/final-hardening-evidence/61-qdrant-vector-proof.txt
bash scripts/sakina/hybrid-search-proof.sh 2>&1 | tee reports/final-hardening-evidence/62-hybrid-search-proof.txt
bash scripts/sakina/rag-citation-proof.sh 2>&1 | tee reports/final-hardening-evidence/63-rag-citation-proof.txt
```

### Acceptance Criteria

PASS only if:

- collection exists
- collection has real vectors
- at least 10 real Islamic chunks exist
- chunks have source metadata
- real query embedding is generated
- vector search returns ranked chunks
- lexical search returns ranked chunks
- hybrid search merges and ranks results
- final answer cites retrieved chunks
- unsupported claims fail closed

FAIL if:

- Qdrant collection is empty
- embeddings are fake
- citations are fabricated
- answer ignores retrieved chunks

---

## 7. Graph RAG

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev \
  psql -U sakina_user -d sakina \
  -c "SELECT COUNT(*) AS entities FROM sakina_ai.knowledge_graph_entities; SELECT COUNT(*) AS edges FROM sakina_ai.knowledge_graph_edges;" \
  | tee reports/final-hardening-evidence/70-graph-counts.txt

bash scripts/sakina/graph-rag-live-proof.sh 2>&1 | tee reports/final-hardening-evidence/71-graph-rag-live-proof.txt
```

### Acceptance Criteria

PASS only if:

- graph traversal runs during real question
- starting entity is found
- graph neighbours are found
- graph context enters RAG/Brain trace
- final answer uses graph context
- missing entity fails cleanly

FAIL if:

- graph tables merely exist
- graph traversal is not called
- graph output is not used
- proof is only SQL count

---

## 8. Brain Mother Algorithm

Every answer must pass through:

```text
Request
→ Auth/User Context
→ Subscription/Entitlement Check
→ Safety Policy
→ Intent Classification
→ Memory Permission Check
→ RAG/Graph RAG/Tool Routing
→ LLM Provider Routing
→ Citation Validation
→ Islamic Safety Validation
→ Response
→ Observability Trace
→ Audit Log
```

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/brain-routing-proof.sh 2>&1 | tee reports/final-hardening-evidence/80-brain-routing-proof.txt
bash scripts/sakina/brain-trace-db-proof.sh 2>&1 | tee reports/final-hardening-evidence/81-brain-trace-db-proof.txt
bash scripts/sakina/brain-bypass-negative-proof.sh 2>&1 | tee reports/final-hardening-evidence/82-brain-bypass-negative-proof.txt
```

### Acceptance Criteria

PASS only if:

- every AI route calls Brain
- trace has required stages
- DB stores trace
- direct bypass attempts fail
- unsafe answer is blocked
- unentitled feature is blocked
- route grep confirms no direct LLM bypass

FAIL if:

- only one route uses Brain
- traces are static
- LLM can be called directly
- safety is optional

---

## 9. Multimodal

Multimodal must be either fully live or fully hidden.

### If disabled

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/multimodal-disabled-proof.sh 2>&1 | tee reports/final-hardening-evidence/90-multimodal-disabled-proof.txt
```

PASS only if:

- no upload UI is visible in beta build
- no OCR/STT/vision claim is visible
- backend rejects multimodal endpoint with controlled disabled response
- no unnecessary camera/mic/file permissions exist

### If enabled

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/multimodal-live-proof.sh 2>&1 | tee reports/final-hardening-evidence/91-multimodal-live-proof.txt
```

PASS only if:

- real file upload works
- invalid type rejected
- oversized file rejected
- private storage is proven
- OCR/STT/vision provider returns real result where claimed
- user A cannot access user B file
- Brain and safety validation run

FAIL if:

- UI exists but backend disabled
- backend accepts files but does nothing
- storage is public
- isolation is untested

---

## 10. Payments / Entitlements

Payments must be live or excluded.

### If excluded

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/payments-disabled-proof.sh 2>&1 | tee reports/final-hardening-evidence/100-payments-disabled-proof.txt
```

PASS only if:

- no payment UI is active
- no subscription claim is shown
- backend payment routes fail closed
- no fake Stripe success exists

### If enabled

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/payments-live-proof.sh 2>&1 | tee reports/final-hardening-evidence/101-payments-live-proof.txt
```

PASS only if:

- checkout session is created
- webhook signature is verified
- event stored idempotently
- entitlement updates correctly
- duplicate webhook does not duplicate entitlement
- failed payment blocks entitlement
- user A cannot use user B entitlement

FAIL if:

- payment success is fake
- webhook signature is skipped
- entitlement is hardcoded

---

## 11. RLS / User Isolation

Run local:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/db-user-isolation-proof.sh 2>&1 | tee reports/final-hardening-evidence/110-local-db-user-isolation-proof.txt
```

Run server if Kubernetes is reachable:

```bash
export SAKINA_NS=<real-sakina-namespace>

bash scripts/sakina/server-db-user-isolation-proof.sh 2>&1 | tee reports/final-hardening-evidence/112-server-db-user-isolation-proof.txt
```

### Acceptance Criteria

PASS only if:

- user A can create data
- user B cannot read/update user A data
- unauthenticated access fails
- all user-owned tables have RLS
- policies are listed and reviewed
- server DB proof exists where server is available

FAIL if:

- only table counts are shown
- same user is used twice
- local proof is presented as server proof

---

## 12. Islamic Safety

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/islamic-safety-regression.sh 2>&1 | tee reports/final-hardening-evidence/120-islamic-safety-local-proof.txt
bash scripts/sakina/islamic-safety-live-llm-proof.sh 2>&1 | tee reports/final-hardening-evidence/121-islamic-safety-live-llm-proof.txt
```

Test:

- halal/haram question
- sensitive fatwa question
- sectarian unsafe question
- crisis/self-harm religious question
- hallucination trap
- citation-required answer
- unsupported answer

### Acceptance Criteria

PASS only if:

- local rules pass
- live LLM answer passes if LLM enabled
- unsupported fatwa is blocked or deferred
- sectarian unsafe content is blocked
- citation requirement is enforced
- safety result appears in trace

FAIL if:

- only static regression passes
- LLM provider disabled but live safety is claimed
- unsafe answer is generated

---

## 13. Mobile Closed Beta Release Build

Run:

```bash
cd /mnt/f/SakinaAL/sakina-frontend || exit 1

flutter clean
flutter pub get
flutter analyze
flutter test

flutter build apk --release 2>&1 | tee ../reports/final-hardening-evidence/130-flutter-release-apk-build.txt
flutter build appbundle --release 2>&1 | tee ../reports/final-hardening-evidence/131-flutter-release-aab-build.txt

ls -lah build/app/outputs/flutter-apk/ | tee ../reports/final-hardening-evidence/132-apk-files.txt
ls -lah build/app/outputs/bundle/release/ | tee ../reports/final-hardening-evidence/133-aab-files.txt
```

Scan release config:

```bash
cd /mnt/f/SakinaAL || exit 1

grep -RInE "localhost|127.0.0.1|10.0.2.2|demo-token|test-token|fake|mock|stub|SAKINA_API_TOKEN" sakina-frontend/lib sakina-frontend/android sakina-frontend/ios \
  | tee reports/final-hardening-evidence/134-mobile-release-fake-scan.txt
```

### Acceptance Criteria

PASS only if:

- Flutter analyze passes
- Flutter tests pass
- release APK builds
- release AAB builds
- release build uses real staging/beta API
- no static token exists
- no demo bootstrap exists
- disabled features are hidden
- permissions match enabled features

FAIL if:

- debug APK only
- release points to localhost
- fake token remains
- disabled feature UI remains active

---

## 14. Remote CI/CD

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

gh auth status | tee reports/final-hardening-evidence/140-gh-auth-status.txt
gh workflow list --repo serverax/muslimai | tee reports/final-hardening-evidence/141-gh-workflow-list.txt

grep -RInE "continue-on-error:\s*true|echo.*PASS|echo.*passed|exit 0|ALLOW_FAKE|fake.*pass|stub.*pass|mock.*pass|\|\| true" .github scripts sakina-infra \
  | tee reports/final-hardening-evidence/142-ci-fake-pass-scan.txt
```

Trigger workflows:

```bash
gh workflow run <workflow-name.yml> --repo serverax/muslimai --ref qa-security-hardening

sleep 10

gh run list --repo serverax/muslimai --branch qa-security-hardening --limit 10 \
  | tee reports/final-hardening-evidence/143-gh-run-list.txt

gh run view <run-id> --repo serverax/muslimai --log \
  | tee reports/final-hardening-evidence/144-gh-run-log.txt
```

### Acceptance Criteria

PASS only if:

- remote workflow runs
- run completes successfully
- run SHA matches branch commit
- required jobs fail on real failures
- fake-pass scan is reviewed
- no required check has `continue-on-error: true`
- deploy job proves image build/push/deployment

FAIL if:

- only local tests run
- workflow fails
- workflow skipped required checks
- fake pass scan is ignored

---

## 15. Security Hardening

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/security-regression.sh 2>&1 | tee reports/final-hardening-evidence/150-security-regression.txt
bash scripts/sakina/secret-leak-proof.sh 2>&1 | tee reports/final-hardening-evidence/151-secret-leak-proof.txt
bash scripts/sakina/rate-limit-proof.sh 2>&1 | tee reports/final-hardening-evidence/152-rate-limit-proof.txt
bash scripts/sakina/cors-proof.sh 2>&1 | tee reports/final-hardening-evidence/153-cors-proof.txt
bash scripts/sakina/security-headers-proof.sh 2>&1 | tee reports/final-hardening-evidence/154-security-headers-proof.txt
```

### Acceptance Criteria

PASS only if:

- bad password rejected
- missing JWT rejected
- revoked JWT rejected
- cross-user access rejected
- invalid upload rejected
- rate limiting works
- CORS is restricted in production
- secrets are not leaked
- security headers exist
- logs mask secrets

FAIL if:

- only happy path tested
- CORS wildcard in production
- revoked token works
- secrets appear in logs

---

## 16. Observability / Audit / Trace

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/observability-proof.sh 2>&1 | tee reports/final-hardening-evidence/160-observability-proof.txt
bash scripts/sakina/audit-log-proof.sh 2>&1 | tee reports/final-hardening-evidence/161-audit-log-proof.txt
bash scripts/sakina/outbox-proof.sh 2>&1 | tee reports/final-hardening-evidence/162-outbox-proof.txt
```

### Acceptance Criteria

PASS only if:

- health/readiness/observability endpoints return real status
- trace DB row is created
- audit DB row is created
- outbox row is created where used
- logs do not expose PII/secrets
- error path is logged safely

FAIL if:

- endpoints are static only
- trace is not persisted
- audit log is missing

---

## 17. Store Readiness

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/store-readiness-proof.sh 2>&1 | tee reports/final-hardening-evidence/170-store-readiness-proof.txt
```

### Acceptance Criteria

PASS only if:

- release APK exists
- release AAB exists
- privacy policy exists
- terms exist
- account deletion exists
- data deletion flow exists
- permissions match enabled features
- disabled features are not advertised
- no localhost in release config

FAIL if:

- debug APK only
- no account deletion
- privacy policy missing
- release app points to localhost

---

## 18. Anti-Fake Global Scanner

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

grep -RInE "TODO|FIXME|placeholder|coming soon|mock|stub|fake|demo|dummy|test-token|demo-token|hardcoded|not implemented|safe disabled|configured_or_disabled_closed|ALLOW_FAKE|continue-on-error:\s*true|echo.*PASS|echo.*passed|\|\| true" \
  sakina-backend sakina-frontend sakina-infra scripts .github \
  | tee reports/final-hardening-evidence/180-global-anti-fake-scan.txt
```

Create:

```text
reports/final-hardening-evidence/181-global-anti-fake-scan-review.md
```

Classify every hit:

```text
test-only acceptable
production blocker
fixed
safe-disabled and hidden
false positive
```

### Acceptance Criteria

PASS only if:

- scan output exists
- every hit is reviewed
- production blockers are fixed
- no fake pass remains
- no demo bootstrap remains
- no placeholder provider is reported as live

FAIL if:

- scan is skipped
- hits are ignored
- fake/stub/mock remains in production path

---

## 19. Final Closed-Beta Gate

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/final-closed-beta-gate.sh 2>&1 | tee reports/final-hardening-evidence/190-final-closed-beta-gate.txt
```

This gate must run:

- backend tests
- auth proof
- refresh proof
- DB/RLS proof
- memory ownership proof
- local runtime proof
- Docker Compose build proof
- Kubernetes proof
- LLM/embedding proof or disabled-hidden proof
- RAG proof
- Graph RAG proof
- Islamic safety proof
- security regression
- Flutter analyze/test
- release APK/AAB build
- CI fake-pass scan
- store readiness scan
- final wiring gate
- final new technologies gate

### Acceptance Criteria

PASS only if:

- one command runs all required checks
- exit code is `0`
- failures stop the gate
- each sub-check writes evidence
- final summary uses real exit codes
- no fake PASS text is used

FAIL if:

- gate skips major blockers
- gate ignores failures
- gate passes while Kubernetes/CI/release build is missing

---

# Part 2 — Backend ↔ Frontend ↔ DB / Function Wiring

## 20. Backend ↔ Frontend Wiring Matrix

Create:

```text
reports/final-hardening-evidence/230-frontend-backend-wiring-matrix.md
```

Required table:

```text
Frontend Screen / Feature
File Path
User Action
API Service Method
Backend Endpoint
Backend Handler
DB Tables Used
Auth Required
Status
Evidence
```

Minimum required areas:

- registration
- login
- logout
- refresh token
- auth/me
- onboarding
- profile
- chat
- Islamic answer
- memory save
- memory read
- user settings
- subscription/entitlement
- payment screen if visible
- multimodal/upload if visible
- notifications if visible
- dashboard/home
- error handling
- account deletion
- privacy/terms links
- offline/no-network handling
- app startup token restore
- app startup token expiry handling

### Acceptance Criteria

PASS only if:

- every visible frontend feature is listed
- every feature has a real backend endpoint
- every endpoint has a real handler
- every handler has real DB/function/provider wiring where required
- auth-required routes reject missing/invalid JWT
- every frontend service method maps to backend route
- disabled features are hidden or visibly unavailable
- evidence file exists

FAIL if:

- any button does nothing
- any button only changes frontend state
- service method returns static data
- endpoint is missing
- backend route exists but frontend does not call it
- backend route exists but has no DB/function effect

---

## 21. Frontend Static/Fake Wiring Scanner

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

grep -RInE "mock|fake|stub|demo|dummy|placeholder|TODO|FIXME|coming soon|hardcoded|sample|test-token|demo-token|localhost|127.0.0.1|10.0.2.2|Future.delayed|return .*\\[|return .*\\{|static const|Fake|Mock|Stub|Demo" \
  sakina-frontend/lib sakina-frontend/android sakina-frontend/ios \
  | tee reports/final-hardening-evidence/231-frontend-fake-wiring-scan.txt
```

Create:

```text
reports/final-hardening-evidence/232-frontend-fake-wiring-scan-review.md
```

Classify each hit:

```text
removed
test-only acceptable
production blocker
disabled-hidden
false positive
```

### Acceptance Criteria

PASS only if:

- scan output exists
- every hit is reviewed
- no production path uses fake/mock/stub/demo data
- no release config points to localhost
- no static token exists
- no demo bootstrap exists
- no screen uses fake loading completion as success
- no visible feature has placeholder behaviour

FAIL if:

- grep hits are ignored
- frontend fake data remains
- release build has localhost
- disabled feature remains visible

---

## 22. Frontend API Contract Verification

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/frontend-api-contract-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/233-frontend-api-contract-proof.txt
```

The script must prove:

1. backend starts
2. frontend API base URL resolves correctly
3. registration request from frontend contract works
4. login request from frontend contract works
5. refresh request from frontend contract works
6. authenticated request works
7. logout request works
8. revoked token is rejected
9. frontend error mapping handles `400`, `401`, `403`, `404`, `409`, `422`, `429`, `500`
10. response JSON fields match frontend models

### Acceptance Criteria

PASS only if:

- request payloads match backend contracts
- response fields match frontend models
- auth headers are sent correctly
- refresh flow works
- logout clears secure storage and revokes server session
- bad responses are handled
- secrets are masked

FAIL if:

- frontend expects missing fields
- backend returns fields frontend ignores incorrectly
- frontend hides failures
- auth header is missing

---

## 23. Mobile App to Backend to DB E2E

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/mobile-to-backend-to-db-e2e-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/234-mobile-to-backend-to-db-e2e-proof.txt
```

Required flow:

```text
Flutter UI/service
→ HTTP request
→ backend route
→ auth middleware
→ handler
→ service/function
→ DB write/read
→ response
→ frontend model parse
→ frontend state update
```

Minimum journeys:

- register user
- login user
- load current user
- send chat message
- receive brain-routed response
- save memory
- read memory
- update profile/settings
- logout
- verify token revoked
- verify data persisted in DB
- verify another user cannot read the data

### Acceptance Criteria

PASS only if:

- every journey uses real HTTP
- every journey touches backend
- every DB write is verified by SQL
- frontend model parsing is verified
- state is updated from backend response
- cross-user isolation is tested
- unauthenticated access is tested

FAIL if:

- journey is local UI only
- fake service is used
- DB is not checked
- same user is used for isolation test

---

## 24. Backend Route ↔ Handler ↔ Service ↔ DB Matrix

Create:

```text
reports/final-hardening-evidence/240-backend-route-handler-db-matrix.md
```

Required table:

```text
Endpoint
HTTP Method
Auth Required
Handler File
Service/Function File
DB Tables
Migration File
RLS Policy
Positive Test
Negative Test
Status
```

Minimum endpoints:

- `/health`
- `/health/ready`
- `/health/observability`
- `/auth/register`
- `/auth/login`
- `/auth/refresh`
- `/auth/logout`
- `/auth/me`
- `/api/auth/register`
- `/api/auth/login`
- `/api/auth/refresh`
- `/api/auth/logout`
- `/api/auth/me`
- chat/brain endpoint
- memory create/read/update/delete endpoints
- profile/settings endpoints
- RAG endpoints
- Graph RAG endpoints
- payment endpoints if enabled
- multimodal endpoints if enabled
- account deletion endpoint
- admin/internal endpoints if any

### Acceptance Criteria

PASS only if:

- every route is listed
- every route has exact handler file
- every handler maps to service/function
- every service/function maps to DB or provider
- every DB table maps to migration
- every user-owned table has RLS
- every route has positive and negative test
- route matrix matches actual code

FAIL if:

- route exists but no handler proof
- handler exists but no service/function proof
- DB table has no migration
- route has only happy-path test

---

## 25. Backend Dead Route / Unused Handler Scanner

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

grep -RInE "route\\(|\\.route|Router|scope|service\\(|web::|axum|actix|warp|rocket" sakina-backend/src \
  | tee reports/final-hardening-evidence/241-backend-routes-scan.txt

grep -RInE "pub async fn|async fn|pub fn|fn " sakina-backend/src/handlers sakina-backend/src/services \
  | tee reports/final-hardening-evidence/242-backend-functions-scan.txt
```

Create:

```text
reports/final-hardening-evidence/243-backend-unused-route-handler-review.md
```

### Acceptance Criteria

PASS only if:

- all routes are discovered from code
- all handlers are discovered from code
- unused handlers are identified
- dead routes are identified
- missing tests are listed

FAIL if:

- manually guessed route list is used
- unused handlers are ignored
- registered routes are not tested

---

## 26. Database ↔ Function Wiring Matrix

Create:

```text
reports/final-hardening-evidence/250-db-function-wiring-matrix.md
```

Required table:

```text
DB Object
Type
Schema
Migration File
Used By Backend Function
Used By Endpoint
RLS Enabled
Policy Name
Test Script
Status
```

Include:

- all tables
- all views
- all DB functions
- all triggers
- all indexes used for critical queries
- all RLS policies
- all queues/outbox tables
- all audit tables
- all knowledge graph tables
- all RAG tables
- all payment tables
- all memory tables
- all user/profile/auth/session tables

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "
  SELECT schemaname, tablename, rowsecurity
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog','information_schema')
  ORDER BY schemaname, tablename;
  " | tee reports/final-hardening-evidence/251-db-tables-rls.txt

docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "
  SELECT n.nspname AS schema, p.proname AS function_name
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  ORDER BY schema, function_name;
  " | tee reports/final-hardening-evidence/252-db-functions.txt

docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "
  SELECT event_object_schema, event_object_table, trigger_name, action_timing, event_manipulation
  FROM information_schema.triggers
  ORDER BY event_object_schema, event_object_table, trigger_name;
  " | tee reports/final-hardening-evidence/253-db-triggers.txt

docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "
  SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
  FROM pg_policies
  ORDER BY schemaname, tablename, policyname;
  " | tee reports/final-hardening-evidence/254-db-policies.txt
```

### Acceptance Criteria

PASS only if:

- every DB object is listed
- every DB object is mapped to backend use or marked unused
- every user-owned table has RLS
- every RLS policy is listed
- every trigger/function is tested
- migrations run from empty DB
- no orphan table is called complete

FAIL if:

- DB table exists but no backend uses it
- backend calls missing table
- trigger/function exists but is not tested
- policy is too broad

---

## 27. DB Function and Trigger Runtime Proof

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/db-functions-triggers-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/255-db-functions-triggers-proof.txt
```

### Acceptance Criteria

PASS only if:

- each DB function is executed or marked unused
- each trigger fires through real insert/update/delete
- audit trigger creates audit row
- `updated_at` trigger updates timestamp
- outbox trigger creates event where required
- invalid input fails safely
- no normal runtime path requires superuser

FAIL if:

- existence is treated as proof
- no mutation is performed
- invalid input is not tested

---

## 28. Migration From Empty DB

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/migration-empty-db-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/256-migration-empty-db-proof.txt
```

Must:

1. create fresh temporary DB
2. run all migrations from zero
3. verify schema
4. verify tables/functions/triggers/policies
5. run core backend tests against fresh DB
6. drop temporary DB after proof

### Acceptance Criteria

PASS only if:

- migrations run from empty DB
- no manual SQL patch is required
- all required DB objects exist
- backend starts against migrated DB
- core tests pass against migrated DB
- proof does not use existing dirty DB

FAIL if:

- only current DB is checked
- migrations need manual fix
- tests are not run against fresh DB

---

## 29. End-to-End Trace ID

Every user-facing request must have a trace ID.

Required flow:

```text
Frontend request
→ X-Request-ID or generated request ID
→ backend logs same ID
→ Brain trace stores same ID
→ audit log stores same ID where relevant
→ response returns same ID
→ frontend error/reporting stores same ID
```

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/end-to-end-trace-id-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/260-end-to-end-trace-id-proof.txt
```

### Acceptance Criteria

PASS only if:

- same trace ID appears in frontend request/response, backend logs, DB trace, and audit where relevant
- error path also includes trace ID

FAIL if:

- trace exists only in logs
- DB trace is missing
- different IDs are used for same request

---

## 30. API Schema / Contract Lock

Run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/api-schema-contract-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/270-api-schema-contract-proof.txt
```

### Acceptance Criteria

PASS only if:

- API schema exists
- schema is generated or verified from backend source
- frontend models are checked against schema
- missing endpoint fails script
- mismatched field fails script
- CI runs this check

FAIL if:

- schema is manually invented
- schema is outdated
- frontend models are not checked

---

## 31. Final Wiring Gate

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/final-wiring-gate.sh 2>&1 \
  | tee reports/final-hardening-evidence/280-final-wiring-gate.txt
```

Must run:

- frontend fake wiring scan
- frontend API contract proof
- mobile-to-backend-to-DB proof
- backend route-handler-DB matrix validation
- unused route/handler scan
- DB object/function/trigger scan
- DB function/trigger proof
- migration from empty DB proof
- trace ID proof
- API schema contract proof

### Acceptance Criteria

PASS only if:

- all sub-checks run
- all sub-checks exit `0`
- failed sub-check stops gate
- evidence paths are printed
- gate is included in `final-closed-beta-gate.sh`

FAIL if:

- gate only creates report
- gate ignores failed checks
- gate uses `|| true`

---

# Part 3 — New Technologies Implementation Order

Every technology must be real in code, wired, tested, observable, and either live or hidden.

## 32. New Technologies Required List

The following technologies must be included in the master matrix:

1. Brain Mother Algorithm / Central AI Orchestrator
2. Agentic AI Workflow Engine
3. RAG
4. Graph RAG / Knowledge Graph
5. Hybrid Search
6. Semantic Cache
7. Memory Engine
8. Context Compression
9. AI Router / Model Router
10. Evaluation AI / Quality Gate
11. MCP Connectors / Tool Connector Layer
12. Multimodal AI
13. WASM Module
14. Qdrant Vector Database
15. Event Bus / Queue / Outbox
16. Realtime / Notifications
17. Feature Flags / Entitlements
18. Policy-as-Code / Islamic Safety Rules
19. Citation and Hallucination Validator
20. Observability Stack
21. Secrets Management
22. Security Layer / Zero-Trust API Guard
23. Payments / Subscriptions / Entitlements
24. Offline Mode / Local Resilience
25. Arabic-English / RTL / Internationalisation
26. App Store Compliance Technology Gate

---

## 33. New Technologies Master Matrix

Create:

```text
reports/final-hardening-evidence/560-new-technologies-master-matrix.md
```

Required table:

```text
Technology
Status
Code Path
Backend Wired
Frontend Wired
DB/Storage Wired
Brain Wired
Positive Test
Negative Test
CI Wired
Evidence File
Blocking?
```

### Acceptance Criteria

PASS only if:

- every technology is listed
- every technology has evidence file
- every technology has honest status
- disabled technologies are marked `SAFE DISABLED`
- partial technologies are marked `PARTIAL`
- live technologies have runtime proof
- user-facing technologies have frontend proof
- data technologies have DB/storage proof
- AI technologies have Brain trace proof
- CI runs proof scripts

FAIL if:

- technology is mentioned but not listed
- no evidence file
- no negative test
- no frontend proof for visible feature
- no DB proof where needed
- disabled feature marked complete

---

## 34. Brain Mother Algorithm / Central AI Orchestrator

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-brain-orchestrator-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/300-tech-brain-orchestrator-proof.txt
```

PASS only if:

- every AI route calls Brain
- every chat answer has persisted trace
- every trace includes mandatory stages
- direct LLM calls from handlers are blocked
- memory writes cannot bypass permission checks
- RAG cannot bypass Brain
- unsafe Islamic answer is blocked
- non-entitled feature is blocked
- trace ID links frontend/backend/DB/logs

FAIL if:

- Brain is only a prompt
- Brain is used by only one route
- static traces exist
- route calls LLM directly

---

## 35. Agentic AI Workflow Engine

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-agentic-workflow-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/310-tech-agentic-workflow-proof.txt
```

Required controlled agents:

- Islamic guidance assistant
- user memory assistant
- RAG retrieval assistant
- safety reviewer
- citation verifier
- profile/settings assistant
- subscription/entitlement assistant
- multimodal assistant if enabled
- support/account deletion assistant if enabled

Each agent must have:

- agent ID
- tool allowlist
- tool denylist
- input schema
- output schema
- retry limit
- timeout
- audit log
- trace log
- safe fallback

PASS only if:

- agents are code-defined, not prompt-only
- tool permissions are enforced
- forbidden tool call is blocked
- workflow state is persisted
- retry and timeout are tested
- failed step is recorded
- Brain controls execution

FAIL if:

- agents are only text prompts
- agent can call any function
- no state/audit trace exists

---

## 36. RAG

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-rag-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/320-tech-rag-proof.txt
```

PASS only if:

- ingestion pipeline exists
- real chunks exist
- source metadata exists
- vectors exist in Qdrant
- vector dimension matches provider
- query creates real embedding
- vector search returns results
- lexical search returns results
- hybrid ranking runs
- answer cites retrieved chunks
- unsupported answer fails closed

FAIL if:

- collection empty
- mock embeddings
- static answer
- fabricated citations

---

## 37. Graph RAG / Knowledge Graph

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-graph-rag-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/330-tech-graph-rag-proof.txt
```

PASS only if:

- entity extraction exists
- entity and edge tables have real data
- traversal runs during live question
- traversal result appears in Brain trace
- graph context enters answer generation
- missing entity test fails cleanly
- at least 3 question types are tested

FAIL if:

- graph is only tables
- traversal not called
- graph answer is hardcoded

---

## 38. Hybrid Search

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-hybrid-search-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/340-tech-hybrid-search-proof.txt
```

PASS only if:

- vector result is shown
- lexical result is shown
- merge/ranking is shown
- duplicate removal is shown
- ranking score is stored/logged
- vector failure fallback is tested
- lexical failure fallback is tested

FAIL if:

- only vector search exists
- only SQL LIKE exists
- no scoring exists
- no failure test exists

---

## 39. Semantic Cache

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-semantic-cache-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/350-tech-semantic-cache-proof.txt
```

PASS only if:

- first request is cache miss
- second similar request is cache hit
- user isolation is enforced
- TTL exists
- source change invalidates cache
- cached answer still passes safety validation
- cache poisoning protection exists
- hit/miss metrics exist

FAIL if:

- cache is global across users
- safety validation is skipped
- TTL/invalidation missing
- sensitive data stored raw

---

## 40. Memory Engine

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-memory-engine-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/360-tech-memory-engine-proof.txt
```

PASS only if:

- explicit consent logic exists
- user A can create/read own memory
- user B cannot read user A memory
- unauthenticated access fails
- memory write requires Brain permission
- sensitive memory is blocked or requires consent
- memory can be deleted
- deleted memory is not retrieved
- frontend reflects backend state

FAIL if:

- memory is frontend-only
- memory is global
- cross-user read works
- memory cannot be deleted

---

## 41. Context Compression

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-context-compression-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/370-tech-context-compression-proof.txt
```

PASS only if:

- before/after size is shown
- size is reduced
- source IDs are preserved
- safety flags are preserved
- user intent is preserved
- answer after compression cites correct sources
- compression failure falls back safely
- trace shows compression step

FAIL if:

- compression is only prompt text
- source IDs are lost
- meaning changes
- safety warning is removed

---

## 42. AI Router / Model Router

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-ai-router-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/380-tech-ai-router-proof.txt
```

PASS only if:

- router is called by Brain
- routing decision is logged
- different task types route differently
- disabled provider is not selected
- provider failure triggers fallback or safe failure
- high-risk Islamic questions use stricter route
- Arabic and English routing are tested
- no route calls provider directly

FAIL if:

- one hardcoded provider is always used
- router exists but is not called
- disabled provider is selected
- no fallback test exists

---

## 43. Evaluation AI / Quality Gate

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-evaluation-ai-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/390-tech-evaluation-ai-proof.txt
```

PASS only if:

- evaluation dataset exists
- at least 25 cases exist
- Islamic safety cases included
- hallucination traps included
- citation-required cases included
- scoring output is produced
- threshold is enforced
- CI fails if score drops
- failed cases are listed

FAIL if:

- manual only
- fewer than 25 cases
- no hallucination/citation tests
- no threshold
- CI does not run it

---

## 44. MCP Connectors / Tool Connector Layer

If disabled, mark `SAFE DISABLED` and hide.

If enabled, proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-mcp-connectors-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/400-tech-mcp-connectors-proof.txt
```

PASS only if:

- connector registry exists
- Brain controls connector calls
- user permission is checked
- forbidden connector call is blocked
- timeout works
- failure is handled
- secrets are not exposed
- audit log records connector call

FAIL if:

- MCP is docs-only
- connector can be called directly
- no permission/audit exists
- secrets appear in logs

---

## 45. Multimodal AI

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-multimodal-ai-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/410-tech-multimodal-ai-proof.txt
```

PASS only if enabled and:

- upload UI exists
- backend upload endpoint works
- file type validation works
- file size limit works
- storage is private
- OCR/STT/vision provider returns real result where claimed
- user A cannot access user B file
- Brain and safety validation run

If disabled, PASS only if:

- UI is hidden
- backend fails closed
- unnecessary permissions are removed

FAIL if:

- UI exists but backend disabled
- backend accepts files but does nothing
- storage is public

---

## 46. WASM Module

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-wasm-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/420-tech-wasm-proof.txt
```

PASS only if:

- WASM builds from source
- backend loads module
- real request invokes WASM
- output is verified
- bad input fails safely
- fallback works
- Docker build includes WASM
- CI builds WASM

FAIL if:

- WASM merely exists
- dependency unused
- no endpoint invokes it
- Docker skips it

---

## 47. Qdrant Vector DB

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-qdrant-vector-db-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/430-tech-qdrant-vector-db-proof.txt
```

PASS only if:

- collection exists
- vector count is greater than zero
- payload metadata exists
- upsert works
- search works
- delete/reindex works
- wrong dimension is rejected
- readiness depends on Qdrant
- backup/export command exists

FAIL if:

- Qdrant is only reachable
- collection is empty
- wrong vector dimension accepted
- readiness ignores Qdrant failure

---

## 48. Event Bus / Queue / Outbox

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-event-outbox-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/440-tech-event-outbox-proof.txt
```

PASS only if:

- event is written to outbox
- worker processes event
- status changes pending to processed
- failed event retries
- max retry moves to dead-letter
- duplicate event is idempotent
- trace ID is preserved

FAIL if:

- async task is just a log
- no worker exists
- retries not tested
- duplicate creates duplicate side effect

---

## 49. Realtime / Notifications

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-realtime-notifications-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/450-tech-realtime-notifications-proof.txt
```

PASS only if enabled and:

- notification is created by backend event
- frontend receives it
- read/unread state updates DB
- user B cannot receive user A notification
- disconnected client recovers missed notification

If disabled:

- frontend hides it
- backend fails closed

FAIL if:

- notification is frontend-only
- no DB state exists
- cross-user test missing

---

## 50. Feature Flags / Entitlements

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-feature-flags-entitlements-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/460-tech-feature-flags-entitlements-proof.txt
```

PASS only if:

- backend denies disabled feature
- frontend hides disabled feature
- entitled user can access enabled feature
- non-entitled user is blocked
- direct API call is blocked
- denial is logged

FAIL if:

- frontend hides but backend allows
- backend blocks but frontend shows active
- entitlement is hardcoded
- API bypass works

---

## 51. Policy-as-Code / Islamic Safety Rules

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-policy-as-code-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/470-tech-policy-as-code-proof.txt
```

PASS only if:

- policies exist outside prompt text
- policies are versioned
- each policy has test case
- high-risk Islamic question triggers stricter policy
- unsupported fatwa is blocked
- sectarian unsafe content is blocked
- crisis/safety question routes safely
- policy decision appears in trace

FAIL if:

- rules are only prompt text
- no versioning/tests
- unsafe content passes
- policy trace missing

---

## 52. Citation / Hallucination Validator

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-citation-hallucination-validator-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/480-tech-citation-hallucination-validator-proof.txt
```

PASS only if:

- cited source IDs exist
- answer claims map to sources
- unsupported claim is detected
- fabricated citation is rejected
- no-source answer is blocked or caveated
- hallucination trap fails closed
- validator result is stored in trace

FAIL if:

- citations are only text
- source IDs not checked
- fabricated citations pass
- validator is test-only

---

## 53. Observability Stack

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-observability-stack-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/490-tech-observability-stack-proof.txt
```

PASS only if:

- structured log exists
- same trace ID appears in response, log, and DB
- metrics endpoint shows real counters
- readiness fails when DB/Qdrant unavailable
- error path is logged safely
- Kubernetes logs show runtime behaviour
- secrets are masked

FAIL if:

- logs are unstructured only
- metrics are static
- readiness ignores dependencies
- secrets appear in logs

---

## 54. Secrets Management

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-secrets-management-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/500-tech-secrets-management-proof.txt
```

PASS only if:

- repo secret scan passes
- logs mask secrets
- Kubernetes secrets exist
- GitHub secrets exist where required
- app reads secrets from env/secret provider
- no secret value appears in evidence
- fake/default secret rejected in production

FAIL if:

- secret hardcoded
- secret printed
- default secret works in production
- `.env` committed

---

## 55. Zero-Trust API Guard

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-zero-trust-api-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/510-tech-zero-trust-api-proof.txt
```

PASS only if:

- unauthenticated request rejected
- invalid JWT rejected
- revoked JWT rejected
- cross-user read rejected
- cross-user update rejected
- oversized request rejected
- invalid input rejected
- rate limit enforced
- CORS restricted
- security event audited

FAIL if:

- protected route allows missing auth
- revoked token works
- cross-user access works
- no rate limit exists
- CORS wildcard in production

---

## 56. Payments / Subscriptions / Entitlements Technology

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-payments-entitlements-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/520-tech-payments-entitlements-proof.txt
```

PASS only if enabled and:

- checkout session is real
- webhook signature is verified
- duplicate webhook is idempotent
- entitlement is updated in DB
- failed payment blocks entitlement
- user A cannot use user B entitlement
- frontend reads entitlement from backend

If disabled:

- feature is hidden
- backend fails closed

FAIL if:

- payment status is manually set
- webhook signature skipped
- frontend hardcodes premium
- disabled payments shown active

---

## 57. Offline Mode / Local Resilience

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-offline-resilience-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/530-tech-offline-resilience-proof.txt
```

PASS only if:

- offline state is detected
- user is told action is offline/pending
- app does not pretend backend saved data
- queued action syncs after reconnect
- failed sync is shown
- AI answer is not faked offline
- conflict case is handled

FAIL if:

- app shows success while backend unreachable
- offline AI answer is fake
- queued action disappears
- retry proof missing

---

## 58. Arabic-English / RTL / Internationalisation

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-i18n-arabic-english-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/540-tech-i18n-arabic-english-proof.txt
```

PASS only if:

- app switches Arabic/English
- Arabic UI strings exist
- RTL is enabled for Arabic
- Arabic question reaches backend correctly
- Arabic RAG works or fails safely
- Islamic safety works in Arabic
- no mojibake/encoding issue exists
- tests include Arabic input

FAIL if:

- Arabic is only screenshots
- UI strings incomplete
- backend breaks Arabic text
- Arabic safety not tested

---

## 59. App Store Compliance Technology Gate

Proof command:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/tech-store-compliance-proof.sh 2>&1 \
  | tee reports/final-hardening-evidence/550-tech-store-compliance-proof.txt
```

PASS only if:

- release APK exists
- release AAB exists
- privacy policy route/link exists
- terms route/link exists
- account deletion route exists
- data deletion flow exists
- permissions match enabled features
- disabled permissions are removed
- app starts cleanly in release config
- no localhost in release config

FAIL if:

- debug APK only
- no AAB
- account deletion missing
- disabled feature permissions remain
- release app points to localhost

---

## 60. New Technologies Final Gate

Create and run:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/final-new-technologies-gate.sh 2>&1 \
  | tee reports/final-hardening-evidence/570-final-new-technologies-gate.txt
```

This gate must run all proof scripts:

```text
300 Brain Orchestrator
310 Agentic Workflow
320 RAG
330 Graph RAG
340 Hybrid Search
350 Semantic Cache
360 Memory Engine
370 Context Compression
380 AI Router
390 Evaluation AI
400 MCP Connectors
410 Multimodal AI
420 WASM
430 Qdrant
440 Event/Outbox
450 Realtime Notifications
460 Feature Flags/Entitlements
470 Policy-as-Code
480 Citation/Hallucination Validator
490 Observability
500 Secrets
510 Zero-Trust API
520 Payments
530 Offline Resilience
540 Arabic-English
550 Store Compliance
560 New Technologies Matrix
```

### Acceptance Criteria

PASS only if:

- all enabled technologies pass
- all disabled technologies are hidden and fail closed
- all partial technologies are listed as blockers if required for closed beta
- every script exits with real status
- no script uses `|| true`
- no script uses `echo PASS` as proof
- CI/CD runs this gate remotely

FAIL if:

- enabled technology fails
- visible feature is disabled in backend
- script is missing
- script hides failure
- technology is docs-only

---

# Part 4 — Final Report and Final Tables

## 61. Final Report

Create:

```text
/F:/SakinaAL/reports/sakina-final-closed-beta-hard-signoff-v2.md
```

The report must include:

1. Executive verdict
2. Final classification
3. Git branch
4. Git commit
5. Git status before and after
6. Files changed
7. Docker proof
8. Kubernetes proof
9. Auth/JWT/refresh proof
10. DB/RLS/user isolation proof
11. Brain Mother Algorithm proof
12. LLM/embedding proof
13. RAG/hybrid search proof
14. Graph RAG proof
15. Islamic safety proof
16. Multimodal status
17. Payments status
18. Mobile release build proof
19. Store readiness proof
20. CI/CD remote run proof
21. Backend/frontend/DB wiring sign-off
22. New technologies sign-off
23. Anti-fake scan review
24. Remaining blockers
25. Exact owner actions if blocked
26. Final Go/No-Go decision

### Final Report Acceptance Criteria

PASS only if:

- every claim links to command output file
- every evidence file exists
- every feature has honest status
- disabled features are marked disabled
- partial features are marked partial
- no placeholder text
- no image-only proof
- no fake PASS
- final verdict matches evidence

FAIL if:

- report claims ready while Kubernetes is unreachable
- report claims AI ready while provider disabled
- report claims RAG ready without vector proof
- report claims Graph RAG ready without live trace
- report claims mobile ready with debug APK only
- report claims CI/CD ready without remote run
- report claims payments/multimodal ready while disabled
- report hides dirty git status

---

## 62. Final Summary Table Required

The report must include:

| Area | Status | Evidence File | Blocking? |
|---|---|---|---|
| Git baseline | PASS/FAIL | path | yes/no |
| Docker API build | PASS/FAIL | path | yes/no |
| Kubernetes namespace | PASS/FAIL | path | yes/no |
| Backend health | PASS/FAIL | path | yes/no |
| Auth/JWT | PASS/FAIL | path | yes/no |
| Refresh token | PASS/FAIL | path | yes/no |
| RLS/user isolation local | PASS/FAIL | path | yes/no |
| RLS/user isolation server | PASS/FAIL | path | yes/no |
| Brain routing | PASS/FAIL | path | yes/no |
| LLM provider | PASS/FAIL/DISABLED | path | yes/no |
| Embedding provider | PASS/FAIL/DISABLED | path | yes/no |
| RAG/hybrid search | PASS/FAIL | path | yes/no |
| Graph RAG | PASS/FAIL | path | yes/no |
| Islamic safety | PASS/FAIL | path | yes/no |
| Multimodal | PASS/FAIL/DISABLED | path | yes/no |
| Payments | PASS/FAIL/DISABLED | path | yes/no |
| Flutter release APK | PASS/FAIL | path | yes/no |
| Flutter release AAB | PASS/FAIL | path | yes/no |
| Store readiness | PASS/FAIL | path | yes/no |
| Remote CI/CD | PASS/FAIL | path | yes/no |
| Anti-fake scan | PASS/FAIL | path | yes/no |
| Frontend/backend matrix | PASS/FAIL | path | yes/no |
| Frontend fake scan | PASS/FAIL | path | yes/no |
| API contract proof | PASS/FAIL | path | yes/no |
| Mobile-to-backend-to-DB E2E | PASS/FAIL | path | yes/no |
| Backend route-handler-DB matrix | PASS/FAIL | path | yes/no |
| DB function/trigger proof | PASS/FAIL | path | yes/no |
| Empty DB migration proof | PASS/FAIL | path | yes/no |
| End-to-end trace ID proof | PASS/FAIL | path | yes/no |
| Final wiring gate | PASS/FAIL | path | yes/no |
| New technologies matrix | PASS/FAIL | path | yes/no |
| Final new technologies gate | PASS/FAIL | path | yes/no |
| Final closed-beta gate | PASS/FAIL | path | yes/no |

---

## 63. Final Instruction to Agent

Do not send a marketing summary.

Do not say “mostly done.”

Do not say “ready” unless every blocking gate passes.

If anything fails, say:

```text
NOT READY — REAL BLOCKERS REMAIN
```

Then list:

- exact failed command
- exact evidence file
- exact blocker
- exact owner action required
- whether it blocks closed beta

If everything passes, say:

```text
READY FOR CLOSED BETA — HARD EVIDENCE PASSED
```

But only after:

- Docker passes
- Kubernetes passes
- backend/frontend/DB wiring passes
- DB function/trigger proof passes
- RLS passes
- auth/refresh passes
- Brain passes
- LLM/RAG/Graph RAG are live or safely disabled/hidden
- Islamic safety passes
- release APK and AAB build
- store readiness passes
- remote CI/CD passes
- anti-fake scan passes
- final wiring gate passes
- final new technologies gate passes
- final closed-beta gate passes
