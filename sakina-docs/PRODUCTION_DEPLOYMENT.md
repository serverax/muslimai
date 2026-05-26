# Production Deployment — Project Sakina

> **Status (honest):** the backend (Rust) and frontend (Flutter) compile and pass
> their unit/compile tests. The full stack has **not** been deployed or
> integration-tested in CI/this environment — there is no GPU (so no vLLM), and
> the deploy below has been validated only with `kubectl --dry-run=client`. Treat
> this as the deployment *procedure*, not a record of a live production run.

## Canonical deployment baseline
- **Source of truth for this release:** `sakina-infra/manifests/`
- **Legacy path:** `sakinaai-infra.sh` is retained for historical reference only and is not authoritative for chat-first v1 production.

## Prerequisites
- Docker + a Kubernetes cluster (local: `kind`; prod: managed k8s).
- A node with a **GPU** for vLLM (embeddings + generation). Without it, `/rag/query`
  cannot embed or generate — RAG returns errors/fallbacks.
- NVIDIA device plugin / GPU runtime support for `nvidia.com/gpu` scheduling.
- `kubectl`, `make`.

## 1. Build & load images
```bash
cd sakina-backend
docker build -f Dockerfile.api  -t sakina-backend-api:latest  .
# vLLM image requires CUDA base + a GPU host:
docker build -f Dockerfile.vllm -t sakina-backend-vllm:latest .

# kind only:
kind load docker-image sakina-backend-api:latest --name sakina
kind load docker-image sakina-backend-vllm:latest --name sakina
```

For remote clusters (AKS/EKS/GKE), ensure the runtime can pull GHCR images and
do not rely on local `kind load`:

```bash
# namespace: sakina-api
kubectl create secret docker-registry ghcr-creds -n sakina-api \
  --docker-server=ghcr.io \
  --docker-username='<github-username>' \
  --docker-password='<github-token-with-read:packages>' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl patch serviceaccount sakina-api -n sakina-api \
  -p '{"imagePullSecrets":[{"name":"ghcr-creds"}]}'
```

## 2. Namespaces + DB layer
```bash
cd sakina-infra
make setup-k8s          # kind cluster + sakina-{data,api,core,audit} namespaces
make dev-start          # postgres + qdrant (builds postgres-init ConfigMap from db/init.sql)
kubectl wait --for=condition=ready pod -l app=postgres -n sakina-data --timeout=300s
```

For managed clusters, use CSI-backed PVCs (`managed-csi`) from the checked-in
StatefulSets. The `storage-class.yaml` local PVs remain useful for kind/local
only and are not required on cloud clusters.

## 3. Deploy everything
```bash
make deploy             # kubectl apply -R -f manifests/  (API, network-policies, monitoring/)
```
This applies: `storage-class`, `postgres`, `qdrant`, `vllm`, `brand-configmap`,
`network-policies`, `sakina-api-deployment`, `sakina-api-ingress`, and
`monitoring/` (prometheus, grafana, jaeger). The `sakina-api` and `vllm` pods
need their images (step 1) or they sit in `ErrImageNeverPull`.

> **kind caveat:** kind's default CNI (kindnet) does **not** enforce
> NetworkPolicies. Use Calico/Cilium for real enforcement.

## 4. Required configuration
| Setting | Where | Notes |
|---|---|---|
| `DATABASE_URL` | Secret `db-credentials` (`connection-string`) | secret must be pre-created in `sakina-api` namespace |
| `SAKINA_API_TOKEN` | Secret `sakina-api-auth` (`api-token`) | required for protected API routes |
| `QDRANT_URL` | API deployment env | `http://qdrant.sakina-data:6333` |
| `VLLM_URL` | API deployment env | points at the vLLM service |
| `VLLM_CHAT_MODEL` | API deployment env | OpenAI-compatible chat model name served by vLLM |
| `VLLM_EMBEDDING_MODEL` | API + ingestion env | OpenAI-compatible embedding model name served by vLLM |
| `QDRANT_COLLECTION` | API + ingestion env | defaults to `verified_knowledge` |
| `QDRANT_VECTOR_SIZE` | ingestion env | must match the embedding model dimension |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | API deployment env | OTLP gRPC endpoint, e.g. Jaeger/collector `http://jaeger.sakina-monitoring.svc.cluster.local:4317` |
| Grafana admin pw | `monitoring/grafana.yaml` | **change** `sakina_admin` before any non-local use |
| PostgreSQL password | Secret `postgres-auth` (`POSTGRES_PASSWORD`) | secret must be pre-created in `sakina-data` namespace |

## 4a. HTTPS ingress
`manifests/sakina-api-ingress.yaml` defines the public HTTPS API entry point for
`api.sakinaapp.com` using `ingressClassName: traefik` and a TLS secret named
`sakina-api-tls`. For cert-manager automation, install cert-manager and create a
`ClusterIssuer` named `sakina-letsencrypt-prod` before applying production
traffic.

The checked-in Ingress is standard `networking.k8s.io/v1` so it validates even
before Traefik/cert-manager CRDs are installed. mTLS between internal services
still requires a service mesh or Traefik CRD-based TLSOptions and is not proven
by this manifest alone.

## 5. Database
Schema is created by `db/init.sql` (run automatically by the postgres
StatefulSet via the `postgres-init` ConfigMap). To re-run manually:
```bash
kubectl port-forward -n sakina-data svc/postgres 5432:5432
psql -h localhost -U sakina_user -d sakina < sakina-backend/db/init.sql
```
Load verified texts after review. The ingestion binary creates the Qdrant
collection if needed, stores SHA-256 source integrity hashes, writes chunks to
Postgres, and upserts chunk vectors to Qdrant:
```bash
cargo run --release --bin sakina-ingest -- --path data/verified-texts
```

## 6. Monitoring
- Prometheus: `kubectl port-forward -n sakina-monitoring svc/prometheus 9090:9090` → `/-/ready`.
- Grafana: `…svc/grafana 3000:3000` → `/api/health` (Prometheus + Jaeger datasources pre-provisioned).
- Jaeger: `…svc/jaeger 16686:16686`. The API exports spans through OTLP when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set; otherwise local runs fall back to stdout.
- API metrics: `/metrics` exposes Prometheus text metrics for users, verified
  chunks, guardrail triggers, and encrypted backups.

## 7. Pre-created secrets (required)
Before applying manifests in production/staging, create:

```bash
kubectl create secret generic db-credentials -n sakina-api \
  --from-literal=connection-string='postgres://...'

kubectl create secret generic sakina-api-auth -n sakina-api \
  --from-literal=api-token='replace-with-strong-token'

kubectl create secret generic postgres-auth -n sakina-data \
  --from-literal=POSTGRES_PASSWORD='replace-with-strong-password'
```

## Known gaps before this is genuinely production-ready
- vLLM inference is unverified in this environment (no GPU here); RAG now calls
  vLLM chat completions, but this still requires live model validation.
- Qdrant client + embeddings compile but were not run against live services.
- No load test, no penetration test, no real verified-texts corpus loaded.
- Traefik/cert-manager controllers and internal service mTLS are not installed
  by these manifests; the HTTPS Ingress contract is present, but the cluster
  operators must install the controllers and issuer.
- If GHCR packages are private, pods enter `ErrImagePull`/`ImagePullBackOff`
  until an image pull secret is attached to the target service account.
- vLLM requires GPU quota (`nvidia.com/gpu`) and sufficient CPU/memory; on
  small nodes the API may need temporary reduced requests for staging smoke
  tests before production sizing is restored.
