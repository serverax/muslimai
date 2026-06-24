# Sakina AI — PHASE 6: Production Deployment Readiness (Kubernetes / Staging)

Date: 2026-06-23 · Branch: `qa-security-hardening`
Scope: audit + repair + **offline** validation of the Kubernetes manifests; deployment runbook.
**Honest constraint:** there is **no reachable Sakina cluster** in this environment (the kube context points at an unrelated, unreachable AKS endpoint `aks-iterla-…westeurope.azmk8s.io`). Therefore **live cluster apply/runtime is UNPROVEN/BLOCKED**. The proven runtime baseline remains the local Docker QA stack on `:28080` (health 200 at time of writing). **This is NOT a LIVE_READY signoff.**

## What was validated (real, command-proven, offline)
Validation tool: `kubectl` v1.36 `kustomize` (strict YAML build — no API server needed).

| Overlay | Build | Objects |
|---|---|---|
| `infra/k8s/sakina-mobile-staging` | **OK** | 35 |
| `infra/k8s/sakina-mobile-prod` | **OK** | 35 |

Object breakdown (each overlay): 1 DaemonSet, 12 Deployment, 1 Ingress, 2 Job, 1 Namespace, 1 PersistentVolumeClaim, 15 Service, 2 StatefulSet.

## Defect found and repaired
**Staging overlay did not build** — `kubectl kustomize` rejected it with `mapping key "valueFrom" already defined`. Root cause: in three staging manifests the `POSTGRES_PASSWORD` container env var had **lost its own `valueFrom`** and the orphaned `secretKeyRef` (postgres password) was mis-attached as a **duplicate `valueFrom`** under `ENCRYPTION_KEY`. Effect if it had ever been applied: the migration Job, Postgres, and worker pods would start with an **empty `POSTGRES_PASSWORD`** (auth failure / crash loop), and kustomize/`apply -k` refuses the whole overlay.

Files repaired (re-attached `POSTGRES_PASSWORD` → `secretKeyRef{sakina-postgres-secret/POSTGRES_PASSWORD}`, removed the duplicate key):
- `infra/k8s/sakina-mobile-staging/db-migrations.yaml`
- `infra/k8s/sakina-mobile-staging/postgres.yaml`
- `infra/k8s/sakina-mobile-staging/worker.yaml`

The **prod** overlay already had the correct structure (used as the reference). After the fix, `key: POSTGRES_PASSWORD` resolves to a `secretKeyRef` in 10 places in the rendered staging output; both overlays build clean.

## Manifest audit (static, honest)
| Check | Finding | Status |
|---|---|---|
| App image | `ghcr.io/serverax/sakina-backend:qa-security-hardening` (13 refs) + `sakina-frontend:qa-security-hardening` (1) | ⚠ image **not proven pushed** to GHCR; the Docker-proven image is local `sakina-backend:latest`. CI must build+push this tag before apply. |
| Secrets committed? | **None** — no `kind: Secret` and no literal password/JWT values in the overlays | ✅ clean |
| Secrets referenced | `sakina-postgres-secret`, `sakina-staging-secrets` (staging) / `sakina-prod-secrets` (prod), `ghcr-pull-secret` | ⚠ must be **created out-of-band** before apply |
| Migration runner | Job `backoffLimit: 1`, `restartPolicy: Never`, runs `/usr/local/bin/sakina-migrate` (38 migrations embedded) | ✅ correct shape |
| Ingress / TLS | Traefik, `tls.secretName: sakina-api-tls`, `host: api.7jzi.com` | ⚠ TLS secret must exist (cert-manager/manual); **prod and staging currently share the same host** — set distinct hosts per environment before a real deploy |
| Smoke tests | Job curls `/health/ready` on backend, rag-retrieval, llm-gateway and `/` on admin | ✅ present |
| App DB role | Postgres official image bootstraps `POSTGRES_USER` from secret; `sakina-migrate` applies schema + RLS gate | ✅ (init.sql/`CREATE ROLE` bootstrap is a Docker-compose concern, not needed in this overlay) |

## Pre-apply requirements (blocking, must be satisfied on a real cluster)
1. **Push images** `ghcr.io/serverax/sakina-{backend,frontend}:qa-security-hardening` from CI.
2. **Create secrets** in the target namespace: `sakina-postgres-secret` (POSTGRES_DB/USER/PASSWORD), `sakina-staging-secrets` / `sakina-prod-secrets` (jwt-secret, encryption-key, …), and `ghcr-pull-secret` (registry pull).
3. **TLS**: provision `sakina-api-tls` (cert-manager Issuer or manual) and set a per-environment ingress host.
4. **Stripe**: still `provider_not_configured` (PHASE 5) — set real test keys as secrets when ready; do **not** mark Stripe live.

## Verdict
- **Manifests: STATICALLY VALIDATED & REPAIRED** — both staging and prod kustomize overlays build clean (35 objects each); the staging-blocking duplicate-key defect is fixed.
- **Live cluster runtime: UNPROVEN / BLOCKED** — no reachable cluster in this environment.
- **Proven runtime baseline: Docker QA stack** on `:28080` (health 200).
- Overall product status remains **PARTIAL_READY — NOT LIVE_READY**.

## Next step to actually go live (requires operator + cluster)
Provision a cluster, satisfy the four pre-apply requirements, then follow `docs/sakina-mobile-deployment-runbook.md` (apply staging overlay → migration Job → smoke-tests Job → validate ingress), and only then promote prod.
