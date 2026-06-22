# Sakina AI — Kubernetes / Talos Runtime Audit

Date: 2026-06-22.

## Runtime status: UNPROVEN — no live Sakina cluster available
- `kubectl get ns` fails: the configured context targets an unreachable AKS cluster from a **different project** (`aks-iterla-…westeurope.azmk8s.io` — DNS no-such-host). No Sakina namespace/cluster reachable from this environment.
- None of the required runtime k8s checks (pod status, CrashLoopBackOff, ImagePullBackOff, PVCs, secrets, ingress, probes) could be executed. **Must be exercised on the real Talos/k8s target before READY.**

## Static manifest review (`sakina-infra/manifests/`, `k8s/`)
Present: `00-namespaces.yaml`, `storage-class.yaml`, `network-policies.yaml`, `brand-configmap.yaml`; deployments `postgres-deployment.yaml`, `qdrant-deployment.yaml`, `sakina-api-deployment.yaml`; `base/`, `overlays/`, `sakina-prod/`, `monitoring/`; `k8s/ollama`, `k8s/sakina-mobile-prod`, `k8s/sakina-mobile-staging`.

Carry-over risks (confirm at runtime):
- `postgres-deployment.yaml` mounts the same `init.sql` (configmap `postgres-init`) that caused **boot failure SAK-002** in Docker — the `CREATE USER` conflict will hit k8s Postgres unless the now-fixed init.sql is re-published into the configmap (`Makefile:18` builds it `--from-file`). **Action: regenerate the postgres-init configmap from the repaired init.sql.**
- RLS-bypass (SAK-006) applies identically — the deployment connects as `sakina_user`.
- Hardcoded-secrets pattern (SAK-013) must not be carried into k8s Secrets; verify secrets come from a SecretProvider/sealed-secrets, not literals.

## Required runtime proof (to run on the target cluster)
```
kubectl get pods -n sakina-prod -o wide
kubectl get svc,ingress,pvc,secrets,configmap -n sakina-prod
kubectl logs -n sakina-prod deploy/sakina-api --tail=100
kubectl get deploy -n sakina-prod -o wide   # readiness/liveness probes present?
```
Until these pass with output, k8s readiness = **UNPROVEN**.
