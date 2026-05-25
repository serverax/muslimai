# Production Deployment — Project Sakina

> **Status (honest):** the backend (Rust) and frontend (Flutter) compile and pass
> their unit/compile tests. The full stack has **not** been deployed or
> integration-tested in CI/this environment — there is no GPU (so no vLLM), and
> the deploy below has been validated only with `kubectl --dry-run=client`. Treat
> this as the deployment *procedure*, not a record of a live production run.

## Prerequisites
- Docker + a Kubernetes cluster (local: `kind`; prod: managed k8s).
- A node with a **GPU** for vLLM (embeddings + generation). Without it, `/rag/query`
  cannot embed or generate — RAG returns errors/fallbacks.
- `kubectl`, `make`.

## 1. Build & load images
```bash
cd sakina-backend
docker build -f Dockerfile.api  -t sakina-backend-api:latest  .
# vLLM image requires CUDA base + a GPU host:
docker build -f Dockerfile.vllm -t sakina-backend-vllm:latest .

# kind only:
kind load docker-image sakina-backend-api:latest --name sakina
```

## 2. Namespaces + DB layer
```bash
cd sakina-infra
make setup-k8s          # kind cluster + sakina-{data,api,core,audit} namespaces
make dev-start          # postgres + qdrant (builds postgres-init ConfigMap from db/init.sql)
kubectl wait --for=condition=ready pod -l app=postgres -n sakina-data --timeout=300s
```

## 3. Deploy everything
```bash
make deploy             # kubectl apply -R -f manifests/  (API, network-policies, monitoring/)
```
This applies: `storage-class`, `postgres`, `qdrant`, `brand-configmap`,
`network-policies`, `sakina-api-deployment`, and `monitoring/` (prometheus,
grafana, jaeger). The `sakina-api` pods need the image (step 1) or they sit in
`ErrImageNeverPull`.

> **kind caveat:** kind's default CNI (kindnet) does **not** enforce
> NetworkPolicies. Use Calico/Cilium for real enforcement.

## 4. Required configuration
| Setting | Where | Notes |
|---|---|---|
| `DATABASE_URL` | `sakina-api-deployment.yaml` Secret `db-credentials` | matches `db/init.sql` creds |
| `QDRANT_URL` | API deployment env | `http://qdrant.sakina-data:6333` |
| vLLM endpoint | API source (`main.rs`) | currently `http://localhost:8000`; point at the vLLM service |
| Grafana admin pw | `monitoring/grafana.yaml` | **change** `sakina_admin` before any non-local use |
| DB password | Secret + `db/init.sql` + `postgres-config` | rotate for production; use sealed-secrets |

## 5. Database
Schema is created by `db/init.sql` (run automatically by the postgres
StatefulSet via the `postgres-init` ConfigMap). To re-run manually:
```bash
kubectl port-forward -n sakina-data svc/postgres 5432:5432
psql -h localhost -U sakina_user -d sakina < sakina-backend/db/init.sql
```
Then create the Qdrant collection:
```bash
curl -X PUT http://localhost:6333/collections/verified_knowledge \
  -H 'Content-Type: application/json' \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```
Load verified texts: `cargo run --release --bin sakina-ingest -- --path data/verified-texts`.

## 6. Monitoring
- Prometheus: `kubectl port-forward -n sakina-monitoring svc/prometheus 9090:9090` → `/-/ready`.
- Grafana: `…svc/grafana 3000:3000` → `/api/health` (Prometheus + Jaeger datasources pre-provisioned).
- Jaeger: `…svc/jaeger 16686:16686`. **Note:** the API currently exports OTel spans to
  stdout; switch `telemetry.rs` to `opentelemetry-otlp` (→ `jaeger:4317`) to see traces in Jaeger.
- The API's `prometheus.io/scrape` annotation points at `/metrics`, which is **not yet
  implemented** — add a metrics endpoint before relying on Prometheus app metrics.

## Known gaps before this is genuinely production-ready
- vLLM inference is unverified (no GPU here); RAG answer generation is a placeholder.
- Qdrant client + embeddings compile but were not run against live services.
- No load test, no penetration test, no real verified-texts corpus loaded.
- Traefik / cert-manager / mTLS from the original plan are not implemented.
