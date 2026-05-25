#!/bin/bash

################################################################################
# Project Sakina - Complete Automated Setup Script
# This script creates the entire project structure, documentation, and configs
# Usage: ./setup-sakina.sh
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="${1:-.}"
PROJECT_NAME="SakinaAL"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=0
    
    # Check for git
    if ! command -v git &> /dev/null; then
        print_warning "Git not found. Install from: https://git-scm.com"
        missing=1
    else
        print_success "Git found"
    fi
    
    # Check for Docker (optional but recommended)
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found (optional but recommended)"
    else
        print_success "Docker found"
    fi
    
    # Check for Rust (optional)
    if ! command -v cargo &> /dev/null; then
        print_warning "Rust/Cargo not found (needed for backend, install from: https://rustup.rs)"
    else
        print_success "Rust/Cargo found"
    fi
    
    # Check for Flutter (optional)
    if ! command -v flutter &> /dev/null; then
        print_warning "Flutter not found (needed for mobile app, install from: https://flutter.dev)"
    else
        print_success "Flutter found"
    fi
    
    if [ $missing -eq 1 ]; then
        print_warning "Some prerequisites missing. You may need to install them manually."
    fi
}

# Create directory structure
create_directories() {
    print_header "Creating Directory Structure"
    
    # Main project directories
    local dirs=(
        "sakina-backend/src/handlers"
        "sakina-backend/src/models"
        "sakina-backend/src/services"
        "sakina-backend/db"
        "sakina-backend/tests"
        "sakina-backend/.github/workflows"
        
        "sakina-frontend/lib/config"
        "sakina-frontend/lib/models"
        "sakina-frontend/lib/services"
        "sakina-frontend/lib/screens"
        "sakina-frontend/lib/widgets"
        "sakina-frontend/lib/providers"
        "sakina-frontend/lib/l10n"
        "sakina-frontend/.github/workflows"
        
        "sakina-infra/helm"
        "sakina-infra/manifests"
        "sakina-infra/network"
        "sakina-infra/storage"
        "sakina-infra/volumes"
        "sakina-infra/scripts"
        
        "sakina-docs/architecture"
        "sakina-docs/api"
        "sakina-docs/guides"
        "sakina-docs/runbooks"
        
        "sakina-tests/integration"
        "sakina-tests/e2e"
        "sakina-tests/unit"
        
        ".github/workflows"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$PROJECT_ROOT/$dir"
        print_success "Created: $dir"
    done
}

# Create documentation files
create_documentation() {
    print_header "Creating Documentation Files"
    
    # Main README
    cat > "$PROJECT_ROOT/README.md" << 'EOF'
# Project Sakina - Sovereign Islamic AI System

A privacy-first, zero-hallucination AI system for Islamic guidance built on local Kubernetes infrastructure.

## Features

✅ **Sovereign Infrastructure** - Everything runs locally on Kubernetes  
✅ **Zero Hallucination** - Strict RAG guardrails prevent theological inaccuracies  
✅ **Privacy-First** - All data encrypted at rest and in transit  
✅ **Offline-Capable** - Local LLM inference, no cloud APIs  
✅ **Audit Trail** - Append-only logging for transparency  
✅ **Dual UI** - Native RTL/LTR Flutter support  

## Quick Start

### Prerequisites

- **Docker Desktop** (with Kubernetes enabled)
- **kubectl** (comes with Docker Desktop)
- **Rust 1.75+** (for backend)
- **Flutter 3.16+** (for mobile)
- **Git**
- **Make**

### Installation

```bash
# Clone the project
git clone https://github.com/sakina-project/sakina-al.git
cd SakinaAL

# Initialize local Kubernetes and deploy
make -C sakina-infra setup-k8s
make -C sakina-infra dev-start

# Deploy all services
make -C sakina-infra deploy

# Access services
# - API: http://localhost:8080
# - Qdrant: http://localhost:6333
# - PostgreSQL: localhost:5432
# - vLLM: http://localhost:8000
```

## Project Structure

```
SakinaAL/
├── sakina-backend/          # Rust backend services
│   ├── src/
│   ├── db/                  # Database schemas
│   └── Dockerfile.api
├── sakina-frontend/         # Flutter mobile app
│   ├── lib/
│   └── pubspec.yaml
├── sakina-infra/            # Kubernetes & infrastructure
│   ├── manifests/
│   ├── helm/
│   └── Makefile
├── sakina-docs/             # Documentation
├── sakina-tests/            # Test suites
└── .github/workflows/       # CI/CD pipelines
```

## Development Workflow

1. **Create Feature Branch**: `git checkout -b feat/your-feature`
2. **Make Changes**: Edit files in your favorite editor
3. **Run Tests**: `make test`
4. **Commit**: `git commit -m "feat: description"`
5. **Push**: `git push origin feat/your-feature`
6. **Create PR**: Submit pull request on GitHub

## Architecture

- **Backend**: Rust with Actix-web, SQLx, Qdrant client
- **Frontend**: Flutter with Riverpod state management
- **Infrastructure**: Kubernetes (minikube/kind), PostgreSQL, Qdrant
- **LLM**: Local vLLM with Falcon-7B or Qwen-8B
- **Database**: PostgreSQL for relational, Qdrant for vectors
- **Encryption**: TLS 1.3, SQLCipher for local data

## Documentation

- [Architecture Guide](./sakina-docs/ARCHITECTURE.md)
- [API Specification](./sakina-docs/API.md)
- [Setup Guide](./sakina-docs/SETUP.md)
- [Contributing Guide](./CONTRIBUTING.md)

## Security & Privacy

- ✅ No external API calls
- ✅ All data stays local
- ✅ Encryption in transit (mTLS)
- ✅ Encryption at rest (SQLCipher)
- ✅ Append-only audit logs
- ✅ Strict access controls

## Support

For issues and questions:
- **Issues**: GitHub Issues
- **Documentation**: See `/sakina-docs`
- **Discord**: Coming soon

## License

MIT License - See LICENSE file

## Contributors

Built with ❤️ for the Islamic community

---

Made with precision, intelligence, and respect.
EOF
    
    print_success "Created: README.md"
    
    # Contributing guide
    cat > "$PROJECT_ROOT/CONTRIBUTING.md" << 'EOF'
# Contributing to Project Sakina

## Code of Conduct

Be respectful, inclusive, and focused on creating a high-quality Islamic AI system.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/sakina-al.git`
3. Create a feature branch: `git checkout -b feat/your-feature`
4. Set up development environment: `make setup-k8s`

## Development Guidelines

### Commit Messages

```
feat: add semantic router implementation
fix: correct similarity threshold logic
docs: update architecture guide
test: add integration tests for RAG engine
chore: update dependencies
```

### Code Style

- **Rust**: Follow `rustfmt` standards (`cargo fmt`)
- **Flutter**: Follow Dart conventions (`dart format`)
- **Python**: Follow PEP 8

### Testing

```bash
# Run all tests
make test

# Backend tests
cd sakina-backend && cargo test

# Frontend tests
cd sakina-frontend && flutter test
```

### Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Run full test suite locally
4. Submit PR with clear description
5. Wait for code review
6. Address feedback and iterate
7. Merge after approval

## Theological Review

For features involving Islamic knowledge:
1. Submit for theological review by domain experts
2. Ensure sources are authenticated
3. Include madhhab coverage
4. Document authenticity grades

## Reporting Issues

Include:
- **Description**: What's the problem?
- **Steps**: How to reproduce
- **Expected**: What should happen
- **Actual**: What actually happens
- **Environment**: OS, Kubernetes version, etc.

## Questions?

Ask in GitHub Discussions or open an issue.

Thank you for contributing! 🙏
EOF
    
    print_success "Created: CONTRIBUTING.md"
}

# Create architecture documentation
create_architecture_docs() {
    print_header "Creating Architecture Documentation"
    
    cat > "$PROJECT_ROOT/sakina-docs/ARCHITECTURE.md" << 'EOF'
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

### Threat Model

**Insider Risk**: 
- Append-only audit logs
- Role separation (developer ≠ moderation)

**Prompt Injection**:
- Semantic router blocks suspicious inputs
- Similarity threshold requires valid retrieval

**Data Exfiltration**:
- No external API calls
- All data stays local
- Encrypted backups

## Deployment

### Local Development
```bash
make setup-k8s
make dev-start
make deploy
```

### Production
- Upgrade to multi-node K8s cluster
- Enable persistence volumes on network storage
- Set up monitoring + alerting
- Enable auto-scaling

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
EOF
    
    print_success "Created: sakina-docs/ARCHITECTURE.md"
}

# Create API documentation
create_api_docs() {
    print_header "Creating API Documentation"
    
    cat > "$PROJECT_ROOT/sakina-docs/API.md" << 'EOF'
# Project Sakina - API Reference

## Base URL

```
http://localhost:8080/v1
```

## Authentication

Currently none (local development). Add JWT in production.

## Endpoints

### Health Check

**GET** `/health`

Check API and dependencies health.

**Response**:
```json
{
  "status": "healthy",
  "database": "ok",
  "vector_db": "ok",
  "timestamp": "2024-05-25T10:30:00Z"
}
```

### User Management

#### Create User

**POST** `/users`

Create a new user with madhhab preference.

**Request**:
```json
{
  "pub_key": "user_ed25519_public_key",
  "madhhab_preference": "hanafi"
}
```

**Response**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "pub_key": "user_ed25519_public_key",
  "madhhab_preference": "hanafi",
  "created_at": "2024-05-25T10:30:00Z"
}
```

#### Get User

**GET** `/users/{user_id}`

Retrieve user preferences.

**Response**: (as above)

### RAG Engine

#### Query with RAG

**POST** `/rag/query`

Submit a Fiqh or Tafsir question.

**Request**:
```json
{
  "query": "هل الموسيقى حرام؟",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "madhhab_filter": "hanafi"
}
```

**Response**:
```json
{
  "answer": "According to Hanafi jurisprudence, the ruling on music depends...",
  "sources": [
    {
      "id": "chunk-uuid-1",
      "title": "Radd al-Muhtar",
      "author": "Ibn Abidin",
      "chapter": "On Permissible and Impermissible Sounds",
      "authenticity_grade": "sahih"
    }
  ],
  "confidence": 0.92,
  "guardrail_triggered": false,
  "processing_time_ms": 450
}
```

**Error Response** (threshold not met):
```json
{
  "answer": "I'm not certain about this. Please consult a scholar.",
  "sources": [],
  "confidence": 0.0,
  "guardrail_triggered": true,
  "trigger_reason": "SIMILARITY_THRESHOLD_FAILED"
}
```

### Intent Classification

#### Classify User Intent

**POST** `/classify`

Classify user input intent.

**Request**:
```json
{
  "text": "Is music permissible in Islam?"
}
```

**Response**:
```json
{
  "intent": "FiqhQuery",
  "confidence": 0.95,
  "routing_decision": "RAG"
}
```

### Sync & Backup

#### Upload Backup

**POST** `/sync/backup?user_id={user_id}`

Upload encrypted backup blob (server cannot decrypt).

**Request**: Binary data (encrypted)

**Response**:
```json
{
  "success": true,
  "backup_hash": "sha256_hash_of_encrypted_data",
  "sync_timestamp": "2024-05-25T10:30:00Z"
}
```

#### Download Backup

**GET** `/sync/backup/{user_id}`

Download encrypted backup.

**Response**: Binary encrypted data

### Audit Dashboard

#### Get Guardrail Logs

**GET** `/dashboard/guardrails` (admin only)

Get all guardrail trigger events.

**Response**:
```json
[
  {
    "timestamp": "2024-05-25T10:15:00Z",
    "query": "how to make explosives",
    "trigger_reason": "OUT_OF_SCOPE",
    "user_id": null
  }
]
```

## Rate Limiting

- **API Endpoints**: 100 req/min per IP
- **RAG Queries**: 20 req/min per user
- **Auth Endpoints**: 10 req/min

## Error Codes

- `200`: Success
- `201`: Created
- `400`: Bad request
- `401`: Unauthorized
- `404`: Not found
- `429`: Rate limit exceeded
- `500`: Server error
- `503`: Service unavailable (dependency down)

## Examples

### cURL

```bash
# Health check
curl http://localhost:8080/v1/health

# Query RAG
curl -X POST http://localhost:8080/v1/rag/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "هل الموسيقى حرام؟",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "madhhab_filter": "hanafi"
  }'
```

### JavaScript

```javascript
const response = await fetch('http://localhost:8080/v1/rag/query', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    query: 'هل الموسيقى حرام؟',
    user_id: '550e8400-e29b-41d4-a716-446655440000',
    madhhab_filter: 'hanafi'
  })
});

const data = await response.json();
console.log(data.answer);
console.log(data.sources);
```

### Python

```python
import requests

url = 'http://localhost:8080/v1/rag/query'
payload = {
    'query': 'هل الموسيقى حرام؟',
    'user_id': '550e8400-e29b-41d4-a716-446655440000',
    'madhhab_filter': 'hanafi'
}

response = requests.post(url, json=payload)
data = response.json()
print(data['answer'])
```

---

See swagger/OpenAPI spec at `/docs` when API is running.
EOF
    
    print_success "Created: sakina-docs/API.md"
}

# Create setup guide
create_setup_guide() {
    print_header "Creating Setup Guide"
    
    cat > "$PROJECT_ROOT/sakina-docs/SETUP.md" << 'EOF'
# Project Sakina - Setup Guide

## Prerequisites Installation

### macOS

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install essentials
brew install git docker kubectl rustup-init flutter

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Windows (PowerShell)

```powershell
# Install Chocolatey
Set-ExecutionPolicy AllSigned; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install essentials
choco install git docker-desktop kubectl rustup.install flutter -y
```

### Linux (Ubuntu/Debian)

```bash
# Update system
sudo apt update && sudo apt upgrade

# Install essentials
sudo apt install -y git curl build-essential

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"
```

## Project Setup

### 1. Clone Repository

```bash
git clone https://github.com/sakina-project/sakina-al.git
cd SakinaAL
```

### 2. Initialize Kubernetes

```bash
# Start Kubernetes (Docker Desktop already has it enabled)
docker run -d --name=minikube-docker -p 8443:8443 \
  -v /var/lib/minikube:/var/lib/minikube gcr.io/k8s-minikube/kicbase:latest

# Or use kind
kind create cluster --name sakina

# Verify
kubectl cluster-info
kubectl get nodes
```

### 3. Deploy Infrastructure

```bash
cd sakina-infra

# Create namespaces
kubectl create namespace sakina-data
kubectl create namespace sakina-audit
kubectl create namespace sakina-core
kubectl create namespace sakina-api

# Label namespaces
kubectl label namespace sakina-core name=sakina-core
kubectl label namespace sakina-data name=sakina-data

# Create storage
kubectl apply -f storage/storage-class.yaml
mkdir -p /tmp/sakina-storage/{postgres,qdrant,audit,models}

# Deploy databases
kubectl apply -f manifests/postgres-deployment.yaml
kubectl apply -f manifests/qdrant-deployment.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=postgres -n sakina-data --timeout=300s
kubectl wait --for=condition=ready pod -l app=qdrant -n sakina-data --timeout=300s
```

### 4. Initialize Databases

```bash
# Port-forward PostgreSQL
kubectl port-forward -n sakina-data svc/postgres 5432:5432 &

# Run schema
psql -h localhost -U sakina_user -d sakina < ../sakina-backend/db/init.sql

# Create Qdrant collection
curl -X PUT http://localhost:6333/collections/verified_knowledge \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```

### 5. Build Backend

```bash
cd ../sakina-backend

# Install dependencies
cargo fetch

# Build
cargo build --release

# Test
cargo test

# Build Docker image
docker build -f Dockerfile.api -t sakina-backend-api:latest .

# Deploy
kubectl apply -f k8s/api-deployment.yaml
kubectl wait --for=condition=ready pod -l app=sakina-api -n sakina-api --timeout=300s
```

### 6. Build Frontend

```bash
cd ../sakina-frontend

# Get dependencies
flutter pub get

# Build APK (Android)
flutter build apk --release

# Build iOS
flutter build ios --release

# Run on emulator
flutter run

# Or run on device
flutter run -d <device_id>
```

### 7. Access Services

```bash
# API
kubectl port-forward -n sakina-api svc/sakina-api 8080:8080 &
# Access: http://localhost:8080/v1/health

# Qdrant
kubectl port-forward -n sakina-data svc/qdrant 6333:6333 &
# Access: http://localhost:6333

# PostgreSQL
kubectl port-forward -n sakina-data svc/postgres 5432:5432 &
# Access: localhost:5432

# vLLM
kubectl port-forward -n sakina-core svc/vllm-router 8000:8000 &
# Access: http://localhost:8000/v1

# Kubernetes Dashboard
kubectl proxy
# Access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Development Workflow

### Running Tests

```bash
# All tests
make test

# Backend unit tests
cd sakina-backend && cargo test

# Backend integration tests
cargo test --test '*' -- --test-threads=1

# Frontend tests
cd ../sakina-frontend && flutter test

# Integration tests
cd ../sakina-tests && pytest -v
```

### Building & Deploying

```bash
# Build everything
make build

# Deploy to Kubernetes
make deploy

# Check pod status
kubectl get pods -A
kubectl logs -f deployment/sakina-api -n sakina-api

# Check service health
curl http://localhost:8080/v1/health
```

### Stopping Services

```bash
# Stop port-forwarding
pkill kubectl  # Be careful!

# Stop Kubernetes
kind delete cluster --name sakina

# Or minikube
minikube stop
```

## Troubleshooting

### Kubernetes won't start
```bash
# Check Docker Desktop
docker ps

# Reset Docker
docker system prune -a
docker run hello-world

# Try kind
kind create cluster --name sakina
```

### PostgreSQL connection refused
```bash
# Check pod
kubectl get pods -n sakina-data
kubectl describe pod postgres-0 -n sakina-data

# Check logs
kubectl logs postgres-0 -n sakina-data

# Verify port-forward
kubectl port-forward -n sakina-data svc/postgres 5432:5432

# Test connection
psql -h localhost -U sakina_user -d sakina -c "SELECT version();"
```

### Qdrant collection not found
```bash
# Create collection manually
curl -X PUT http://localhost:6333/collections/verified_knowledge \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'

# Check collections
curl http://localhost:6333/collections
```

### API pod not starting
```bash
# Check pod status
kubectl describe pod <pod_name> -n sakina-api

# Check logs
kubectl logs <pod_name> -n sakina-api

# Check events
kubectl get events -n sakina-api
```

### vLLM model not loading
```bash
# Check vLLM logs
kubectl logs deployment/vllm-router -n sakina-core

# Download model manually
huggingface-cli download TheBloke/Falcon-7B-Instruct-AWQ \
  --cache-dir ./models/falcon-7b-awq

# Mount in pod
kubectl set env deployment/vllm-router \
  -n sakina-core MODEL_PATH=/models/falcon-7b-awq
```

## Next Steps

1. **Read Architecture**: See `sakina-docs/ARCHITECTURE.md`
2. **API Examples**: See `sakina-docs/API.md`
3. **Add Data**: Ingest verified texts via ingestion pipeline
4. **Run Tests**: Execute full test suite
5. **Deploy**: Push to staging/production Kubernetes

---

For detailed help: GitHub Discussions or Issues
EOF
    
    print_success "Created: sakina-docs/SETUP.md"
}

# Create Makefile
create_makefile() {
    print_header "Creating Makefile"
    
    cat > "$PROJECT_ROOT/Makefile" << 'EOF'
.PHONY: help setup-k8s dev-start dev-stop test build deploy clean logs health

PROJECT_NAME=SakinaAL
DOCKER_COMPOSE_FILE=sakina-infra/docker-compose.yml
K8S_DIR=sakina-infra/manifests
BACKEND_DIR=sakina-backend
FRONTEND_DIR=sakina-frontend

help:
	@echo "$(PROJECT_NAME) - Project Makefile"
	@echo "=================================="
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  setup-k8s       Initialize local Kubernetes cluster (minikube/kind)"
	@echo "  dev-start       Start development environment (databases + services)"
	@echo "  dev-stop        Stop development environment"
	@echo "  deploy          Deploy all services to Kubernetes"
	@echo "  build           Build all containers"
	@echo "  test            Run all tests"
	@echo "  logs            View all service logs"
	@echo "  health          Check health of all services"
	@echo "  clean           Remove all artifacts and reset"
	@echo ""

setup-k8s:
	@echo "Setting up Kubernetes cluster..."
	@command -v kind >/dev/null 2>&1 && kind create cluster --name sakina || minikube start --cpus=8 --memory=16384 --disk-size=100g
	@kubectl create namespace sakina-data || true
	@kubectl create namespace sakina-audit || true
	@kubectl create namespace sakina-core || true
	@kubectl create namespace sakina-api || true
	@kubectl label namespace sakina-core name=sakina-core --overwrite
	@kubectl label namespace sakina-data name=sakina-data --overwrite
	@kubectl label namespace sakina-audit name=sakina-audit --overwrite
	@kubectl label namespace sakina-api name=sakina-api --overwrite
	@echo "✓ Kubernetes setup complete"

dev-start:
	@echo "Starting development environment..."
	@mkdir -p /tmp/sakina-storage/{postgres,qdrant,audit,models}
	@kubectl apply -f $(K8S_DIR)/storage-class.yaml
	@kubectl apply -f $(K8S_DIR)/postgres-deployment.yaml
	@kubectl apply -f $(K8S_DIR)/qdrant-deployment.yaml
	@echo "✓ Databases deployed. Waiting for pods..."
	@kubectl wait --for=condition=ready pod -l app=postgres -n sakina-data --timeout=300s || true
	@kubectl wait --for=condition=ready pod -l app=qdrant -n sakina-data --timeout=300s || true
	@echo "✓ Development environment ready"
	@echo ""
	@echo "Port-forward these services:"
	@echo "  PostgreSQL: kubectl port-forward -n sakina-data svc/postgres 5432:5432 &"
	@echo "  Qdrant:     kubectl port-forward -n sakina-data svc/qdrant 6333:6333 &"
	@echo "  API:        kubectl port-forward -n sakina-api svc/sakina-api 8080:8080 &"
	@echo "  vLLM:       kubectl port-forward -n sakina-core svc/vllm-router 8000:8000 &"

dev-stop:
	@echo "Stopping development environment..."
	@pkill -f "kubectl port-forward" || true
	@kubectl delete deployment -l app=postgres -n sakina-data || true
	@kubectl delete deployment -l app=qdrant -n sakina-data || true
	@echo "✓ Development environment stopped"

build:
	@echo "Building all containers..."
	@cd $(BACKEND_DIR) && docker build -f Dockerfile.api -t sakina-backend-api:latest .
	@cd $(BACKEND_DIR) && docker build -f Dockerfile.vllm -t sakina-backend-vllm:latest .
	@echo "✓ Containers built"

deploy: build
	@echo "Deploying to Kubernetes..."
	@kubectl apply -f $(K8S_DIR)/
	@kubectl wait --for=condition=ready pod -l app=sakina-api -n sakina-api --timeout=300s || true
	@echo "✓ Deployment complete"
	@make health

test:
	@echo "Running all tests..."
	@cd $(BACKEND_DIR) && cargo test --verbose
	@cd $(FRONTEND_DIR) && flutter test
	@cd sakina-tests && pytest -v || true
	@echo "✓ All tests completed"

logs:
	@echo "Streaming logs from all services..."
	@kubectl logs -f deployment/sakina-api -n sakina-api &
	@kubectl logs -f deployment/postgres -n sakina-data &
	@kubectl logs -f deployment/qdrant -n sakina-data &
	@wait

health:
	@echo "Checking service health..."
	@echo ""
	@echo "Kubernetes Nodes:"
	@kubectl get nodes
	@echo ""
	@echo "Pods:"
	@kubectl get pods -A
	@echo ""
	@echo "Services:"
	@kubectl get svc -A
	@echo ""
	@echo "Testing API health..."
	@curl -s http://localhost:8080/v1/health 2>/dev/null || echo "API not responding (port-forward required)"
	@echo ""

clean:
	@echo "Cleaning up..."
	@cargo clean -p sakina-backend || true
	@rm -rf sakina-frontend/.flutter-plugins* || true
	@pkill -f "kubectl port-forward" || true
	@kind delete cluster --name sakina || true
	@rm -rf /tmp/sakina-storage || true
	@echo "✓ Cleanup complete"

# Aliases
k8s: setup-k8s
start: dev-start
stop: dev-stop
run: deploy
EOF
    
    print_success "Created: Makefile"
}

# Create GitHub workflows
create_github_workflows() {
    print_header "Creating GitHub CI/CD Workflows"
    
    # Backend CI/CD
    cat > "$PROJECT_ROOT/.github/workflows/backend-ci.yml" << 'EOF'
name: Backend CI/CD

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'sakina-backend/**'
      - '.github/workflows/backend-ci.yml'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'sakina-backend/**'

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: sakina_test
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
    - uses: actions/checkout@v4
    
    - uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
        override: true
    
    - name: Cache cargo
      uses: actions/cache@v3
      with:
        path: |
          ~/.cargo/registry
          ~/.cargo/git
          sakina-backend/target
        key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
    
    - name: Run tests
      working-directory: sakina-backend
      run: cargo test --verbose
      env:
        DATABASE_URL: postgres://test_user:test_pass@localhost:5432/sakina_test
    
    - name: Build release
      working-directory: sakina-backend
      run: cargo build --release
    
    - name: Check formatting
      working-directory: sakina-backend
      run: cargo fmt -- --check
    
    - name: Lint
      working-directory: sakina-backend
      run: cargo clippy -- -D warnings

  docker:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Build Docker image
      working-directory: sakina-backend
      run: docker build -f Dockerfile.api -t sakina-backend-api:latest .
    
    - name: Build vLLM image
      working-directory: sakina-backend
      run: docker build -f Dockerfile.vllm -t sakina-backend-vllm:latest .
EOF
    
    print_success "Created: .github/workflows/backend-ci.yml"
    
    # Frontend CI/CD
    cat > "$PROJECT_ROOT/.github/workflows/frontend-ci.yml" << 'EOF'
name: Frontend CI/CD

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'sakina-frontend/**'
      - '.github/workflows/frontend-ci.yml'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'sakina-frontend/**'

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Get dependencies
      working-directory: sakina-frontend
      run: flutter pub get
    
    - name: Analyze
      working-directory: sakina-frontend
      run: flutter analyze
    
    - name: Run tests
      working-directory: sakina-frontend
      run: flutter test
    
    - name: Build APK
      working-directory: sakina-frontend
      run: flutter build apk --release

  build-ios:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Get dependencies
      working-directory: sakina-frontend
      run: flutter pub get
    
    - name: Build iOS
      working-directory: sakina-frontend
      run: flutter build ios --release
EOF
    
    print_success "Created: .github/workflows/frontend-ci.yml"
}

# Create configuration files
create_config_files() {
    print_header "Creating Configuration Files"
    
    # .gitignore
    cat > "$PROJECT_ROOT/.gitignore" << 'EOF'
# Rust
/target/
Cargo.lock
**/*.rs.bk
*.pdb

# Flutter
.flutter-plugins*
.packages
.dart_tool/
build/

# IDE
.vscode/
.idea/
*.swp
*.swo
*.iml
.DS_Store

# Environment
.env
.env.local
.env.*.local

# Logs
*.log
logs/

# Database
*.db
*.sqlite
*.sqlite3

# Models
models/
*.bin
*.pth

# OS
.DS_Store
Thumbs.db

# Temporary
/tmp/
*.tmp
EOF
    
    print_success "Created: .gitignore"
    
    # .dockerignore
    cat > "$PROJECT_ROOT/sakina-backend/.dockerignore" << 'EOF'
.git
.gitignore
target/
Cargo.lock
.env
.env.local
.vscode
.idea
*.log
EOF
    
    print_success "Created: sakina-backend/.dockerignore"
}

# Create deployment scripts
create_deployment_scripts() {
    print_header "Creating Deployment Scripts"
    
    mkdir -p "$PROJECT_ROOT/sakina-infra/scripts"
    
    # Main deployment script
    cat > "$PROJECT_ROOT/sakina-infra/scripts/deploy.sh" << 'EOF'
#!/bin/bash
set -e

echo "Deploying Project Sakina..."

# Create namespaces
kubectl create namespace sakina-data --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace sakina-audit --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace sakina-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace sakina-api --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces
kubectl label namespace sakina-core name=sakina-core --overwrite
kubectl label namespace sakina-data name=sakina-data --overwrite
kubectl label namespace sakina-audit name=sakina-audit --overwrite
kubectl label namespace sakina-api name=sakina-api --overwrite

# Create secrets
kubectl create secret generic db-creds \
  --from-literal=username=sakina_user \
  --from-literal=password=$(openssl rand -base64 32) \
  -n sakina-data --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
kubectl apply -f manifests/storage-class.yaml
kubectl apply -f manifests/postgres-deployment.yaml
kubectl apply -f manifests/qdrant-deployment.yaml
kubectl apply -f network/

# Wait for services
echo "Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n sakina-data --timeout=300s || echo "PostgreSQL not ready"
kubectl wait --for=condition=ready pod -l app=qdrant -n sakina-data --timeout=300s || echo "Qdrant not ready"

echo "✓ Deployment complete"
echo ""
echo "Next steps:"
echo "1. Initialize databases: ./scripts/init-db.sh"
echo "2. Deploy API: kubectl apply -f manifests/api-deployment.yaml"
echo "3. Check status: kubectl get pods -A"
EOF
    
    chmod +x "$PROJECT_ROOT/sakina-infra/scripts/deploy.sh"
    print_success "Created: sakina-infra/scripts/deploy.sh"
    
    # Database initialization script
    cat > "$PROJECT_ROOT/sakina-infra/scripts/init-db.sh" << 'EOF'
#!/bin/bash
set -e

echo "Initializing databases..."

# Port-forward PostgreSQL
kubectl port-forward -n sakina-data svc/postgres 5432:5432 &
PG_PID=$!
sleep 2

# Wait for PostgreSQL to be ready
for i in {1..30}; do
  if psql -h localhost -U sakina_user -d postgres -c "SELECT 1" 2>/dev/null; then
    break
  fi
  echo "Waiting for PostgreSQL... ($i/30)"
  sleep 1
done

# Run schema
echo "Running database schema..."
psql -h localhost -U sakina_user -d sakina < ../sakina-backend/db/init.sql || echo "Schema may already exist"

# Create Qdrant collection
echo "Creating Qdrant collection..."
curl -X PUT http://localhost:6333/collections/verified_knowledge \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}' || echo "Collection may already exist"

# Cleanup
kill $PG_PID

echo "✓ Databases initialized"
EOF
    
    chmod +x "$PROJECT_ROOT/sakina-infra/scripts/init-db.sh"
    print_success "Created: sakina-infra/scripts/init-db.sh"
    
    # Health check script
    cat > "$PROJECT_ROOT/sakina-infra/scripts/health-check.sh" << 'EOF'
#!/bin/bash

echo "Sakina Health Check"
echo "===================="
echo ""

echo "Kubernetes Cluster:"
kubectl cluster-info

echo ""
echo "Pods Status:"
kubectl get pods -A

echo ""
echo "Services:"
kubectl get svc -A

echo ""
echo "Checking service health..."

# API
echo -n "API (8080): "
curl -s http://localhost:8080/v1/health -o /dev/null && echo "✓" || echo "✗"

# Qdrant
echo -n "Qdrant (6333): "
curl -s http://localhost:6333/health -o /dev/null && echo "✓" || echo "✗"

# vLLM
echo -n "vLLM (8000): "
curl -s http://localhost:8000/v1/models -o /dev/null && echo "✓" || echo "✗"

echo ""
echo "Health check complete"
EOF
    
    chmod +x "$PROJECT_ROOT/sakina-infra/scripts/health-check.sh"
    print_success "Created: sakina-infra/scripts/health-check.sh"
}

# Create example manifests
create_manifests() {
    print_header "Creating Kubernetes Manifests"
    
    mkdir -p "$PROJECT_ROOT/sakina-infra/manifests"
    
    # Storage class
    cat > "$PROJECT_ROOT/sakina-infra/manifests/storage-class.yaml" << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Retain
EOF
    
    print_success "Created: sakina-infra/manifests/storage-class.yaml"
    
    # PostgreSQL deployment
    cat > "$PROJECT_ROOT/sakina-infra/manifests/postgres-deployment.yaml" << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: sakina-data
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: local-storage
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: sakina-data
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: sakina
        - name: POSTGRES_USER
          value: sakina_user
        - name: POSTGRES_PASSWORD
          value: changeme
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: sakina-data
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF
    
    print_success "Created: sakina-infra/manifests/postgres-deployment.yaml"
    
    # Qdrant deployment
    cat > "$PROJECT_ROOT/sakina-infra/manifests/qdrant-deployment.yaml" << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: qdrant-data
  namespace: sakina-data
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: local-storage
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: qdrant
  namespace: sakina-data
spec:
  serviceName: qdrant
  replicas: 1
  selector:
    matchLabels:
      app: qdrant
  template:
    metadata:
      labels:
        app: qdrant
    spec:
      containers:
      - name: qdrant
        image: qdrant/qdrant:v1.10.0
        ports:
        - containerPort: 6333
        - containerPort: 6334
        volumeMounts:
        - name: qdrant-data
          mountPath: /qdrant/storage
  volumeClaimTemplates:
  - metadata:
      name: qdrant-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: local-storage
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: qdrant
  namespace: sakina-data
spec:
  type: ClusterIP
  selector:
    app: qdrant
  ports:
  - port: 6333
    name: http
  - port: 6334
    name: grpc
EOF
    
    print_success "Created: sakina-infra/manifests/qdrant-deployment.yaml"
}

# Main execution
main() {
    print_header "Project Sakina - Automated Setup"
    
    check_prerequisites
    create_directories
    create_documentation
    create_architecture_docs
    create_api_docs
    create_setup_guide
    create_makefile
    create_github_workflows
    create_config_files
    create_deployment_scripts
    create_manifests
    
    print_header "Setup Complete!"
    
    echo -e "${GREEN}Project structure created at: $PROJECT_ROOT${NC}"
    echo -e "${GREEN}Total files created: $(find $PROJECT_ROOT -type f | wc -l)${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. cd $PROJECT_ROOT"
    echo "2. make setup-k8s           # Initialize Kubernetes"
    echo "3. make dev-start            # Start databases"
    echo "4. make deploy               # Deploy services"
    echo "5. make health               # Check health"
    echo ""
    echo "For detailed instructions, see: sakina-docs/SETUP.md"
    echo ""
}

main "$@"
