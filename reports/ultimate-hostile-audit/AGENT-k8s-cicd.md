# Hostile DevOps Audit — K8s Manifests + CI/CD (SakinaAL)

Scope: STATIC manifest + workflow analysis only. Live-cluster verification is OUT OF SCOPE (orchestrator owns it). No `cargo`/`docker build` run. `kubectl kustomize` used only for local rendering.

Branch: `qa-security-hardening`. Active staging target: `infra/k8s/sakina-mobile-staging/`.

---

## 1. Files inspected

K8s source manifests (active staging):
- `infra/k8s/sakina-mobile-staging/kustomization.yaml`
- `infra/k8s/sakina-mobile-staging/namespace.yaml`
- `infra/k8s/sakina-mobile-staging/postgres.yaml`
- `infra/k8s/sakina-mobile-staging/qdrant.yaml`
- `infra/k8s/sakina-mobile-staging/redis.yaml`
- `infra/k8s/sakina-mobile-staging/ollama.yaml`
- `infra/k8s/sakina-mobile-staging/ollama-preload.yaml`
- `infra/k8s/sakina-mobile-staging/llm-gateway.yaml`
- `infra/k8s/sakina-mobile-staging/db-migrations.yaml`
- `infra/k8s/sakina-mobile-staging/rag.yaml`
- `infra/k8s/sakina-mobile-staging/backend.yaml`
- `infra/k8s/sakina-mobile-staging/admin.yaml`
- `infra/k8s/sakina-mobile-staging/smoke-tests.yaml` (present on disk, see finding F1)
- `k8s/ollama/ollama-cpu-lite.yaml` (out-of-tree, not referenced by staging kustomization)

Other (referenced for comparison, NOT in active deploy path):
- `sakina-infra/manifests/network-policies.yaml` (PROD multi-namespace tree)
- `sakina-infra/docker-compose.yml`, `sakina-infra/docker-compose.local.yml`

CI/CD workflows inspected:
- `.github/workflows/sakina-deploy.yml` (REAL deploy: build+push GHCR + apply k8s)
- `.github/workflows/sakina-mobile-staging-deploy.yml` (Terraform-only)
- `.github/workflows/sakinaai-images.yml`, `.github/workflows/infra-ci.yml` (validation)
- Full workflow list: see `149`/`161` evidence files (25 workflows total).

---

## 2. Line numbers (key evidence, rendered file = `150-kustomize-staging.yaml`)

- LLM env separation (PASS):
  - backend owns `SAKINA_LLM_GATEWAY_URL=http://sakina-llm-gateway:8087` — rendered L342-343; NO `OLLAMA_BASE_URL`.
  - gateway owns `OLLAMA_BASE_URL=http://sakina-ollama:11434` — rendered L514-515.
  - `sakina-llm-gateway` Deployment — rendered L480-487, command `sakina-llm-gateway` L509-510.
- Ollama is a **Deployment, replicas:1** — rendered L572-581. NOT a DaemonSet.
  - Source: `infra/k8s/sakina-mobile-staging/ollama.yaml:35` (`kind: Deployment`).
- Ollama image **unpinned** `ollama/ollama` (no tag → implicit `:latest`) — rendered L604; source `ollama.yaml:70`.
- ollama-preload is a **Job** — rendered L1333-1339; source `ollama-preload.yaml:2` (`kind: Job`).
- Probes present on every long-running workload — rendered livenessProbe/readinessProbe at L248/258 (admin), L403/413 (backend), L526/536 (gateway), L606/618 (ollama), L733/743 + L887/897 (rag), L998/1009 (redis), L1091/1104 (postgres), L1192/1202 (qdrant).
- resources requests+limits present on every workload — rendered L264, L419, L542, L626, L749, L903, L1016, L1113, L1208, L1295.
- imagePullSecrets `ghcr-pull-secret` on all GHCR-image workloads — rendered L286-287, L440-441, L557-558, L770-771, L924-925, L1313-1314.
- App image tags = `:qa-security-hardening` (mutable branch tag, NOT digest) — rendered L246, L401, L448, L524, L731, L778, L885, L932, L1292.
- Third-party pinned: `redis:7-alpine` L996, `postgres:16-alpine` L1089, `qdrant/qdrant:v1.10.1` L1190, `curlimages/curl:8.8.0` L1370.
- No `kind: NetworkPolicy` in rendered output (grep returned NONE).
- No `kind: DaemonSet` in rendered output (grep returned NONE).

---

## 3. Commands run

```
mkdir -p reports/ultimate-hostile-audit
find infra/k8s k8s deploy -type f \( -name '*.yaml' -o -name '*.yml' \) | sort > reports/ultimate-hostile-audit/149-k8s-files.txt
ls -la infra/k8s/sakina-mobile-staging/
kubectl kustomize infra/k8s/sakina-mobile-staging > reports/ultimate-hostile-audit/150-kustomize-staging.yaml 2>&1; echo EXIT=$?   # -> EXIT=0, 1406 lines
rg -n "kind:|image:|imagePullSecrets|ghcr|OLLAMA_BASE_URL|SAKINA_LLM_GATEWAY_URL|readinessProbe|livenessProbe|resources:|secretKeyRef|configMapKeyRef|namespace:" 150-kustomize-staging.yaml > 151-kustomize-key-fields.txt
rg -n "NetworkPolicy" 150-kustomize-staging.yaml            # NONE
rg -n "kind: DaemonSet" 150-kustomize-staging.yaml          # NONE
rg -rni "lawapp|iterlaw" infra/k8s/sakina-mobile-staging/   # NONE
rg -rni "localhost|127.0.0.1" infra/k8s/sakina-mobile-staging/  # NONE
rg -rn ":latest" infra/k8s/sakina-mobile-staging/           # NONE (literal)
rg -n -i "continue-on-error|allow-failure|\|\| true|echo.*pass|fake|mock|skip|docker-compose|:latest|kubectl apply" .github/workflows scripts/sakina > 161-ci-bypass-scan.txt
```

---

## 4. Evidence files

- `reports/ultimate-hostile-audit/149-k8s-files.txt` — manifest inventory
- `reports/ultimate-hostile-audit/150-kustomize-staging.yaml` — rendered staging (EXIT=0, 1406 lines)
- `reports/ultimate-hostile-audit/151-kustomize-key-fields.txt` — key fields (124 lines)
- `reports/ultimate-hostile-audit/161-ci-bypass-scan.txt` — CI bypass scan (289 hits)

---

## 5. Failures

- Kustomize render: **none** — `kubectl kustomize` exited 0, 1406 lines, well-formed.

---

## 6. Not-deployed / missing manifests (drift candidates for orchestrator)

| Concern | Status | Evidence |
|---|---|---|
| **Ollama DaemonSet** | ABSENT — Ollama is a 1-replica `Deployment` instead | rendered L572-581; `ollama.yaml:35` |
| **NetworkPolicy (Ollama→gateway-only)** | ABSENT from active staging tree entirely | `rg NetworkPolicy 150-*.yaml` = NONE |
| NetworkPolicies that DO exist (prod tree) | Do NOT cover staging | `sakina-infra/manifests/network-policies.yaml` — multi-namespace (sakina-api/data/core), references vLLM not Ollama, wrong namespace model for single-ns staging |
| **smoke-tests.yaml** | On disk but NOT in `kustomization.yaml resources` | `kustomization.yaml:10-21` lists 11 resources, omits `smoke-tests.yaml`. (It IS applied directly by `sakina-deploy.yml:363`, so it deploys — but kustomize render does not include it.) |
| Stale DaemonSet cleanup | Deploy script deletes `daemonset ollama-inference` | `sakina-deploy.yml:284` — leftover reference to a retired DaemonSet design; no such manifest exists in repo |
| `k8s/ollama/ollama-cpu-lite.yaml` | Orphan — not referenced by staging kustomization | inventory `149-*.txt` |

**Workloads the manifests DEFINE** (orchestrator should compare to RUNNING):
Deployments: `sakina-admin`, `sakina-backend` (replicas 2), `sakina-llm-gateway`, `sakina-ollama`, `sakina-rag-ingestion`, `sakina-rag-retrieval`, `sakina-redis`.
StatefulSets: `sakina-postgres`, `sakina-qdrant`.
Jobs: `sakina-db-migrations`, `sakina-ollama-preload` (+ `sakina-staging-smoke` via direct apply).
Services (10): admin, backend, llm-gateway, ollama, postgres, qdrant, rag, rag-ingestion, rag-retrieval, redis.
PVC: `sakina-ollama-models`. Namespace: `sakina-mobile-staging`.

---

## 7. Fake / bypass in CI (file:line)

No fake-PASS, no `continue-on-error`, no `|| true` on required steps found in the deploy path.

- `sakina-deploy.yml` (the REAL deploy): `set -euo pipefail` on every script step; rollouts/jobs fail hard with `exit 1` (e.g. L177 job wait, L219 rollout, L379 final health, L400-402 bad-pod gate). Smoke job runs and is awaited: `apply_file ... smoke-tests.yaml` + `wait_job sakina-staging-smoke` (L363-364) — failure aborts. **Not bypassed.**
- Real GHCR image build+push: `sakina-deploy.yml:50-68` builds & pushes `sakina-backend`/`sakina-frontend` tagged with `${{ github.sha }}` AND `:qa-security-hardening`, `push: true`. Runtime deployments are then pinned to the **sha image** (immutable) at L317-346. PASS.
- Deploys k8s manifests, NOT compose: `sakina-deploy.yml:118-364` applies individual files from `infra/k8s/sakina-mobile-staging/`. No `docker compose up` anywhere.
- `docker compose` hits are **config-validation only** (syntax lint), never deployment:
  - `infra-ci.yml:54` `docker compose ... config`
  - `sakinaai-images.yml:60` `docker compose ... config`
- `:latest` hits in CI are **negative assertions** (good): `sakinaai-images.yml:70-71` `assert ":latest" not in backend/frontend`; `sakina-backend-image.yml:38` defines a `latest_tag` var (review use, but not in active staging deploy).
- `skip` hits = PR-scope build optimization, not test-skips: `sakinaai-images.yml:140-143`.

Caveats (not bypass, but weaknesses):
- W1: App images use **mutable branch tag** `:qa-security-hardening` in manifests (rendered L246 etc.); only `sakina-deploy.yml` repins to sha at runtime. A raw `kubectl apply` of the manifests alone would pull a mutable tag. Not pinned to digest.
- W2: CI lint (`infra-ci.yml`, `sakinaai-images.yml`) validates the **prod tree** `sakina-infra/manifests/`, NOT the active staging tree `infra/k8s/sakina-mobile-staging/`. The staging kustomize is never rendered/linted in CI — render only verified here, manually.
- W3: `sakina-mobile-staging-deploy.yml` is Terraform-only (L21-25) and does NOT apply k8s manifests; the actual k8s deploy is `sakina-deploy.yml` (push trigger on `qa-security-hardening`, L15-17).

---

## 8. Repairs

None applied — report only, per instructions.

Recommended (for owner, not done):
1. Add a `NetworkPolicy` to the staging tree restricting `sakina-ollama` ingress to `app: sakina-llm-gateway` only (currently any pod in namespace can reach Ollama:11434).
2. Pin `ollama/ollama` to an explicit version/digest (`ollama.yaml:70`).
3. Either add `smoke-tests.yaml` to `kustomization.yaml resources` or document it as deploy-script-only.
4. Add staging kustomize render to CI (`kubectl kustomize infra/k8s/sakina-mobile-staging`) so it is linted.
5. Decide DaemonSet vs Deployment for Ollama; remove the stale `daemonset ollama-inference` delete in `sakina-deploy.yml:284` and orphan `k8s/ollama/ollama-cpu-lite.yaml` if unused.

---

## 9. Rendered-proof excerpts

Gateway owns Ollama URL; backend does NOT (rendered):
```
# Deployment sakina-backend (L308)
- name: SAKINA_LLM_GATEWAY_URL
  value: http://sakina-llm-gateway:8087      # L342-343  (no OLLAMA_BASE_URL present)
# Deployment sakina-llm-gateway (L480)
- name: OLLAMA_BASE_URL
  value: http://sakina-ollama:11434          # L514-515
```

Ollama is a Deployment, not a DaemonSet, unpinned image (rendered):
```
kind: Deployment                              # L572
  name: sakina-ollama                         # L578
  replicas: 1                                 # L581
    image: ollama/ollama                      # L604  (no tag)
```

CI builds+pushes real GHCR images and pins to sha (`sakina-deploy.yml`):
```
50  - name: Build and push backend image
55      push: true
57        ghcr.io/serverax/sakina-backend:${{ github.sha }}
317  backend_sha_image="ghcr.io/serverax/sakina-backend:${{ github.sha }}"
336  kubectl set image deployment/sakina-backend backend="$backend_sha_image" ...
364  wait_job sakina-staging-smoke      # smoke failure aborts deploy
```

---

## Manifest inventory table

| Workload | Kind | Replicas | Image | Pinned? | Probes | Resources | imagePullSecret |
|---|---|---|---|---|---|---|---|
| sakina-admin | Deployment | 1 | ghcr.io/serverax/sakina-frontend:qa-security-hardening | mutable tag | yes | yes | ghcr-pull-secret |
| sakina-backend | Deployment | 2 | ghcr.io/serverax/sakina-backend:qa-security-hardening | mutable tag | yes | yes | ghcr-pull-secret |
| sakina-llm-gateway | Deployment | 1 | ghcr.io/serverax/sakina-backend:qa-security-hardening (cmd sakina-llm-gateway) | mutable tag | yes | yes | ghcr-pull-secret |
| sakina-ollama | Deployment | 1 | ollama/ollama | NO (no tag) | yes | yes | n/a (public) |
| sakina-rag-ingestion | Deployment | 1 | ghcr.io/serverax/sakina-backend:qa-security-hardening | mutable tag | yes | yes | ghcr-pull-secret |
| sakina-rag-retrieval | Deployment | 1 | ghcr.io/serverax/sakina-backend:qa-security-hardening | mutable tag | yes | yes | ghcr-pull-secret |
| sakina-redis | Deployment | 1 | redis:7-alpine | tag | yes | yes | n/a |
| sakina-postgres | StatefulSet | 1 | postgres:16-alpine | tag | yes | yes | n/a |
| sakina-qdrant | StatefulSet | 1 | qdrant/qdrant:v1.10.1 | pinned | yes | yes | n/a |
| sakina-db-migrations | Job | - | ghcr.io/serverax/sakina-backend:qa-security-hardening | mutable tag (sha-patched at deploy) | n/a | yes | ghcr-pull-secret |
| sakina-ollama-preload | Job | - | curlimages/curl:8.8.0 | pinned | n/a | yes | n/a |

---

## VERDICT

**K8s-manifests: PARTIAL**
- PASS: kustomize renders clean (EXIT=0); LLM env ownership correctly split (gateway=OLLAMA_BASE_URL, backend=SAKINA_LLM_GATEWAY_URL only); probes + resources on every workload; imagePullSecret consistent and created at deploy time; no lawapp/iterlaw; no localhost; no compose in k8s tree; hardened securityContext throughout.
- FAIL/gaps: NO NetworkPolicy in staging tree (Ollama not restricted to gateway) ; Ollama is a 1-replica Deployment, NOT a DaemonSet ; `ollama/ollama` image unpinned (implicit :latest) ; app images use mutable branch tag (only repinned to sha by the deploy script, not in manifests) ; `smoke-tests.yaml` omitted from kustomization resources ; stale `ollama-inference` DaemonSet reference + orphan `k8s/ollama/ollama-cpu-lite.yaml`.

**CI/CD: PASS (with caveats)**
- PASS: `sakina-deploy.yml` builds+pushes real GHCR images, pins runtime to immutable sha, applies real k8s manifests (not compose), fails hard on rollout/job/smoke/bad-pod (`set -euo pipefail`, `exit 1`); no `continue-on-error`/`|| true`/fake-PASS on required steps; compose used only for `config` lint; `:latest` appears only as negative assertions.
- Caveats: CI lints the PROD manifest tree (`sakina-infra/manifests/`), NOT the active staging tree — staging kustomize is never rendered in CI ; `sakina-mobile-staging-deploy.yml` is Terraform-only (the real k8s apply is `sakina-deploy.yml`).

NOTE: Live-cluster state (what is actually RUNNING vs DEFINED) is OUT OF SCOPE — orchestrator owns drift verification.
