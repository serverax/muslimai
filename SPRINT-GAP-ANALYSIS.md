# SPRINT GAP ANALYSIS - PROJECT SAKINA
## What's Missing from Original Sprint Plan

> **Accuracy corrections applied to this draft (vs. the original):**
> 1. Sprint 3 "What's stubbed" payloads now match the real handlers (the
>    originals were wrong and contradicted the integration tests).
> 2. Sprint 0 PVCs: only postgres (10Gi) + qdrant (5Gi) exist — there is no
>    2Gi audit PVC.
> 3. Sprint 4 frontend snippets flagged where they need packages not in
>    `pubspec.yaml` (Dio, SQLCipher, ChaCha/ECDH).
> 4. Reflects work added this session: `network-policies.yaml` and
>    `sakina-api-deployment.yaml` now exist (root) and pass `kubectl --dry-run=client`.

---

# EXECUTIVE SUMMARY

**Current State:** scaffolding + architecture complete; business logic largely stubbed.
**Missing:** business logic, data pipeline, frontend services, security hardening, operations.

| Category | Status | Gap |
|----------|--------|-----|
| Scaffolding | ✅ done | — |
| Endpoints (routes) | ✅ done | logic is stubbed |
| Infrastructure | ⚠️ partial | Traefik, mTLS (NetworkPolicies + API manifest now drafted) |
| Business Logic | ⚠️ stubs only | Router, guardrails, citation, ingestion |
| Data Pipeline | ❌ 0% | Ingestion, chunker, outbox relay, data |
| Frontend Services | ❌ 0% | LocalDB, Sync, API wiring, citations |
| Operations | ❌ 0% | Monitoring, dashboards, tracing |

---

# SPRINT 0: LOCAL K8S FOUNDATION

## Planned
```
minikube/kind cluster; 4 namespaces (sakina-core/data/audit/api);
StorageClass local-storage (hostPath); PVCs; Makefile; CI/CD; Docker Compose
```

## Actual (on disk)
```
✅ Kind cluster setup (Makefile setup-k8s)
✅ 4 namespaces configured
✅ StorageClass defined (storage-class.yaml)
✅ PVCs via volumeClaimTemplates: postgres 10Gi, qdrant 5Gi  (NO separate audit PVC)
✅ Makefile complete
✅ CI/CD workflows done
✅ Docker Compose complete
✅ NetworkPolicies (network-policies.yaml — default-deny + allow rules, this session)
✅ sakina-api Deployment+Service+SA+Secret (sakina-api-deployment.yaml, this session)
❌ Traefik API Gateway (rate limiting)
❌ cert-manager + mTLS
```

> Note on NetworkPolicies: cross-namespace rules select namespaces by the
> built-in `kubernetes.io/metadata.name` label. `network-policies.yaml`,
> `sakina-api-deployment.yaml`, and `monitoring/` now live under `manifests/`,
> and `make deploy` uses `kubectl apply -R -f manifests/`, so they are applied.
> The sakina-api pods need `make load-image` first. NOTE: kind's default CNI
> (kindnet) does NOT enforce NetworkPolicies — use Calico if you need enforcement.

### Still missing: Traefik API Gateway
Rate limiting (100/min API, 20/min RAG), TLS termination, single entry point.
Files: `sakina-infra/helm/traefik-values.yaml`, `manifests/traefik-ingressroute.yaml`. **~3-4 days.**

### Still missing: cert-manager + mTLS
SelfSignedIssuer internal CA, per-service certs, rotation. **~4-5 days.**

---

# SPRINT 1: DATA INGESTION & SCHEMA

## Status
```
✅ PostgreSQL StatefulSet, Qdrant StatefulSet, schema (init.sql)
❌ Ingestion producer (ACID), Outbox relay (FOR UPDATE SKIP LOCKED),
   ArabicSemanticChunker, Ingestion Job, Verified-texts data
```

### Missing: Ingestion Producer (`src/services/ingestion_producer.rs`)
Read text → chunk → INSERT chunk → embed → upsert Qdrant → INSERT outbox → COMMIT/ROLLBACK. **~5-7 days.**

### Missing: Outbox Relay (`src/services/outbox_relay.rs`)
`SELECT ... FOR UPDATE SKIP LOCKED`, send to Qdrant, mark Sent/Failed, retry to max_retries=5. **~3-4 days.**

### Missing: ArabicSemanticChunker
Normalize/strip diacritics, split on markers (باب/فصل/مسألة), 512-token chunks w/ 50-100 overlap.
> Architecture note: proposed as Python (`chunking.py`) inside the Rust backend —
> decide whether ingestion is a Rust path or a separate Python sidecar/job before building. **~4-5 days.**

### Missing: Ingestion Job (`manifests/ingestion-job.yaml`) + verified-texts data
Batch Job scanning `data/verified-texts/`. Data sourcing is external (public-domain Quran/Hadith, licensed fiqh). **~2-3 days + sourcing.**

---

# SPRINT 2: RAG ENGINE & GUARDRAILS

## Status
```
✅ vLLM Dockerfile
⚠️ SemanticRouter / Guardrails / CitationEngine exist as EMPTY STUB STRUCTS
❌ real logic, audit logging wiring
```

### Missing: SemanticRouter logic (`src/services/semantic_router.rs`)
Classify FiqhQuery / TafsirQuery / CompanionChat / OutOfScope. **~4-5 days.**

### Missing: Guardrails logic (`src/services/guardrails.rs`)
Embed query → Qdrant top-k → if max score < 0.85 return "consult a scholar" (bypass LLM); madhhab filter; log triggers. **~3-4 days.**

### Missing: Citation Engine logic (`src/services/citation.rs`)
Map chunk → source_document → {title, author, chapter, authenticity_grade}. **~3-4 days.**

### Missing: Audit logging wiring
Schema (`audit.logs`) exists; nothing writes to it yet. Wire RAG queries + guardrail triggers. **~2-3 days.**

---

# SPRINT 3: API

## Status
```
✅ Actix-web structure; all routes (/v1/users, /v1/rag/query, /v1/classify, /v1/sync/backup, /v1/dashboard/guardrails)
✅ sakina-api-deployment.yaml (3 replicas, liveness/readiness on /v1/health) — added this session
❌ endpoint business logic (stubs), sync/backup encryption
```

### What's stubbed (ACTUAL current responses — corrected)
```
POST /v1/rag/query   → {answer:"Response to: <query>", sources:[{id,title,author,chapter,authenticity_grade}],
                        confidence:0.92, guardrail_triggered:false, processing_time_ms:450}
POST /v1/classify    → {intent:"FiqhQuery", confidence:0.95, routing_decision:"RAG"}
POST /v1/users       → {id:<uuid>, pub_key, madhhab_preference, created_at}
POST /v1/sync/backup → {success:true, backup_hash:"sha256_hash", sync_timestamp:<rfc3339>}
GET  /v1/sync/backup/{user_id} → body "encrypted_backup_data" (literal placeholder)
GET  /v1/dashboard/guardrails  → [{timestamp, query, trigger_reason, user_id:null}]
```
(The integration tests in `sakina-tests/integration/test_rag_query.py` assert
`answer`/`sources` and `intent`/`confidence`, which match these real stubs.)

### What needs implementing
- **/v1/rag/query:** route → guardrails(0.85) → vLLM(top-k) → citations → audit log → answer+sources+confidence.
- **/v1/classify:** SemanticRouter → intent+confidence.
- **/v1/users:** real INSERT into `public.users`; derive/store pub key.
- **/v1/sync/backup (POST/GET):** server-blind encrypted blob store. **~6-8 days total.**

### Missing: Sync/Backup Encryption (`src/services/sync.rs`)
Ephemeral keypair → ECDH → KDF → ChaCha20-Poly1305; return ephemeral_pub || ciphertext || tag. **~3-4 days.**

### WASM Microservices — status unclear
Tokenization=Python chunker, embedding=vLLM, encryption=client crypto — none currently WASM. Clarify intent before building.

---

# SPRINT 4: FLUTTER FRONTEND

## Status
```
✅ structure, Riverpod, ApiConfig+theme, chat screen, brand widgets
❌ LocalDBService, SyncService, API wiring, Citation UI
```

> **Package gap (important):** the proposed snippets below assume packages NOT in
> the current `pubspec.yaml`. Before implementing, add/swap:
> - HTTP client: pubspec has **`http`**, snippets use **`dio`** → either add `dio` or rewrite with `http`.
> - Encrypted local DB: pubspec has plain **`sqflite`** (no cipher) → use **`sqflite_sqlcipher`** for SQLCipher.
> - ChaCha20-Poly1305 / ECDH: the **`encrypt`** package is AES-oriented → add **`cryptography`**.

### Missing: LocalDBService (`lib/services/local_db_service.dart`)
SQLCipher-encrypted SQLite for chat history / offline mode. **~4-5 days.** (needs `sqflite_sqlcipher`)

### Missing: SyncService (`lib/services/sync_service.dart`)
Encrypt local state → upload; download → decrypt → restore. **~4-5 days.** (needs `cryptography`)

### Missing: API Service Integration (`lib/services/api_service.dart`)
Wire send button → `POST /v1/rag/query`; render answer + sources; loading/error states. **~3-4 days.** (use `http`, or add `dio`)

### Missing: Citation UI (`lib/widgets/citation_widget.dart`)
Source badges/dialog (title, author, chapter, grade) using `SakinaBrand.colorAccent`. **~2-3 days.**

---

# SPRINT 5: SECURITY & AUDIT DASHBOARD

## Status
```
✅ /dashboard/guardrails endpoint (stub), audit.logs schema
❌ Dashboard UI, audit logging wiring, penetration testing
```

- **Dashboard UI** (`sakina-dashboard/`): guardrail triggers, low-confidence monitor, system health. Vue + Chart.js. **~5-7 days.**
- **Audit logging wiring**: middleware writing to `audit.logs` (schema exists, unused). **~2-3 days.**
- **Penetration testing**: authn/authz, input validation, SQLi, data-at-rest/in-transit. **~3-5 days (external firm).**

---

# OPERATIONS / ALPHA TARGETS

```
⚠️ TestFlight / Play internal — app not built yet (toolchains missing)
⚠️ Prometheus + Grafana — manifests created (manifests/monitoring/), but the API
   has no /metrics endpoint yet, so there's nothing app-level to scrape
⚠️ Jaeger — all-in-one manifest created (OTLP enabled); still needs OpenTelemetry
   instrumentation in the Rust code
```
- **Prometheus + Grafana** manifests + a real `/metrics` endpoint in the API. **~4-5 days.**
- **Jaeger tracing**: OpenTelemetry instrumentation in `main.rs` + handlers. **~4-5 days.**

---

# SUMMARY

| Sprint | Gap | Priority | Effort |
|--------|-----|----------|--------|
| 0 | Traefik, mTLS (NetworkPolicies + API manifest drafted) | High | ~7 days |
| 1 | Ingestion, chunker, outbox, data | Critical | ~14 days |
| 2 | Router, guardrails, citation, audit logic | Critical | ~12 days |
| 3 | Endpoint logic, sync encryption | Critical | ~10 days |
| 4 | LocalDB, sync, API wiring, citations (+ package adds) | Critical | ~12 days |
| 5 | Dashboard, audit wiring, pentest | High | ~8 days |
| Ops | Prometheus, Grafana, Jaeger, /metrics | High | ~8 days |

**Total remaining: ~71 days of engineering (rough order-of-magnitude).**

---

# HANDOFF SUMMARY

**Delivered:** complete scaffolding, all routes (stubbed), schemas, infra (DB layer
+ NetworkPolicies + API manifest drafted), brand identity wired in, tests prepared,
CI/CD configured. Config validated client-side; not compiled (no Rust/Flutter here).

**Next team:** implement the 5 service modules; wire endpoints; build frontend
services (after adding the missing packages); add Traefik/mTLS; add monitoring +
`/metrics`; pentest; load verified Islamic texts.

No architectural redesign needed — implementation only.

---

Made with precision, intelligence, and respect for privacy. 🙏

Project Sakina: Sovereign. Intelligent. Secure. Islamic.
