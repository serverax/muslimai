# Setup Guide

## Prerequisites
- Rust (stable) + Cargo — backend
- Flutter >= 3.16 — frontend
- Docker — container builds
- kubectl + kind — local Kubernetes
- make — task runner
- PostgreSQL client (psql) — DB init
- Python 3.11+ + pytest + requests — integration tests

## Backend
```bash
cd sakina-backend
cargo build --release
cargo test
```

Set `DATABASE_URL` to point at Postgres (defaults to
`postgres://sakina_user:sakina_password@localhost:5432/sakina`).

## Frontend
```bash
cd sakina-frontend
flutter pub get
flutter analyze
flutter test
```

## Local infrastructure (Docker Compose)
```bash
cd sakina-infra
docker compose up -d postgres qdrant
```

## Local infrastructure (Kubernetes)
```bash
cd sakina-infra
make setup-k8s     # create kind cluster + namespaces
make dev-start     # start postgres + qdrant
make deploy        # deploy all manifests
make health        # check pods
```

## Database initialization
```bash
psql -h localhost -U sakina_user -d sakina < sakina-backend/db/init.sql
```

## Qdrant collection
```bash
curl -X PUT http://localhost:6333/collections/verified_knowledge \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```
