# Sakina AI — Architecture Handoff

Date: 2026-06-22.

## What it is
Controlled Islamic AI companion: Rust/actix-web backend + Flutter frontend, RAG-grounded answers with citations, scholar escalation for high-risk fatwa, internal-only LLM via a gateway. No direct frontend→LLM access (verified).

## Components
- **Backend** (`sakina-backend`, Rust/actix-web): single crate, 4 binaries — `sakina-api`, `sakina-llm-gateway`, `sakina-migrate`, `sakina-ingest`. ~120 HTTP routes. Services: brain controller/policy, decision algorithm (mother), hybrid+graph RAG, embeddings, qdrant client, guardrails, pii redaction, fatwa verifier, llm gateway.
- **Frontend** (`sakina-frontend`, Flutter): real http client → api-gateway; secure JWT storage.
- **Datastores**: Postgres 15 (113 app tables across public/sakina_ai/audit/outbox/verified_knowledge), Qdrant (vectors), Redis (cache).
- **LLM**: Ollama (internal) behind `sakina-llm-gateway`; default model `qwen2.5:0.5b`.

## Deployment topologies
- **Monolithic** (`docker-compose.qa.yml` / `docker-compose.yml`): one `sakina-api` does brain/rules/rag/citation internally. Runtime-proven this session.
- **Distributed** (`docker-compose.distributed.yml`): api-gateway → brain → {rules-engine, rag-service, citation-guard} → llm-gateway → ollama. Activated by `SAKINA_*_URL` env vars; api forwards `/api/sakina/ask` to Brain when `SAKINA_BRAIN_URL` set.
- **k8s/Talos**: manifests under `sakina-infra/manifests` (+ overlays, sakina-prod). Not runtime-tested (no cluster).

## Highest-priority flow (`POST /api/sakina/ask`)
auth → workspace → PII redact → intent/lang (keyword) → trace_uuid → local topic lookup → [rules engine] → safety classifier (keyword) → brain route → hybrid RAG → [LLM compose, gated by enabled+context+safety+citation] → [citation guard if configured] → empty→refuse fallback → persist trace+answer → return → enqueue scholar review if high-risk. Trace persisted to `brain_decision_traces` + `ask_shaikh_answers` for every non-distributed answer.

## Key env flags
`SAKINA_LLM_ENABLED`, `SAKINA_LLM_GATEWAY_URL`, `SAKINA_RULES_ENGINE_URL`, `SAKINA_CITATION_GUARD_URL`, `SAKINA_BRAIN_URL`, `DATABASE_URL`, `JWT_SECRET` (≥32), `ENCRYPTION_KEY` (≥32), `QDRANT_URL`, `SAKINA_REDIS_URL`, `ALLOW_MOCK_*` (fail-closed), `CORS_ALLOWED_ORIGINS`.

## Architecture-level risks (see issue register)
- Two answer engines; the citation-gated `decide` engine is dead (SAK-021); live path keyword-based.
- No auth middleware — per-handler opt-in (SAK-001 root cause).
- RLS enabled but inert for the app role (SAK-006); isolation is app-layer only.
- Monolithic mode lacks the external citation guard (SAK-005) and rules engine.

## Build / run (proven commands)
```
docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .
docker compose -f sakina-infra/docker-compose.qa.yml --env-file sakina-infra/.env down -v
docker compose -f sakina-infra/docker-compose.qa.yml --env-file sakina-infra/.env up -d postgres qdrant redis
docker compose -f sakina-infra/docker-compose.qa.yml --env-file sakina-infra/.env run --rm api sakina-migrate
docker compose -f sakina-infra/docker-compose.qa.yml --env-file sakina-infra/.env up -d --no-deps api llm-gateway
# api on http://localhost:28080  (ollama needs host :11434 free)
```
Note: host `cargo` is blocked by an Application Control policy (os error 4551) — build the backend **inside Docker**, not on the host. Flutter is not installed on this host.
