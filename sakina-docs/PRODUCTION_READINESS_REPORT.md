# Sakina Chat-First v1 Production Readiness Report

## Scope
- Backend: `sakina-backend` (Rust API + middleware + handlers).
- Frontend: `sakina-frontend` (Flutter mobile app).
- Infra: `sakina-infra/manifests` (Kubernetes baseline).
- CI gates: backend, frontend, infra workflow validation.

## Completed Hardening

### Backend security and reliability
- Enforced API auth + user identity flow already present in middleware and handlers.
- Added sync endpoint throttling (`upload` and `download`) in `sakina-backend/src/handlers/sync.rs`.
- Removed hardcoded DB role password from `sakina-backend/db/init.sql`; role creation is now password-agnostic.
- Added non-root runtime user in `sakina-backend/Dockerfile.api`.
- Verified dependency-aware readiness and route wiring already present (`/v1/ready`, classify DI, request size limits).
- Verified timeout/retry logic already present for embeddings, Qdrant, and LLM service clients.

### Frontend chat-first readiness
- Confirmed authenticated identity flow is used in chat backend via secure user ID.
- Localized chat error handling by replacing hardcoded strings with localized error keys.
- Added chat error localization keys across all supported locales.
- Refined home shell with premium hero + feature pills while keeping non-v1 modules explicitly upcoming.

### Infra and deployment hardening
- Updated Postgres and Qdrant StatefulSets to use `managed-csi` for cloud clusters.
- Added Postgres `PGDATA` subdirectory to avoid mount-point initialization failures.
- Updated Qdrant health probes (`/`) to prevent liveness false negatives on current image.
- Updated deployment documentation with:
  - canonical manifests baseline,
  - GHCR image pull secret requirements,
  - cloud storage guidance.

## Validation Evidence
- Backend tests: `cargo test --all-targets` passed.
- Backend lint: `cargo clippy --all-targets -- -D warnings` passed.
- Frontend static analysis: `flutter analyze` passed.
- Frontend tests: `flutter test` passed.
- Infra syntax validation: `kubectl apply --dry-run=client -R -f sakina-infra/manifests` passed.
- Integration collection gate: `pytest --collect-only -q sakina-tests/integration/test_rag_query.py` collected 6 tests.

## Live Rollout Attempt Status

### Successfully deployed and validated
- Namespaces created: `sakina-api`, `sakina-data`, `sakina-core`, `sakina-audit`, `sakina-monitoring`.
- Monitoring stack running (`prometheus`, `grafana`, `jaeger`).
- Data services running (`postgres`, `qdrant`) after storage/probe fixes.
- Synthetic in-cluster connectivity checks from API-labeled pods:
  - API namespace -> Qdrant: success.
  - API namespace -> Postgres: success.

### Current blockers for full cutover
- API image pull fails from GHCR (`ImagePullBackOff` / `ErrImagePull`) because registry access is not yet authorized for cluster pulls.
- vLLM deployment cannot run on current node profile due GPU/memory requirements (`nvidia.com/gpu`, high CPU/RAM).
- Without API image pull and vLLM availability, end-to-end RAG smoke and production cutover cannot be completed.

## Required Final Actions to Go Live
1. Provide cluster-level GHCR read access (PAT or workload identity with `read:packages`) and confirm API image pull succeeds.
2. Provision GPU-capable nodepool for vLLM (or switch to a validated managed LLM endpoint for chat-first launch).
3. Re-run rollout verification:
   - `kubectl rollout status` for `sakina-api` and `vllm`,
   - synthetic `/v1/health`, `/v1/ready`, `/metrics`,
   - synthetic authenticated `/v1/rag/query`.
4. Execute controlled production cutover and rollback drill after successful staging verification.
