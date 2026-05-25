# Quick Start Guide for Windows Users

## Prerequisites Installation (PowerShell as Administrator)

```powershell
# 1. Install Chocolatey
Set-ExecutionPolicy AllSigned
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install required tools
choco install git docker-desktop kubectl rustup.install flutter -y

# 3. Install Rust
rustup-init.exe

# 4. Reload PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

## Docker Desktop Setup

1. **Install Docker Desktop**: https://www.docker.com/products/docker-desktop
2. **Enable Kubernetes**:
   - Open Docker Desktop Settings
   - Go to "Kubernetes" tab
   - Check "Enable Kubernetes"
   - Wait for it to initialize (~5 minutes)

3. **Verify**:
```powershell
kubectl cluster-info
kubectl get nodes
```

## Project Setup

```powershell
# 1. Navigate to project
cd F:\SakinaAL

# 2. Run setup
.\setup-sakina.bat

# 3. Wait for directory creation

# 4. Initialize Kubernetes
make setup-k8s

# 5. Start development environment
make dev-start

# 6. Deploy services
make deploy

# 7. Check health
make health
```

## Port Forwarding (Windows CMD or PowerShell)

Open separate terminal windows and run these to access services locally:

```powershell
# PostgreSQL
kubectl port-forward -n sakina-data svc/postgres 5432:5432

# Qdrant
kubectl port-forward -n sakina-data svc/qdrant 6333:6333

# API
kubectl port-forward -n sakina-api svc/sakina-api 8080:8080

# vLLM
kubectl port-forward -n sakina-core svc/vllm-router 8000:8000
```

Then access:
- API: http://localhost:8080/v1/health
- Qdrant: http://localhost:6333
- PostgreSQL: localhost:5432
- vLLM: http://localhost:8000/v1

## Common Issues

### "Docker Desktop is not running"
```powershell
# Start Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker.exe"
# Wait a few seconds for it to initialize
```

### "kubectl: command not found"
```powershell
# Reinstall kubectl
choco install kubectl -y

# Or manually add to PATH:
# 1. Right-click "This PC" → Properties
# 2. Advanced system settings → Environment Variables
# 3. Add Docker Desktop bin folder to PATH
```

### Kubernetes won't start
```powershell
# Reset Docker
docker system prune -a
docker volume prune

# Restart Docker Desktop
# Go to Settings → Reset → "Reset Kubernetes cluster"
```

### Makefile not found
```powershell
# Install Make
choco install make -y
```

## Verify Everything Works

```powershell
# Check cluster
kubectl cluster-info

# Check pods
kubectl get pods -A

# Test API
curl http://localhost:8080/v1/health

# View logs
kubectl logs deployment/sakina-api -n sakina-api
```

## Next Steps

1. Read documentation: `sakina-docs/SETUP.md`
2. Configure IDE: Visual Studio Code + Rust Analyzer extension
3. Build backend: `cd sakina-backend && cargo build`
4. Build frontend: `cd sakina-frontend && flutter pub get`
5. Run tests: `make test`

## Useful Commands

```powershell
# View all pods
kubectl get pods -A

# View specific pod logs
kubectl logs <pod-name> -n <namespace>

# Describe pod (for troubleshooting)
kubectl describe pod <pod-name> -n <namespace>

# Delete all services
kubectl delete all --all -n sakina-api

# Restart a service
kubectl rollout restart deployment/sakina-api -n sakina-api

# Port-forward multiple services at once (create a .ps1 script):
# Save as port-forward.ps1
Start-Job { kubectl port-forward -n sakina-data svc/postgres 5432:5432 }
Start-Job { kubectl port-forward -n sakina-data svc/qdrant 6333:6333 }
Start-Job { kubectl port-forward -n sakina-api svc/sakina-api 8080:8080 }

# Then run: .\port-forward.ps1
```

## Getting Help

- **Documentation**: See `sakina-docs/` folder
- **Issues**: GitHub Issues tab
- **Kubernetes Help**: `kubectl help`
- **Makefile Targets**: `make help`

---

Happy coding! 🚀
