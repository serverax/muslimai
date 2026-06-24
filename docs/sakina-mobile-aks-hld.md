# Sakina Mobile AKS High-Level Design

## Scope
Fresh isolated staging infrastructure for Sakina Mobile in UK South using dedicated resource names and namespaces only.

## Target Azure Resources
- Resource Group: `rg-sakina-mobile-staging-uksouth`
- AKS: `aks-sakina-mobile-staging`
- ACR: `acrsakinamobilestg`
- PostgreSQL Flexible Server: `pg-sakina-mobile-staging`
- Redis Cache: `redis-sakina-mobile-staging`
- Storage Account: `stsakinamobilestg`
- Key Vault: `kv-sakina-mobile-stg`

## Kubernetes Namespaces
- `sakina-mobile-staging`
- `sakina-rag-staging`
- `sakina-monitoring-staging`
- `sakina-security-staging`

## Principles
1. Never mutate non-Sakina-Mobile live workloads.
2. Isolated node pools, identities, ingress, and secrets boundaries.
3. Secrets referenced via Key Vault CSI/External Secrets only.
4. All deployments gated by CI checks and smoke tests.

## Runtime Topology
- `sakina-mobile-staging`: backend API, mobile-config endpoint, workers
- `sakina-rag-staging`: retrieval service and vector indexing worker
- `sakina-monitoring-staging`: Prometheus/Grafana/alert routing
- `sakina-security-staging`: policy agents and admission controls

## Networking
- Private cluster preferred, public API server restricted if private unavailable.
- Ingress through dedicated controller and hostnames under staging domain.
- Egress controls for OpenAI and Azure dependencies.

## Data Plane
- PostgreSQL used as source-of-truth transactional store.
- Redis used for cache/session/rate-limit.
- Blob storage for artifacts and RAG source bundles.

## Delivery Gates
- Infrastructure plan review.
- Schema migration validation.
- Backend and mobile smoke verification.
- Security and policy baseline pass.
