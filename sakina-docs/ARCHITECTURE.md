# Project Sakina - Architecture Guide

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Mobile App                      │
│  (RTL/LTR, Local SQLCipher, Encrypted Sync)                 │
└──────────────┬──────────────────────────────────────────────┘
               │ TLS 1.3
┌──────────────▼──────────────────────────────────────────────┐
│              Kubernetes Cluster (Local)                      │
├──────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐  ┌──────────────┐  ┌────────────────┐  │
│ │  Actix-Web API  │  │  vLLM Router │  │  RAG Engine    │  │
│ │  (8080)         │  │  (8000)      │  │  (Guardrails)  │  │
│ └────────┬────────┘  └──────┬───────┘  └────────┬───────┘  │
│          │                   │                    │           │
├──────────┼───────────────────┼────────────────────┼─────────┤
│ ┌────────▼──────────────────────────────────────────────┐  │
│ │          PostgreSQL (5432)  │  Qdrant (6333)         │  │
│ │  Users │ Audit │ Backups    │  Vector DB             │  │
│ └────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│                  Audit Enclave (Append-Only)                 │
└──────────────────────────────────────────────────────────────┘
```

## Component Details

### Frontend (Flutter)
- **Language**: Dart
- **State Management**: Riverpod
- **Local Storage**: SQLCipher (AES-256)
- **Features**: Offline-first, encrypted sync, dual language

### Backend (Rust)
- **Framework**: Actix-web
- **Database**: SQLx + PostgreSQL
- **Vector Search**: Qdrant client
- **LLM Integration**: vLLM HTTP client
- **Patterns**: Outbox pattern for consistency

### Infrastructure (Kubernetes)
- **Orchestration**: Minikube or kind
- **Storage**: Local path provisioner
- **Networking**: Network policies (default-deny)
- **Monitoring**: Prometheus + Grafana (optional)

### LLM (vLLM)
- **Model**: Falcon-7B or Qwen-8B
- **Quantization**: AWQ (4-bit) or FP8
- **Max Context**: 8192 tokens
- **API**: OpenAI-compatible

### Vector Database (Qdrant)
- **Collection**: `verified_knowledge`
- **Embedding Dim**: 768
- **Distance**: Cosine
- **Payload**: Madhhab, scholar, authenticity grade

### Relational Database (PostgreSQL)
- **Schema**: `verified_knowledge`, `audit`, `outbox`, `public`
- **Backup**: user_backups (encrypted)
- **Audit**: Append-only logs
- **Consistency**: Outbox pattern with relay

## Data Flow

### Query Processing
1. User submits query in Flutter app
2. Intent classifier routes to appropriate handler
3. If Fiqh/Tafsir query:
   - Embed query using local model
   - Vector search in Qdrant (with madhhab filter)
   - Check similarity threshold (0.85)
   - If below threshold → guardrail rejection
   - If above threshold → pass to vLLM with context
4. Generate response with citations
5. Return to client with source references

### Data Ingestion
1. Raw texts uploaded and normalized
2. Semantic chunking with Arabic-aware separators
3. Chunk inserted to PostgreSQL in transaction
4. Outbox event created (same transaction)
5. Outbox relay picks up event
6. Generate embedding using local model
7. Upsert to Qdrant
8. Mark event as sent
9. If failure → move to dead letter queue

## Security Model

### Encryption

**At Rest**:
- SQLCipher: AES-256 for mobile local storage
- Postgres: Native encryption optional
- Qdrant: File-level encryption (filesystem)

**In Transit**:
- TLS 1.3 for external APIs
- mTLS between internal services

### Access Control

- **Network Policies**: Default-deny, explicit allow
- **Database**: Role-based access
- **API**: Rate limiting + authentication
- **Audit**: Segregated, immutable logs

## Performance Characteristics

- **API Latency**: < 500ms (p95) for simple queries
- **RAG Latency**: < 2s (p95) for complex queries
- **Throughput**: 100 req/s per API instance
- **LLM Inference**: ~200ms per 50 tokens
- **Vector Search**: ~50ms for 1M vectors

## Scaling Considerations

- Horizontal: Multiple API replicas behind load balancer
- Vertical: Increase Kubernetes node resources
- vLLM: Add more GPU nodes for inference scaling
- Database: PostgreSQL read replicas + Qdrant clustering

---

See `/sakina-docs` for detailed guides.
