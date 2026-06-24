# Sakina Local Database Configuration

This document describes the local development database path used when the
default PostgreSQL port `5432` is already occupied by another local service.

## Local compose override

Use the Sakina compose file plus the local override:

```bash
POSTGRES_PASSWORD=sakina_password \
docker compose \
  -f sakina-infra/docker-compose.yml \
  -f sakina-infra/docker-compose.local.yml \
  up -d postgres qdrant
```

## Local host connection string

After the local compose stack starts, use:

```text
postgres://sakina_user:sakina_password@localhost:5434/sakina
```

## Local RAG / backend proof environment

Use these local/dev defaults for the smoke scripts and backend:

```text
DATABASE_URL=postgres://sakina_user:sakina_password@localhost:5434/sakina
QDRANT_URL=http://localhost:6333
VLLM_URL=mock://deterministic
SAKINA_API_BASE_URL=http://localhost:8080
ISLAMIC_QDRANT_COLLECTION=sakina_islamic_chunks_en
VLLM_EMBEDDING_DIM=128
```

## Why this exists

The base compose file keeps the canonical in-network PostgreSQL service name
(`postgres`) unchanged for the Sakina API container, but maps the host port to
`5434` for local proof runs when `5432` is already taken by another service.
