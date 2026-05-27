# SakinaAI Production Release Notes (2026-05-27)

## 1) Active Deployments (Release Scope)

- Namespace: `sakina-prod`
- Backend deployment: `sakina-backend`
  - Image: `ghcr.io/serverax/sakina-backend:2eb50fe`
  - Status: `1/1 Running`
- Frontend deployment: `sakina-frontend`
  - Image: `ghcr.io/serverax/sakina-frontend:2eb50fe`
  - Status: `2/2 Running`

## 2) Active Public URLs

- `http://7jzi.com/`
- `http://7jzi.com/lander`
- `http://api.7jzi.com`

## 3) Required Secrets / Env Vars

### Backend (`sakina-backend`)

- Env sources:
  - `configmap/sakina-backend-config`
  - `secret/sakina-supabase-secret`
  - `secret/sakina-object-storage-secret`
- Required readiness env var:
  - `DATABASE_URL` (must be present and non-empty)
- Supabase secret keys expected:
  - `DATABASE_URL`
  - `SUPABASE_DB_URL`
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` (backend-only, never exposed to frontend/mobile/logs)
- Object storage secret keys expected:
  - `OBJECT_STORAGE_ENDPOINT`
  - `OBJECT_STORAGE_BUCKET`
  - `OBJECT_STORAGE_ACCESS_KEY`
  - `OBJECT_STORAGE_SECRET_KEY`
  - `OBJECT_STORAGE_REGION`

### Frontend (`sakina-frontend`)

- Env source:
  - `configmap/sakina-frontend-config`

## 4) Database Schema/Table Used

- Schema: `sakina_ai`
- Table: `sakina_ai.waitlist`
- API writes:
  - `POST /waitlist`
  - `POST /v1/waitlist`

## 5) Rollback Commands

### Revision rollback

```bash
kubectl -n sakina-prod rollout undo deployment/sakina-backend
kubectl -n sakina-prod rollout undo deployment/sakina-frontend
```

### Explicit tag rollback

```bash
kubectl -n sakina-prod set image deployment/sakina-backend backend=ghcr.io/serverax/sakina-backend:<previous-tag>
kubectl -n sakina-prod set image deployment/sakina-frontend frontend=ghcr.io/serverax/sakina-frontend:<previous-tag>
```

## 6) Legacy Cleanup Decision (`sakinaai-*`)

### In-scope release path (confirmed active)

- `sakina-backend`
- `sakina-frontend`
- `7jzi.com`, `www.7jzi.com`, `api.7jzi.com`
- `sakina_ai.waitlist`

### Legacy stack status (post-cleanup review)

- No `sakinaai-*` deployments/services/ingress/configmaps/secrets remain in `sakina-prod`.
- Active ingress now only targets:
  - `7jzi.com`
  - `www.7jzi.com`
  - `api.7jzi.com`

### Dependency check summary

- Code references in active apps:
  - No matches in `sakina-frontend` or `sakina-backend` for `api.sakinaapp.com`, `admin.sakinaapp.com`, `sakinaai-*`.
- Public reachability:
  - `api.sakinaapp.com` -> status `000`
  - `admin.sakinaapp.com` -> status `000`
- Active 7jzi path remained healthy during checks:
  - `api.7jzi.com/health` -> `200`
  - `7jzi.com/lander` -> `200`

### Backup created before cleanup

- File: `sakina-prod-legacy-backup.yaml`
- Command used:
  - `kubectl -n sakina-prod get deploy,svc,ingress,configmap,secret -o yaml > sakina-prod-legacy-backup.yaml`

### Cleanup commands (admin-run, no PVC deletion)

```bash
# scale down
kubectl -n sakina-prod scale deploy/sakinaai-api deploy/sakinaai-admin-web deploy/sakinaai-worker --replicas=0

# delete ingress/services/deployments
kubectl -n sakina-prod delete ingress sakinaai-ingress
kubectl -n sakina-prod delete svc sakinaai-api sakinaai-admin-web
kubectl -n sakina-prod delete deploy sakinaai-api sakinaai-admin-web sakinaai-worker

# delete redis only if confirmed legacy-only
kubectl -n sakina-prod delete svc sakinaai-redis
kubectl -n sakina-prod delete statefulset sakinaai-redis

# delete legacy config/secret only after confirming no references remain
kubectl -n sakina-prod delete configmap sakinaai-config
kubectl -n sakina-prod delete secret sakinaai-secrets
```

Important: do **not** delete PVCs unless explicitly approved.

### Cleanup result snapshot

- Verified absent:
  - `sakinaai-api`
  - `sakinaai-admin-web`
  - `sakinaai-worker`
  - `sakinaai-redis` service
  - `sakinaai-ingress`
- Legacy Redis PVC retained (admin-verified):
  - `redis-data-sakinaai-redis-0`
  - Size: `5Gi`
  - Status: `Bound`
  - StorageClass: `local-path`
- Data-retention decision:
  - PVC/data deletion is **not approved** in this release stage.
  - Keep PVC intact pending separate explicit data-retention approval.
- Initial PVC check from `sakina-developer` account was RBAC-restricted.  
  Admin check command:

```bash
kubectl -n sakina-prod get pvc | grep -Ei 'sakinaai|redis'
```

## 7) Final Verification Evidence

- `GET /health` returned healthy JSON.
- `GET /ready` returned checks:
  - `database_reachable=true`
  - `waitlist_table_exists=true`
  - `required_env_present=true`
- `GET /metrics` returned Prometheus-formatted metrics including:
  - `sakina_backend_up 1`
  - `sakina_waitlist_total <count>`
  - `sakina_build_info{service="sakina-backend"} 1`
- `POST /waitlist` returned:
  - `{"status":"ok","message":"waitlist entry saved"}`
- Post-cleanup waitlist verification email:
  - `post-cleanup-20260527100142@example.com`
- Frontend:
  - `http://7jzi.com/` and `http://7jzi.com/lander` served expected landing page content.

## 8) Operational Note

The current `sakina-developer` service account is read-constrained for cleanup actions in `sakina-prod` (scale/delete forbidden). Legacy cleanup must be executed by a cluster-admin or a service account with patch/delete permissions.
