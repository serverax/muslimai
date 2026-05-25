# Project Sakina - Setup Package

Welcome! This package contains everything needed to set up Project Sakina locally.

## What's Included

```
├── setup-sakina.sh          # Main cross-platform setup script (macOS/Linux)
├── setup-sakina.bat         # Windows setup script
├── macos-setup.sh           # macOS prerequisite installer
├── linux-setup.sh           # Linux prerequisite installer
├── INSTALLATION.md          # Master installation guide
├── WINDOWS_SETUP.md         # Windows-specific setup guide
└── README-SETUP.md          # This file
```

## Quick Start (Choose Your OS)

### macOS

```bash
# Option 1: Automated (installs everything)
chmod +x macos-setup.sh
./macos-setup.sh

# Option 2: Manual (see INSTALLATION.md)
# Follow step-by-step instructions
```

### Windows

```powershell
# Run the batch script
.\setup-sakina.bat

# Or see WINDOWS_SETUP.md for manual steps
```

### Linux (Ubuntu/Debian)

```bash
# Run as sudo (installs prerequisites)
sudo chmod +x linux-setup.sh
sudo ./linux-setup.sh

# Log out and back in for Docker changes
# Then run main setup
```

## After Prerequisites Are Installed

All OSes follow the same main setup:

```bash
# Make scripts executable
chmod +x setup-sakina.sh

# Run main setup
./setup-sakina.sh

# This creates complete project structure with all files
```

## What Gets Created

The setup script creates:

```
SakinaAL/
├── sakina-backend/              # Rust backend services
│   ├── src/
│   ├── db/
│   ├── tests/
│   ├── Dockerfile.api
│   ├── Dockerfile.vllm
│   ├── Cargo.toml
│   └── .github/workflows/
│
├── sakina-frontend/             # Flutter mobile app
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── services/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   ├── pubspec.yaml
│   └── .github/workflows/
│
├── sakina-infra/                # Kubernetes infrastructure
│   ├── Makefile
│   ├── docker-compose.yml
│   ├── helm/
│   ├── manifests/               # K8s deployment files
│   ├── network/
│   ├── storage/
│   ├── scripts/
│   └── volumes/
│
├── sakina-docs/                 # Complete documentation
│   ├── ARCHITECTURE.md
│   ├── API.md
│   ├── SETUP.md
│   └── guides/
│
├── sakina-tests/                # Test suites
│   ├── integration/
│   ├── e2e/
│   └── unit/
│
├── .github/workflows/           # CI/CD pipelines
│
├── README.md                    # Project overview
├── CONTRIBUTING.md              # Contribution guide
├── Makefile                     # Build automation
├── .gitignore
└── LICENSE
```

## Next Steps After Setup

1. **Read Documentation**
   ```bash
   cat sakina-docs/ARCHITECTURE.md      # Understand the system
   cat sakina-docs/API.md               # Learn the APIs
   cat sakina-docs/SETUP.md             # Detailed setup help
   ```

2. **Initialize Kubernetes**
   ```bash
   make setup-k8s
   make dev-start
   make deploy
   ```

3. **Verify Everything Works**
   ```bash
   make health
   curl http://localhost:8080/v1/health
   ```

4. **Start Developing**
   ```bash
   git checkout -b feat/your-feature
   # ... make changes ...
   make test
   git commit -m "feat: your changes"
   git push origin feat/your-feature
   ```

## File Descriptions

### Setup Scripts

- **setup-sakina.sh**: Main setup script that creates entire project structure, documentation, and configuration. Works on macOS and Linux.
- **setup-sakina.bat**: Windows version that creates project structure.
- **macos-setup.sh**: Installs all macOS prerequisites (Homebrew, Git, Docker, Rust, Flutter, kubectl).
- **linux-setup.sh**: Installs all Linux prerequisites (sudo required).

### Documentation

- **INSTALLATION.md**: Comprehensive installation guide for all OS platforms with troubleshooting.
- **WINDOWS_SETUP.md**: Specific Windows setup instructions with common issues and solutions.
- **README-SETUP.md**: This file - overview of the setup package.

## System Requirements

### Minimum
- 8GB RAM
- 50GB Disk Space
- Dual-core processor
- Internet connection

### Recommended
- 16GB+ RAM
- 100GB+ Disk Space
- Quad-core processor or better
- Gigabit internet

## Troubleshooting

### Setup Script Fails

1. Ensure you have admin/sudo privileges
2. Check internet connection
3. Verify enough disk space: `df -h`
4. On macOS, install Xcode command line tools: `xcode-select --install`
5. On Windows, disable antivirus temporarily during setup

### Prerequisites Won't Install

- **macOS**: May need to install Xcode first
- **Linux**: Run with sudo: `sudo ./linux-setup.sh`
- **Windows**: Run PowerShell as Administrator

### Kubernetes Won't Start

1. Check Docker Desktop is running
2. Ensure Kubernetes is enabled in Docker settings
3. Check system resources (8GB+ RAM needed)
4. Try reset: Docker Desktop → Preferences → Reset

### Port Already in Use

```bash
# Kill process using port (macOS/Linux)
lsof -i :8080 | grep LISTEN | awk '{print $2}' | xargs kill -9

# On Windows
netstat -ano | findstr :8080
taskkill /PID <PID> /F
```

## Getting Help

### Documentation
- See `/sakina-docs` folder after setup
- Read `INSTALLATION.md` for detailed steps
- Check `README.md` for project overview

### Online
- GitHub Issues: For bugs and feature requests
- GitHub Discussions: For questions
- Documentation: Comprehensive guides in `/sakina-docs`

## What's Next

After everything is set up:

1. ✅ Complete the setup scripts
2. ✅ Initialize Kubernetes with `make setup-k8s`
3. ✅ Deploy services with `make deploy`
4. ✅ Read architecture guide: `sakina-docs/ARCHITECTURE.md`
5. ✅ Explore the codebase
6. ✅ Run tests: `make test`
7. ✅ Start contributing!

## Support

For issues or questions:

1. **Check INSTALLATION.md** for common issues
2. **Check relevant documentation** in `/sakina-docs`
3. **Search GitHub Issues** for similar problems
4. **Open a new GitHub Issue** with details
5. **Join Discord** community (coming soon)

## License

MIT License - See LICENSE file for details

---

**Everything is automated. Let's build something amazing together! 🚀**

```bash
# One command to start
chmod +x setup-sakina.sh && ./setup-sakina.sh
```

Questions? See INSTALLATION.md or open a GitHub issue.
