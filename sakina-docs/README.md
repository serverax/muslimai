# Project Sakina - Sovereign Islamic AI System

A privacy-first, zero-hallucination AI system for Islamic guidance built on local Kubernetes infrastructure.

## Features

✅ **Sovereign Infrastructure** - Everything runs locally on Kubernetes  
✅ **Zero Hallucination** - Strict RAG guardrails prevent theological inaccuracies  
✅ **Privacy-First** - All data encrypted at rest and in transit  
✅ **Offline-Capable** - Local LLM inference, no cloud APIs  
✅ **Audit Trail** - Append-only logging for transparency  
✅ **Dual UI** - Native RTL/LTR support for Arabic and English  

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
make -C sakina-infra deploy

# Access services
# - API: http://localhost:8080/v1/health
# - Qdrant: http://localhost:6333
# - PostgreSQL: localhost:5432
# - vLLM: http://localhost:8000/v1
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
├── .github/workflows/       # CI/CD pipelines
└── Makefile
```

## Architecture

- **Backend**: Rust with Actix-web, SQLx, Qdrant client
- **Frontend**: Flutter with Riverpod state management
- **Infrastructure**: Kubernetes (minikube/kind), PostgreSQL, Qdrant
- **LLM**: Local vLLM with Falcon-7B or Qwen-8B
- **Database**: PostgreSQL for relational, Qdrant for vectors
- **Encryption**: TLS 1.3, SQLCipher for local data

## Development Workflow

1. **Create Feature Branch**: `git checkout -b feat/your-feature`
2. **Make Changes**: Edit files in your favorite editor
3. **Run Tests**: `make test`
4. **Commit**: `git commit -m "feat: description"`
5. **Push**: `git push origin feat/your-feature`
6. **Create PR**: Submit pull request on GitHub

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
