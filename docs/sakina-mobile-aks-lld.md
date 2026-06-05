# Sakina Mobile AKS Low-Level Design

## Cluster Baseline
- Kubernetes version: latest supported stable in UK South
- System pool: 3x Linux nodes
- User pool: autoscaling enabled for API and RAG workloads
- Managed identity enabled
- OIDC issuer + workload identity enabled

## Namespace Design
### `sakina-mobile-staging`
- Deployments: `sakina-backend-api`, `sakina-sync-worker`
- Services: `backend-api`, `metrics`
- ConfigMaps: `backend-runtime-config`

### `sakina-rag-staging`
- Deployments: `sakina-rag-indexer`, `sakina-rag-query`
- Jobs/CronJobs: chunk refresh and embedding refresh

### `sakina-monitoring-staging`
- Deployments: `prometheus`, `grafana`, `loki` (optional)

### `sakina-security-staging`
- Gatekeeper/Kyverno policies
- Image policy and namespace guard rails

## Identity & Secret Flow
1. AKS workload identity maps service accounts to user-assigned identities.
2. Key Vault stores DB/Redis/API secrets.
3. CSI driver mounts secret material as files or env references.

## Observability
- Standard Kubernetes metrics + app metrics endpoint.
- Structured logs with correlation IDs.
- Alert channels for API availability and error budget burn.

## Release Sequence
1. Terraform plan/apply to target RG only.
2. Bootstrap namespaces and policies.
3. Apply DB migrations and verify schema.
4. Deploy backend then RAG services.
5. Run smoke tests for backend and mobile config.
