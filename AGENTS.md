# Project Sakina — Agent Notes

## Cursor Cloud specific instructions

This repo is a multi-component "Sovereign Islamic AI" system. Most of the marketing
docs (`00-START-HERE.md`, `README.md`, etc.) describe a full Kubernetes + vLLM + Qdrant
stack. **That full stack is NOT runnable in the Cloud VM** (no GPU, no Docker/`kind`).
What *is* runnable for day-to-day development is documented below.

### Components & how to run them

| Component | Path | Stack | Status in Cloud VM |
|-----------|------|-------|--------------------|
| Backend API | `sakina-backend` | Rust / Actix-web + Postgres | ✅ builds, lints, tests, runs |
| Chunker | `sakina-backend/chunking.py` | Python | ✅ unit tests run (pure fns) |
| Integration tests | `sakina-tests` | Python / pytest | ✅ partial (see RAG note) |
| Dashboard | `sakina-dashboard` | static Vue (CDN) | ✅ runs (see CORS note) |
| Frontend | `sakina-frontend` | Flutter (mobile) | ✅ pub get / analyze / test / web build |
| Infra | `sakina-infra` | k8s manifests, docker-compose | ❌ needs Docker/kind/GPU |

Standard build/test/run commands live in the root `Makefile`, `sakina-infra/Makefile`,
and `.github/workflows/*.yml`; prefer those rather than re-deriving commands.

### Rust toolchain (important)
Backend dependencies require `edition2024`, so the **stable** toolchain (1.96+) must be
the default — the bundled rustc 1.83 fails with "feature `edition2024` is required".
`rustup default stable` is already configured in the VM snapshot.

### PostgreSQL
The backend needs Postgres. It is installed (apt, v16) but is a **service**, so start it
each session (it is not started by the update script):
```
sudo pg_ctlcluster 16 main start
```
Database `sakina` (user `sakina_user`, password `sakina_password`) and the schema
(`sakina-backend/db/init.sql`) are loaded into the snapshot. Run the API with:
```
cd sakina-backend
DATABASE_URL="postgres://sakina_user:sakina_password@127.0.0.1:5432/sakina" cargo run --bin sakina-api
```
Health: `curl http://localhost:8080/v1/health`. The `users`, `classify`, and
`dashboard/guardrails` endpoints work without any external service.

### Known limitation: RAG / vLLM / Qdrant
`POST /v1/rag/query` (and `sakina-tests/integration/test_rag_query.py`) require a live
vLLM embeddings server (`:8000`) and Qdrant (`:6333`). Neither runs here (GPU/Docker),
so that endpoint returns 500 and that one integration test fails **by design** — it is
not an environment regression. `test_health_check` and `test_classify_intent` pass.

### Known limitation: `cargo fmt -- --check`
The committed `src/main.rs` is not rustfmt-clean, so the CI `cargo fmt -- --check` lint
fails on unmodified code. `cargo clippy -- -D warnings` and `cargo test` pass.

### Python
Use the repo-root virtualenv `.venv` (the update script keeps it populated):
```
. .venv/bin/activate
cd sakina-backend && python -m pytest chunking_test.py     # pure, always passes
cd sakina-tests && python -m pytest integration/           # needs API running on :8080
```

### Dashboard (CORS gotcha)
`sakina-dashboard` is static and fetches `http://localhost:8080/v1/...`. The API ships
**no CORS headers**, so opening the static files directly from a different port is blocked
by the browser. To demo it, serve it same-origin with the API (e.g. a small reverse proxy
that forwards `/v1/*` to `:8080`) or set `window.SAKINA_API_BASE` to a same-origin path.

### Frontend (Flutter)
Flutter SDK lives at `/opt/flutter/bin` (add to `PATH`). It is a **mobile** app with no
committed web/Android scaffolding. `flutter pub get`, `flutter analyze`, and
`flutter test` work as-is. To run it in a browser for a quick demo, scaffold web first
(do **not** commit the generated `web/` dir):
```
export PATH="/opt/flutter/bin:$PATH"
cd sakina-frontend
flutter create . --platforms=web
flutter build web            # then serve build/web with any static server
```
Building an APK requires the Android SDK (not installed).
