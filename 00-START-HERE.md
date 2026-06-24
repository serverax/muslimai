# 🚀 PROJECT SAKINA - START HERE

Welcome to Project Sakina! This file explains how to get everything set up.

## What is Project Sakina?

A sovereign, privacy-first AI system for Islamic guidance:
- ✅ Runs entirely locally (no cloud APIs)
- ✅ Zero hallucinations (strict RAG guardrails)
- ✅ Encrypted data (at rest and in transit)
- ✅ Audit trails (append-only logging)
- ✅ Dual language UI (Arabic & English, proper RTL)

## 5-Minute Quick Start

### 1. Choose Your Operating System

#### macOS
```bash
chmod +x macos-setup.sh
./macos-setup.sh
```

#### Windows
```powershell
.\setup-sakina.bat
```

#### Linux (Ubuntu/Debian)
```bash
sudo chmod +x linux-setup.sh
sudo ./linux-setup.sh
```

### 2. Run Main Setup (All Platforms)
```bash
chmod +x setup-sakina.sh
./setup-sakina.sh
```

This creates the ENTIRE project structure with:
- ✅ Backend (Rust)
- ✅ Frontend (Flutter)
- ✅ Infrastructure (Kubernetes)
- ✅ Documentation (Comprehensive)
- ✅ Tests (Integration & Unit)
- ✅ CI/CD (GitHub Actions)

### 3. Start Services
```bash
cd SakinaAL
make setup-k8s
make dev-start
make deploy
make health
```

### 4. Access Services
- **API**: http://localhost:8080/v1/health
- **Qdrant**: http://localhost:6333
- **PostgreSQL**: localhost:5432
- **vLLM**: http://localhost:8000/v1

**That's it! You're done. 🎉**

---

## File Guide

### Setup Scripts (Run These First)

| File | Purpose | When to Use |
|------|---------|------------|
| `macos-setup.sh` | Installs macOS prerequisites | First time on macOS |
| `linux-setup.sh` | Installs Linux prerequisites | First time on Linux (run with sudo) |
| `setup-sakina.bat` | Windows setup | Windows users |
| `setup-sakina.sh` | Creates entire project | After prerequisites installed |

### Documentation Files (Read These)

| File | What It Covers |
|------|----------------|
| `README-SETUP.md` | Overview of setup package (recommended start) |
| `INSTALLATION.md` | Detailed setup guide for all OS with troubleshooting |
| `WINDOWS_SETUP.md` | Windows-specific setup and common issues |
| `00-START-HERE.md` | This file - the quick guide |

### What Gets Created

After running setup scripts, you'll have:

```
SakinaAL/
├── sakina-backend/      # Rust backend (HTTP API, RAG engine)
├── sakina-frontend/     # Flutter app (iOS/Android)
├── sakina-infra/        # Kubernetes manifests
├── sakina-docs/         # Full documentation
├── sakina-tests/        # Test suites
├── .github/workflows/   # CI/CD pipelines
├── Makefile             # Build automation
└── README.md            # Project overview
```

Plus 50+ documentation and configuration files.

---

## Recommended Reading Order

After setup, read these in order:

1. **README.md** (5 min) - Project overview
2. **sakina-docs/ARCHITECTURE.md** (10 min) - How it all works
3. **sakina-docs/API.md** (5 min) - API reference
4. **sakina-docs/SETUP.md** (10 min) - Detailed setup help
5. **Code** (30+ min) - Explore the codebase

---

## Common Questions

### Q: Do I need to install prerequisites manually?
**A:** No! The setup scripts do it automatically (macos-setup.sh, linux-setup.sh, setup-sakina.bat).

### Q: How long does setup take?
**A:** 5-10 minutes for scripts, 40-60 minutes for everything including downloads and initialization.

### Q: Can I use this on Windows?
**A:** Yes! Use setup-sakina.bat, then see WINDOWS_SETUP.md for details.

### Q: Do I need to know Rust/Flutter?
**A:** No, but helpful for contributing. The project is designed to be easy to contribute to.

### Q: What if something fails?
**A:** See INSTALLATION.md "Troubleshooting" section. Most issues are easy to fix.

### Q: How much disk space do I need?
**A:** 50GB minimum, 100GB+ recommended. Includes models, databases, and build artifacts.

### Q: Can I use this with an M1/M2 Mac?
**A:** Yes! All scripts are fully compatible with Apple Silicon.

### Q: What about 32-bit systems?
**A:** No, you need 64-bit (x86_64 or ARM64).

---

## System Requirements at a Glance

✅ **Minimum:**
- 8GB RAM
- 50GB Disk
- Internet connection
- Administrator access

✅ **Recommended:**
- 16GB+ RAM
- 100GB+ Disk
- Quad-core processor
- Gigabit internet

---

## Development Workflow

Once everything is set up:

```bash
# 1. Create feature branch
git checkout -b feat/your-feature

# 2. Make changes
# ... edit code ...

# 3. Test changes
make test

# 4. Commit with clear message
git commit -m "feat: description"

# 5. Push to GitHub
git push origin feat/your-feature

# 6. Create pull request on GitHub
```

---

## Getting Help

### Before Asking

1. ✅ Read **INSTALLATION.md** troubleshooting section
2. ✅ Check **sakina-docs/SETUP.md** for detailed help
3. ✅ Search **GitHub Issues** for similar problems
4. ✅ Check **README.md** in the main folder

### If You Still Need Help

1. **Open GitHub Issue** - Provide:
   - OS and version
   - Error message
   - Steps to reproduce
   - System info (RAM, disk, etc.)

2. **Ask in GitHub Discussions** - For questions
3. **Join Discord** - Community chat (coming soon)

---

## One-Liner Installation

Can't be simpler:

```bash
chmod +x setup-sakina.sh && ./setup-sakina.sh
```

---

## What Happens Next

1. **Setup scripts create complete project** (~10 min)
   - All folders
   - All documentation
   - All configuration
   - CI/CD pipelines

2. **You initialize Kubernetes** (2 min)
   ```bash
   make setup-k8s
   ```

3. **Services start up** (5 min)
   ```bash
   make dev-start
   make deploy
   ```

4. **Everything works** (verify with)
   ```bash
   make health
   ```

5. **You start developing** 🎉

---

## Architecture at a Glance

```
Flutter App ──→ Rust API ──→ RAG Engine ──→ vLLM (Local LLM)
                              ↓
                        Vector Search (Qdrant)
                              ↓
                        Verified Knowledge Base
```

- Everything runs locally
- No internet calls after initialization
- Data stays encrypted
- Everything audited

---

## Feature Highlights

🔒 **Security**
- Encrypted at rest (SQLCipher)
- Encrypted in transit (TLS 1.3)
- No external API calls
- Append-only audit logs

🧠 **Intelligence**
- Local LLM inference (Falcon-7B)
- Vector semantic search (Qdrant)
- RAG with guardrails
- Zero hallucination design

📱 **User Experience**
- Native Flutter app
- Proper RTL/LTR support (Arabic/English)
- Offline-first architecture
- Encrypted sync to server

🚀 **Performance**
- <500ms API latency
- Local inference (no network delays)
- Optimized vector search
- Efficient chunking

---

## Prerequisites Checklist

Before running setup, have:

- [ ] Administrator/sudo access
- [ ] 8GB+ RAM free
- [ ] 50GB+ disk space
- [ ] Internet connection
- [ ] Docker Desktop (coming with setup on macOS/Windows)

---

## File Size Reference

| Component | Size | Notes |
|-----------|------|-------|
| Setup scripts | 92 KB | Everything to get started |
| Generated project | 200+ MB | After setup (with node_modules, etc.) |
| Models (downloaded) | 20+ GB | Falcon-7B or Qwen-8B LLM |
| Databases (empty) | 15+ GB | PostgreSQL + Qdrant storage |

---

## Estimated Timeline

| Step | Time |
|------|------|
| Prerequisites install | 15-30 min |
| Project structure creation | 2-5 min |
| Kubernetes initialization | 5-10 min |
| Service deployment | 10-15 min |
| **Total** | **40-60 min** |

---

## Success Criteria

You've succeeded when:

✅ `make health` shows all services healthy  
✅ `curl http://localhost:8080/v1/health` returns OK  
✅ `kubectl get pods -A` shows all pods running  
✅ You can read sakina-docs/ARCHITECTURE.md  
✅ You understand the system design  

---

## Ready? Let's Go! 🚀

```bash
# Choose your OS and run the first script:

# macOS
chmod +x macos-setup.sh && ./macos-setup.sh

# Linux
sudo chmod +x linux-setup.sh && sudo ./linux-setup.sh

# Windows
.\setup-sakina.bat

# Then run main setup (all platforms)
chmod +x setup-sakina.sh && ./setup-sakina.sh
```

---

## Questions?

1. **During Setup**: Check INSTALLATION.md → Troubleshooting
2. **During Development**: Check README.md in main folder
3. **Architecture Questions**: Read sakina-docs/ARCHITECTURE.md
4. **API Questions**: Read sakina-docs/API.md
5. **Still Stuck**: Open GitHub Issue with details

---

## Next Steps

✅ Run the appropriate setup script for your OS  
✅ Run setup-sakina.sh  
✅ Read README.md in the generated SakinaAL folder  
✅ Read sakina-docs/ARCHITECTURE.md  
✅ Run `make help` to see available commands  
✅ Start developing!  

---

**Made with precision, intelligence, and respect for privacy.**

Built by the community, for the community.  
Powered by open-source tools.  
Guided by Islamic principles.  

🙏 Let's build something meaningful together.
