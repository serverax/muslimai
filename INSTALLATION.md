# Project Sakina - Master Installation Guide

Welcome to Project Sakina! This guide walks you through the complete setup process.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation by OS](#installation-by-os)
3. [Quick Start](#quick-start)
4. [Troubleshooting](#troubleshooting)
5. [Next Steps](#next-steps)

---

## Prerequisites

Before starting, ensure you have:

- **8GB RAM** minimum (16GB recommended)
- **50GB Disk Space** for databases and models
- **Internet Connection** for downloading dependencies
- **Administrator Access** (for some installations)

---

## Installation by OS

### Option 1: macOS (Recommended for Apple Silicon)

#### Automated Setup (Recommended)

```bash
# Download and run the complete setup script
chmod +x macos-setup.sh
./macos-setup.sh

# Then run the main setup
chmod +x setup-sakina.sh
./setup-sakina.sh
```

#### Manual Setup

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install prerequisites
brew install git docker kubectl rustup-init flutter make

# 3. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 4. Install Docker Desktop and enable Kubernetes
brew install --cask docker
# Then manually enable Kubernetes in Docker settings

# 5. Run project setup
chmod +x setup-sakina.sh
./setup-sakina.sh
```

### Option 2: Windows (PowerShell as Administrator)

#### Automated Setup

```powershell
# Download the script, then run:
.\setup-sakina.bat
```

#### Manual Setup

```powershell
# 1. Install Chocolatey
Set-ExecutionPolicy AllSigned
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install prerequisites
choco install git docker-desktop kubectl rustup.install flutter make -y

# 3. Install Rust
rustup-init.exe

# 4. Install Docker Desktop
choco install docker-desktop -y
# Then enable Kubernetes in Docker settings

# 5. Create project structure and run setup
# See WINDOWS_SETUP.md for detailed instructions
```

**For detailed Windows instructions, see: [WINDOWS_SETUP.md](./WINDOWS_SETUP.md)**

### Option 3: Linux (Ubuntu/Debian)

#### Automated Setup

```bash
# Download and run
chmod +x linux-setup.sh
./linux-setup.sh

# Then run main setup
chmod +x setup-sakina.sh
./setup-sakina.sh
```

#### Manual Setup

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install essentials
sudo apt install -y git curl build-essential

# 3. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 4. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 5. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 6. Install Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"

# 7. Run project setup
chmod +x setup-sakina.sh
./setup-sakina.sh
```

---

## Quick Start

After installation, get started with:

```bash
# Navigate to project
cd SakinaAL

# Check Makefile targets
make help

# Initialize Kubernetes
make setup-k8s

# Start development environment
make dev-start

# Deploy all services
make deploy

# Check health
make health
```

### Access Services

Once deployed, access them at:

- **API**: http://localhost:8080/v1/health
- **Qdrant**: http://localhost:6333
- **PostgreSQL**: localhost:5432
- **vLLM**: http://localhost:8000/v1

(Note: May need to set up port-forwarding first)

---

## Detailed Documentation

After installation, read these documents in order:

1. **[SETUP.md](./sakina-docs/SETUP.md)** - Detailed setup and troubleshooting
2. **[ARCHITECTURE.md](./sakina-docs/ARCHITECTURE.md)** - System architecture overview
3. **[API.md](./sakina-docs/API.md)** - API reference and examples
4. **[README.md](./README.md)** - Project overview

---

## Development Workflow

Once everything is installed:

```bash
# Create a feature branch
git checkout -b feat/your-feature

# Make changes to code

# Run tests
make test

# Commit with clear message
git commit -m "feat: description of your changes"

# Push to GitHub
git push origin feat/your-feature

# Create pull request on GitHub
```

---

## Troubleshooting

### General Issues

#### Commands not found

```bash
# Reload your shell
source ~/.bashrc          # Linux/macOS (bash)
source ~/.zshrc           # macOS (zsh)
. $PROFILE                # Windows (PowerShell)
```

#### Ports already in use

```bash
# Find process using port (macOS/Linux)
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or use different port in port-forward
kubectl port-forward svc/sakina-api 8081:8080
```

### Kubernetes Issues

#### Cluster won't start

```bash
# Reset Docker
docker system prune -a

# For Docker Desktop:
# Go to Settings → Reset → "Reset Kubernetes cluster"

# For kind:
kind delete cluster --name sakina
kind create cluster --name sakina
```

#### Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace>
```

### Service Connection Issues

#### PostgreSQL won't connect

```bash
# Check if pod is running
kubectl get pod -l app=postgres -n sakina-data

# Check logs
kubectl logs -l app=postgres -n sakina-data

# Verify port-forward
lsof -i :5432  # macOS/Linux
netstat -ano | findstr :5432  # Windows

# Test connection
psql -h localhost -U sakina_user -d sakina
```

#### API not responding

```bash
# Check if pod is running
kubectl get pod -l app=sakina-api -n sakina-api

# Check logs
kubectl logs -l app=sakina-api -n sakina-api

# Check environment variables
kubectl describe pod <pod-name> -n sakina-api

# Test endpoint
curl -v http://localhost:8080/v1/health
```

### Database Issues

#### Schema not found

```bash
# Initialize schema manually
kubectl port-forward -n sakina-data svc/postgres 5432:5432 &
psql -h localhost -U sakina_user -d sakina < sakina-backend/db/init.sql
```

#### Qdrant collection missing

```bash
# Create collection
curl -X PUT http://localhost:6333/collections/verified_knowledge \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```

---

## System Requirements Checklist

Before opening a GitHub issue, ensure:

- [ ] Installed all prerequisites for your OS
- [ ] Docker Desktop is running (if using Docker Desktop)
- [ ] Kubernetes cluster is running (`kubectl cluster-info`)
- [ ] At least 8GB RAM available
- [ ] At least 50GB disk space available
- [ ] No conflicting services on ports 5432, 6333, 8000, 8080

---

## Getting Help

1. **Check Documentation**: Read relevant `.md` files first
2. **Common Issues**: See troubleshooting above
3. **GitHub Issues**: Search or open an issue
4. **GitHub Discussions**: Ask questions in discussions
5. **Discord**: Join our community (coming soon)

---

## What's Next?

After successful installation:

1. Read the architecture guide: `sakina-docs/ARCHITECTURE.md`
2. Explore the codebase in `sakina-backend/` and `sakina-frontend/`
3. Run the test suite: `make test`
4. Set up your IDE with Rust Analyzer and Flutter extensions
5. Follow the development workflow for contributing

---

## Quick Reference

### Commonly Used Commands

```bash
# Kubernetes
kubectl get pods -A                    # List all pods
kubectl describe pod <name> -n <ns>    # Pod details
kubectl logs <pod> -n <namespace>      # View logs
kubectl port-forward svc/<svc> <port>  # Forward port

# Make targets
make setup-k8s                         # Initialize Kubernetes
make dev-start                         # Start services
make dev-stop                          # Stop services
make test                              # Run tests
make deploy                            # Deploy to K8s
make health                            # Check health

# Cargo (Rust)
cargo build                            # Build
cargo test                             # Test
cargo run                              # Run
cargo fmt                              # Format code

# Flutter
flutter pub get                        # Get dependencies
flutter test                           # Run tests
flutter run                            # Run app
flutter build apk                      # Build APK
flutter build ios                      # Build iOS
```

---

## System Information

Your installation includes:

- **Kubernetes**: Local cluster (minikube/kind)
- **Database**: PostgreSQL 16 + Qdrant 1.10
- **Backend**: Rust with Actix-web
- **Frontend**: Flutter with Dart
- **LLM**: Local vLLM with Falcon-7B
- **Embedding**: HuggingFace Transformers
- **Storage**: Local filesystem with encryption
- **Monitoring**: Prometheus + Grafana (optional)

---

## Estimated Setup Time

- **Prerequisites Installation**: 15-30 minutes
- **Project Structure Setup**: 5 minutes
- **Kubernetes Initialization**: 10-15 minutes
- **Service Deployment**: 10-15 minutes
- **Total**: 40-75 minutes (depending on internet speed)

---

## License

MIT License - See LICENSE file for details

---

**Ready? Let's go! 🚀**

```bash
chmod +x setup-sakina.sh
./setup-sakina.sh
```

For OS-specific help:
- **macOS**: `chmod +x macos-setup.sh && ./macos-setup.sh`
- **Windows**: `.\setup-sakina.bat`
- **Linux**: `chmod +x linux-setup.sh && ./linux-setup.sh`
