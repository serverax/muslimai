# Troubleshooting — Project Sakina

## Backend (Rust)

### Build runs out of memory (`rustc-LLVM ERROR: out of memory`)
This machine OOMs compiling the full dependency tree in parallel. **Always build
single-threaded:**
```bash
cargo test -j 1
cargo clippy -j 1 --all-targets -- -D warnings
```

### A dependency change breaks `sqlx-core` / `thiserror` (`::core::write`)
This was the `sqlx 0.7.4` + new-rustc landmine, fixed by bumping to **sqlx 0.8**.
If you see it again after editing deps, you likely re-resolved an incompatible
lockfile — restore a known-good lock: `git checkout <good-commit> -- sakina-backend/Cargo.lock`.

### `openssl`/native-tls fails to build on Windows
Don't pull `openssl` or reqwest's `native-tls`. We use `sqlx` `tls-rustls-ring`
and `reqwest` with `default-features=false, features=["json"]` (no TLS — local
http only). For https, add a rustls feature deliberately.

### `cargo clippy -- -D warnings` fails on dead code
A service that isn't wired into a handler/`main` is dead in the bin crate. Either
wire it in or keep it as lib-only public API (`main.rs` consumes the lib via
`use sakina_backend::{...}`; don't re-declare modules with `mod`).

### Adding a new crate
Safe now that `sqlx` is 0.8. Prefer crates that don't pull `tonic` (gRPC) to
avoid the OOM tree — e.g., we use Qdrant's **REST** API via `reqwest`, not the
`qdrant-client` gRPC crate.

## Runtime

### `/rag/query` errors or returns fallbacks
Real RAG needs three live services that are **not** stubbed anymore:
1. **vLLM** at the embeddings URL (needs a GPU) — `curl http://<vllm>/v1/models`.
2. **Qdrant** with an indexed `verified_knowledge` collection — `curl http://<qdrant>:6333/collections/verified_knowledge`.
3. **Postgres** with `db/init.sql` applied and chunks ingested.
Without all three, the handler returns the "consult a scholar" fallback or an error.

### API pod stuck `ErrImageNeverPull`
Build + load the image: `docker build -f Dockerfile.api -t sakina-backend-api:latest .`
then `kind load docker-image sakina-backend-api:latest --name sakina`.

### NetworkPolicies seem ignored
kind's default CNI (kindnet) does not enforce NetworkPolicies. Install Calico/Cilium.

## Frontend (Flutter)

### `flutter pub get` version conflicts
The constraints are aligned to Flutter 3.44 via `pub upgrade --major-versions`.
On a newer SDK, re-run it. `sqflite_sqlcipher`/`cryptography` were left at `any`
(pinned by `pubspec.lock`).

### `flutter build apk` fails / no `android` scaffold
The platform folders are partial. Run `flutter create .` in `sakina-frontend/`
to regenerate `android/`+`ios/`, then build. APK needs the Android SDK; iOS needs macOS.

## Operations

### Scale API replicas
`kubectl scale deployment/sakina-api -n sakina-api --replicas=N` (manifest defaults to 3).

### Add new verified Islamic texts
Drop `.txt` files in `sakina-backend/data/verified-texts/`, then:
`cargo run --release --bin sakina-ingest -- --path data/verified-texts`
(currently uses a simple paragraph splitter; the Arabic semantic chunker in
`chunking.py` is the intended path once bridged).

### See traces in Jaeger
`telemetry.rs` currently exports OTel spans to **stdout**. Swap the stdout
exporter for `opentelemetry-otlp` pointed at `http://jaeger.sakina-monitoring:4317`.
