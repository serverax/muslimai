# Sakina Mobile Deployment Runbook

Manifests are Kustomize overlays: `infra/k8s/sakina-mobile-staging` and `infra/k8s/sakina-mobile-prod`
(35 objects each; both verified to build with `kubectl kustomize`). See
`reports/sakina-phase6-deployment-readiness.md` for the validation evidence and known gaps.

## Prerequisites (blocking — do before any apply)
1. **Cluster + context** pointing at the real Sakina cluster (current dev kube context targets an
   unrelated AKS and is unreachable — live apply is impossible until this is fixed).
2. **Images pushed** to GHCR with the deployed tag (currently `qa-security-hardening`):
   `ghcr.io/serverax/sakina-backend` and `ghcr.io/serverax/sakina-frontend`. Build from the repo
   `Dockerfile`s in CI and push; the local Docker image `sakina-backend:latest` is the proven build.
3. **Secrets created** in the target namespace (NOT committed to git):
   - `sakina-postgres-secret`: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
   - `sakina-staging-secrets` / `sakina-prod-secrets`: `jwt-secret`, `encryption-key` (+ any provider keys)
   - `ghcr-pull-secret`: docker-registry pull secret for GHCR
   - (when enabling payments) Stripe `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET`
4. **TLS**: provision `sakina-api-tls` (cert-manager Issuer or manual cert) and set a
   per-environment ingress host (staging and prod must NOT share `api.7jzi.com`).

## Validate before apply (no cluster needed)
```
kubectl kustomize infra/k8s/sakina-mobile-staging   # must render without error
kubectl kustomize infra/k8s/sakina-mobile-prod
```

## Deployment Order
1. `kubectl apply -k infra/k8s/sakina-mobile-staging` (namespace, datastores, services).
2. Migration Job (`db-migrations.yaml`) runs `/usr/local/bin/sakina-migrate` — 38 migrations,
   `restartPolicy: Never`, `backoffLimit: 1`. Confirm Job `Complete`.
3. Backend API + workers + RAG/brain/rules/citation-guard come up; wait for Ready.
4. Run the smoke-tests Job (curls `/health/ready` on backend, rag-retrieval, llm-gateway).
5. Validate ingress (`api.<env>` over TLS) and mobile `api_config.dart` endpoint connectivity.
6. Only after staging is green, repeat with `infra/k8s/sakina-mobile-prod`.

## Rollback Strategy
- Backend: rollout undo deployment by revision.
- DB: use explicit rollback scripts where provided; otherwise forward-fix.
- RAG: disable ingestion jobs first, then revert service image tags.

## Required Evidence
- Migration logs showing success.
- Smoke script pass output.
- Endpoint status from health checks.
- Release artifact tags and commit SHA.
