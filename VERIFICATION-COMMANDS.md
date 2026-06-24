# VERIFICATION-COMMANDS.md
## Exact copy-paste commands for Project Sakina after toolchain installation

Run these commands in sequence after installing Rust, Flutter, Kind, and Make.

> Accuracy note: corrected to match the actual repo. `make deploy` only applies
> the DB-layer manifests (there is no API/vLLM Kubernetes manifest yet), the
> integration tests need the API started separately, and the Flutter suite has
> two tests. iOS builds are macOS-only.

---

## PREREQUISITES

Ensure all 4 toolchains are installed and accessible:

```powershell
rustc --version          # Should show: rustc 1.75.0 or later
cargo --version          # Should show: cargo 1.75.0 or later
flutter --version        # Should show: Flutter 3.16.0 or later
kind version             # Should show: kind vX.XX.X
make --version           # Should show: GNU Make 4.3 or later
```

If any fail, install that toolchain first.

---

## PART 1: VERIFY BACKEND (Rust)

```powershell
cd F:\SakinaAL\sakina-backend

# Check compilation (no build artifacts, just syntax/dependency check)
cargo check
# Expected: Finished dev [unoptimized + debuginfo] target(s)
# Note: first run downloads heavy crates (qdrant-client, tonic, openssl). On
# Windows, the `openssl` crate needs a system OpenSSL + Perl; if it fails, set
# `openssl = { version = "0.10", features = ["vendored"] }` in Cargo.toml.

# Run Rust linter (clippy) with warnings-as-errors (matches GitHub Actions CI)
cargo clippy -- -D warnings
# Expected: Finished, no warnings

# Run backend unit tests
cargo test
# Expected: test result: ok. 1 passed (lib it_works)

# Build optimized release binary
cargo build --release
# Expected binary: target\release\sakina-api.exe
```

---

## PART 2: VERIFY FRONTEND (Flutter)

```powershell
cd F:\SakinaAL\sakina-frontend

# Download all Dart dependencies
flutter pub get
# Expected: Got dependencies

# Analyze Dart code for errors/warnings
flutter analyze
# Expected: No issues found!

# Run Flutter widget tests
flutter test
# Expected output:
#   00:0X +2: All tests passed!
#   (two tests: 'Chat screen renders title and input',
#               'Typing and sending appends a message')

# Build release APK (Android)
flutter build apk --release
# Expected: build\app\outputs\flutter-apk\app-release.apk

# Build release IPA (iOS) -- macOS ONLY. This step fails on Windows/Linux.
# flutter build ios --release
```

---

## PART 3: INFRASTRUCTURE (Kubernetes, DB layer)

```powershell
cd F:\SakinaAL\sakina-infra

# Create local kind cluster + 4 namespaces
make setup-k8s
# Expected: cluster created; namespaces sakina-data, sakina-api, sakina-core, sakina-audit

# Verify cluster
kubectl cluster-info

# List namespaces (expect the 4 sakina-* plus defaults)
kubectl get namespaces
```

```powershell
# Start PostgreSQL + Qdrant. dev-start also builds the postgres-init ConfigMap
# from sakina-backend/db/init.sql before applying the manifests.
make dev-start
# Expected (roughly):
#   configmap/postgres-init configured
#   storageclass/persistentvolume ... created
#   statefulset.apps/postgres created
#   statefulset.apps/qdrant created

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n sakina-data --timeout=300s
kubectl wait --for=condition=ready pod -l app=qdrant   -n sakina-data --timeout=300s

# Health
make health
```

```powershell
# Test database connectivity (run port-forward in its own terminal/window)
kubectl port-forward -n sakina-data svc/postgres 5432:5432
psql -h localhost -U sakina_user -d sakina -c "SELECT version();"
```

> Qdrant note: the deployment's liveness probe uses `GET /health`. Recent Qdrant
> images serve `/healthz` (not `/health`); if the pod never becomes ready, change
> the probe path in `manifests/qdrant-deployment.yaml` to `/healthz`.

```powershell
# Apply ALL manifests recursively. `make deploy` == `kubectl apply -R -f manifests/`,
# which now includes: storage-class, postgres, qdrant, brand-configmap,
# network-policies, sakina-api-deployment, and monitoring/ (prometheus, grafana, jaeger).
# The sakina-api pods need the image first (otherwise ErrImageNeverPull):
make load-image   # docker build + kind load sakina-backend-api:latest
make deploy
# Note: kind's default CNI (kindnet) does NOT enforce NetworkPolicies; they apply
# cleanly but only take effect under an enforcing CNI such as Calico.
# There is still no vLLM manifest (needs a GPU).

# Verify pods
kubectl get pods -A
# Expected (once the image is loaded):
#   sakina-data         postgres-0     1/1   Running
#   sakina-data         qdrant-0       1/1   Running
#   sakina-api          sakina-api-…   1/1   Running   (x3)
#   sakina-monitoring   prometheus-…   1/1   Running
#   sakina-monitoring   grafana-…      1/1   Running
#   sakina-monitoring   jaeger-…       1/1   Running
#   (no vLLM pod — no manifest; needs a GPU)
```

---

## PART 4: INTEGRATION TESTS

The tests in `sakina-tests/integration/` hit a live API at `http://localhost:8080`.
Once `make load-image` + `make deploy` are done and the sakina-api pods are
Running, you can `kubectl port-forward -n sakina-api svc/sakina-api 8080:8080`.
If you have not built/loaded the image yet, bring the stub API up one of these
two ways instead.

```powershell
cd F:\SakinaAL\sakina-tests
pip install -r requirements.txt   # pytest + requests
```

**Option A — run the API locally with cargo** (needs Postgres reachable on :5432):
```powershell
# Terminal 1: expose Postgres from the cluster (or use docker compose, below)
kubectl port-forward -n sakina-data svc/postgres 5432:5432

# Terminal 2: run the stub API
cd F:\SakinaAL\sakina-backend
$env:DATABASE_URL = "postgres://sakina_user:sakina_password@localhost:5432/sakina"
cargo run
# Handlers are stubs: /health checks the DB pool; /rag/query and /classify
# return canned JSON. No Qdrant/vLLM needed for the current tests.
```

**Option B — run API + databases via docker compose** (no kubectl needed):
```powershell
cd F:\SakinaAL\sakina-infra
docker compose up -d postgres qdrant api   # do NOT start `vllm` (needs a GPU)
```

Then run the tests:
```powershell
cd F:\SakinaAL\sakina-tests
pytest integration/ -v
# Expected:
#   test_health_check PASSED
#   test_rag_query PASSED
#   test_classify_intent PASSED
#   ==== 3 passed in X.XXs ====
```

---

## SUMMARY CHECKLIST

### Backend
- [ ] `cargo check` completed without errors
- [ ] `cargo clippy -- -D warnings` completed without warnings
- [ ] `cargo test` passed
- [ ] `cargo build --release` created `target\release\sakina-api.exe`

### Frontend
- [ ] `flutter pub get` resolved dependencies
- [ ] `flutter analyze` found no issues
- [ ] `flutter test` — both tests passed
- [ ] `flutter build apk --release` created APK
- [ ] (macOS only) `flutter build ios --release` created the iOS app

### Infrastructure (DB layer)
- [ ] `make setup-k8s` created the cluster + 4 namespaces
- [ ] `kubectl cluster-info` reachable
- [ ] `make dev-start` started postgres + qdrant
- [ ] `kubectl wait` reported both pods ready
- [ ] `make deploy` applied DB-layer manifests (no API/vLLM manifest exists yet)
- [ ] postgres-0 and qdrant-0 are Running

### Integration
- [ ] `pip install -r requirements.txt` succeeded
- [ ] API started via Option A or B
- [ ] `pytest integration/ -v` — 3 passed

---

## TROUBLESHOOTING

### `cargo check` fails
```powershell
cargo clean
cargo check
```

### `flutter pub get` stalls
```powershell
flutter clean
flutter pub get
```

### `make setup-k8s` fails
```powershell
docker ps                         # Docker must be running
kind get clusters
kind delete cluster --name sakina # remove a stale cluster
make setup-k8s
```

### Pods won't start
```powershell
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace>
```

### Port-forward fails
```powershell
# Find and stop an existing port-forward
Get-Process kubectl -ErrorAction SilentlyContinue | Stop-Process
kubectl port-forward -n <namespace> svc/<service> <port>:<port>
```

---

## FULL VERIFICATION SEQUENCE (PowerShell)

```powershell
# Backend
cd F:\SakinaAL\sakina-backend; cargo check; if ($LASTEXITCODE) { return }
cargo clippy -- -D warnings; if ($LASTEXITCODE) { return }
cargo test; cargo build --release

# Frontend (iOS build omitted — macOS only)
cd F:\SakinaAL\sakina-frontend; flutter pub get; flutter analyze; flutter test; flutter build apk --release

# Infrastructure (DB layer)
cd F:\SakinaAL\sakina-infra; make setup-k8s; make dev-start; make health

# Integration (start the API first — see Part 4 Option A/B; pytest needs :8080)
cd F:\SakinaAL\sakina-tests; pip install -r requirements.txt; pytest integration/ -v
```

---

Made with precision, intelligence, and respect for privacy. 🙏

Project Sakina: Sovereign. Intelligent. Secure. Islamic.
