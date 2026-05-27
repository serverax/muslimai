# QA/Security Fix Status (2026-05-27)

## Scope And Guardrails

- Branch: `qa-security-hardening`
- Production runtime changes: **none applied from this branch**
- PVC/data deletion: **none**
- Secrets in logs: **none intentionally printed**

## Priority 1 — Security Cleanup

| Item | Status | Notes |
|---|---|---|
| Remove sensitive files from workspace (`sakina-secure-handoff/...`, root kubeconfig, zip) | **FIXED** | Files deleted locally from workspace path. |
| Confirm if those files were committed | **FIXED** | `git rev-list --all -- <path>` returned no commits for all 4 files. |
| Exposure assessment and rotation plan | **FIXED** | No git-history hits for listed files; keep as low confidence "not committed in this repo clone", still rotate if any file was shared externally. |
| Add `.gitignore` protections | **FIXED** | Added ignores for handoff directory/zip, kubeconfig patterns, and local env files. |
| Add secret scanning gate (gitleaks) | **FIXED** | Added `.github/workflows/secret-scan.yml` + `.gitleaks.toml`. |

### Rotation Steps (run only if any credential left controlled boundary)

1. Supabase:
   - Rotate `SUPABASE_SERVICE_ROLE_KEY` in Supabase dashboard.
   - Update Kubernetes secret/env source.
   - Restart backend deployment.
2. Kubernetes access:
   - Revoke/rotate kubeconfig token or user credentials.
   - Issue new least-privilege kubeconfig.
3. GHCR/deployment secrets:
   - Rotate `ghcr-creds` token if pull secret exposure suspected.
   - Recreate Kubernetes docker-registry secret.

## Priority 2 — Backend Security/Correctness

| Item | Status | Notes |
|---|---|---|
| Replace `DefaultHasher` checksum | **FIXED** | `sync.rs` now uses SHA-256 (`sha2`). |
| Deterministic crypto digest tests | **FIXED** | Added test with known SHA-256 vector for `abc`. |
| Rate limiting on public waitlist routes | **FIXED** | Added in-memory per-requester limiter used by `/waitlist` and `/v1/waitlist`. |
| Strong waitlist validation + safe errors | **FIXED** | Added max length constraints and generic validation errors. |
| Ensure `SUPABASE_SERVICE_ROLE_KEY` backend-only | **FIXED** | Added frontend CI guard to fail if key string appears in frontend source/tests. |

## Priority 3 — API Contract Fixes

| Item | Status | Notes |
|---|---|---|
| `/v1/users/pubkey` contract mismatch | **FIXED** | Implemented `GET /v1/users/pubkey` from `SAKINA_SERVER_PUBKEY`. |
| Complete user handlers or disable clearly | **FIXED** | User create/get now explicit `501 Not Implemented` with clear phase message. |
| Remove production-looking stubs | **FIXED** | Stub success responses removed; replaced with explicit disabled responses. |

## Priority 4 — Frontend Release Readiness

| Item | Status | Notes |
|---|---|---|
| Android v1 embedding build issue | **FIXED** | Regenerated Android scaffold (`flutter create --platforms=android .`), release APK now builds. |
| Production API URL env-driven | **FIXED** | `ApiConfig.baseUrl` now from `SAKINA_API_BASE_URL` with production default. |
| Waitlist UX test | **FIXED** | Added API-level waitlist flow test in `api_service_test.dart`. |
| Basic accessibility/localization checks | **FIXED** | Added semantics labels + widget tests for Arabic text and control semantics. |

## Priority 5 — Kubernetes/Deployment Cleanup

| Item | Status | Notes |
|---|---|---|
| Separate active vs legacy manifests | **FIXED** | Added active path under `sakina-infra/manifests/sakina-prod/`. |
| Mark legacy manifests/scripts clearly | **FIXED** | Marked `sakina-api-deployment.yaml` as legacy and added manifest README. |
| Remove floating `latest` usage where possible | **FIXED** | Pinned Qdrant tag and removed `latest` in compose local service tags. |
| Add securityContext/non-root hardening | **FIXED** | Added hardening in active backend/frontend and data manifests. |
| Add requests/limits where missing | **FIXED** | Added resources for active and data service manifests. |
| Keep Redis PVC untouched | **FIXED** | No Redis PVC/data changes made. |

## Priority 6 — CI/CD Hardening

| Item | Status | Notes |
|---|---|---|
| Remove `latest` image usage in CI | **FIXED** | Backend CI local image tag switched to `${{ github.sha }}`. |
| Align infra CI with active prod path | **FIXED** | Infra/image workflows now validate `sakina-prod` manifests. |
| Add secret scanning | **FIXED** | Added gitleaks workflow. |
| Add dependency/security scanning | **FIXED** | Added `dependency-scan.yml` (cargo-audit + Trivy FS scan). |
| Add post-deploy smoke stage | **FIXED** | Added manual `post-deploy-smoke.yml` workflow. |
| Pin actions by commit SHA | **DEFERRED** | Not fully pinned in this patch set; recommended for next hardening pass. |

## Required Evidence

- `cargo fmt -- --check`: **PASS**
- `cargo test --all-targets`: **PASS** (19 tests incl. main + lib)
- `flutter analyze`: **PASS**
- `flutter test`: **PASS**
- `flutter build apk --release`: **PASS**
- Secret scan (`gitleaks detect --source . --config .gitleaks.toml`): **PASS**, no leaks found
- Endpoint smoke tests:
  - `https://7jzi.com/lander`: **200**
  - `http://api.7jzi.com/health`: **200**
  - `http://api.7jzi.com/ready`: **200**
  - `http://api.7jzi.com/metrics`: **200**
  - `http://api.7jzi.com/v1/health`: **200**
  - `http://api.7jzi.com/v1/ready`: **200**
  - `http://api.7jzi.com/v1/metrics`: **200**
  - `POST http://api.7jzi.com/waitlist`: **ok**
  - `POST http://api.7jzi.com/v1/waitlist`: **ok**
