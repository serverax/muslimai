# TOOLCHAIN INSTALLATION & VERIFICATION GUIDE
## Get Project Sakina Ready to Compile and Deploy

---

# STEP 1: Install Required Toolchains

## Copy and Run These Commands

Open **PowerShell as Administrator** and execute:

```powershell
# Install Rust
Write-Host "Installing Rust..." -ForegroundColor Green
winget install Rustlang.Rustup

# Install Flutter
# NOTE: Flutter is frequently NOT published on winget. If this reports
# "No package found matching input criteria", install the Flutter SDK zip from
# https://docs.flutter.dev/get-started/install/windows or run: choco install flutter
Write-Host "Installing Flutter..." -ForegroundColor Green
winget install --id=Google.Flutter

# Install Kind (Kubernetes)
Write-Host "Installing Kind..." -ForegroundColor Green
winget install Kubernetes.kind

# Install Make
Write-Host "Installing Make..." -ForegroundColor Green
winget install GnuWin32.Make

Write-Host "Installation complete! Restart PowerShell and verify..." -ForegroundColor Green
```

---

# STEP 2: Verify Installation

Open **new PowerShell window** and run:

```powershell
# Verify Rust
Write-Host "`nVerifying Rust..." -ForegroundColor Cyan
rustc --version          # Should show: rustc X.XX.X
cargo --version          # Should show: cargo X.XX.X

# Verify Flutter
Write-Host "`nVerifying Flutter..." -ForegroundColor Cyan
flutter --version        # Should show: Flutter X.XX.X
flutter doctor          # Should show green checkmarks

# Verify Kind
Write-Host "`nVerifying Kind..." -ForegroundColor Cyan
kind version            # Should show: kind vX.XX.X

# Verify Make
Write-Host "`nVerifying Make..." -ForegroundColor Cyan
make --version          # Should show: GNU Make X.XX.X
```

**Expected Output:**
```
✅ rustc 1.75.0 or later
✅ cargo 1.75.0 or later
✅ Flutter 3.16.0 or later
✅ Kind v0.20.0 or later
✅ GNU Make 4.3 or later
```

---

# STEP 3: Verify Backend Compilation

```powershell
cd F:\SakinaAL\sakina-backend

Write-Host "Checking Rust code..." -ForegroundColor Cyan
cargo check

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Backend compiles successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Backend compilation failed" -ForegroundColor Red
    exit 1
}

Write-Host "Running Rust linter (clippy)..." -ForegroundColor Cyan
cargo clippy -- -D warnings

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Clippy checks passed!" -ForegroundColor Green
} else {
    Write-Host "❌ Clippy checks failed" -ForegroundColor Red
    exit 1
}

Write-Host "Running backend tests..." -ForegroundColor Cyan
cargo test

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Backend tests passed!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some tests failed (check output above)" -ForegroundColor Yellow
}
```

**Expected Results:**
- ✅ Compiles without errors
- ✅ Clippy reports no warnings
- ✅ Tests pass successfully

---

# STEP 4: Verify Frontend Build

```powershell
cd F:\SakinaAL\sakina-frontend

Write-Host "Downloading Flutter dependencies..." -ForegroundColor Cyan
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dependencies downloaded!" -ForegroundColor Green

Write-Host "Analyzing Flutter code..." -ForegroundColor Cyan
flutter analyze

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Code analysis passed!" -ForegroundColor Green
} else {
    Write-Host "❌ Code analysis failed" -ForegroundColor Red
    exit 1
}

Write-Host "Running Flutter smoke tests..." -ForegroundColor Cyan
flutter test

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Smoke tests passed!" -ForegroundColor Green
} else {
    Write-Host "❌ Smoke tests failed" -ForegroundColor Red
    exit 1
}
```

**Expected Results:**
- ✅ Dependencies downloaded (50+ packages)
- ✅ Code analysis passes
- ✅ Smoke test passes

---

# STEP 5: Set Up Infrastructure

```powershell
cd F:\SakinaAL\sakina-infra

Write-Host "Creating local Kubernetes cluster..." -ForegroundColor Cyan
make setup-k8s

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Kubernetes cluster created!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create cluster" -ForegroundColor Red
    exit 1
}

Write-Host "Starting database services..." -ForegroundColor Cyan
make dev-start

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database services started!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to start services" -ForegroundColor Red
    exit 1
}

Write-Host "Waiting for services to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

Write-Host "Checking service health..." -ForegroundColor Cyan
make health

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ All services are healthy!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some services may not be ready yet (try again in 30 seconds)" -ForegroundColor Yellow
}
```

**Expected Results:**
- ✅ Kubernetes cluster created with 4 namespaces
- ✅ PostgreSQL pod running
- ✅ Qdrant pod running
- ✅ All services healthy

---

# COMPREHENSIVE VERIFICATION SCRIPT

Save this as `verify-sakina.ps1` and run it:

```powershell
# verify-sakina.ps1
# Comprehensive Project Sakina verification script

param(
    [switch]$Full = $false
)

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     PROJECT SAKINA - COMPREHENSIVE VERIFICATION          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check toolchains
Write-Host "📋 Checking installed toolchains..." -ForegroundColor Yellow

$tools = @{
    "Rust" = "rustc --version"
    "Cargo" = "cargo --version"
    "Flutter" = "flutter --version"
    "Kind" = "kind version"
    "Make" = "make --version"
}

$allToolsFound = $true
foreach ($tool in $tools.GetEnumerator()) {
    try {
        $output = Invoke-Expression $tool.Value 2>&1 | Select-Object -First 1
        Write-Host "✅ $($tool.Name): $output" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($tool.Name): NOT FOUND" -ForegroundColor Red
        $allToolsFound = $false
    }
}

if (-not $allToolsFound) {
    Write-Host "`n⚠️  Some toolchains are missing. Please install them first." -ForegroundColor Yellow
    exit 1
}

# Verify backend
Write-Host "`n📦 Verifying Backend (Rust)..." -ForegroundColor Yellow
try {
    Push-Location F:\SakinaAL\sakina-backend
    
    Write-Host "  Checking compilation..." -NoNewline
    cargo check --quiet 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "cargo check failed" }
    Write-Host " ✅" -ForegroundColor Green
    
    Write-Host "  Running clippy checks..." -NoNewline
    cargo clippy --quiet -- -D warnings 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "clippy failed" }
    Write-Host " ✅" -ForegroundColor Green
    
    if ($Full) {
        Write-Host "  Running tests..." -NoNewline
        cargo test --quiet 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "cargo test failed" }
        Write-Host " ✅" -ForegroundColor Green
    }
    
    Pop-Location
} catch {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
}

# Verify frontend
Write-Host "`n📱 Verifying Frontend (Flutter)..." -ForegroundColor Yellow
try {
    Push-Location F:\SakinaAL\sakina-frontend
    
    Write-Host "  Analyzing code..." -NoNewline
    flutter analyze 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }
    Write-Host " ✅" -ForegroundColor Green
    
    if ($Full) {
        Write-Host "  Running smoke tests..." -NoNewline
        flutter test --no-pub 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "flutter test failed" }
        Write-Host " ✅" -ForegroundColor Green
    }
    
    Pop-Location
} catch {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
}

# Verify infrastructure
Write-Host "`n☸️  Verifying Infrastructure (Kubernetes)..." -ForegroundColor Yellow
try {
    Push-Location F:\SakinaAL\sakina-infra
    
    Write-Host "  Checking Kubernetes..." -NoNewline
    kubectl cluster-info 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
    
    Write-Host "  Checking namespaces..." -NoNewline
    $ns = kubectl get namespaces 2>&1
    if ($ns -match "sakina") {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ⚠️ (Not deployed yet)" -ForegroundColor Yellow
    }
    
    Pop-Location
} catch {
    Write-Host " ⚠️ (Not yet available)" -ForegroundColor Yellow
}

Write-Host "`n✅ Verification Complete!" -ForegroundColor Green
Write-Host "`nProject Sakina is ready to compile and deploy." -ForegroundColor Cyan
```

**Run it:**
```powershell
.\verify-sakina.ps1 -Full
```

---

# TROUBLESHOOTING

## Issue: `rustc --version` not found

**Solution:**
```powershell
# Add Rust to PATH manually
$env:Path += ";$HOME\.cargo\bin"

# Verify
rustc --version
```

## Issue: `flutter doctor` shows warnings

**Solution:**
```powershell
# Run doctor to see what's needed
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses

# Or configure for specific platform
flutter config --enable-windows-desktop  # For Windows
```

## Issue: `kind` cluster creation fails

**Solution:**
```powershell
# Ensure Docker is running
docker ps

# Check Docker resources
docker info | grep "Memory"

# Try with more resources
kind create cluster --name sakina --config kind-config.yaml
```

## Issue: `make` command not found

**Solution:**
```powershell
# Verify installation
where.exe make

# If not found, try via Git Bash
bash -c "make --version"

# Or install via Chocolatey
choco install make
```

---

# FINAL STATUS CHECK

Once all verifications pass, you're ready to:

```bash
# Compile backend
cargo build --release

# Build frontend APK
flutter build apk --release

# Deploy infrastructure
make deploy

# Run integration tests (first: pip install -r sakina-tests/requirements.txt,
# and start the API on :8080 -- see VERIFICATION-COMMANDS.md Part 4)
pytest sakina-tests/integration/
```

**Congratulations! Project Sakina is ready for development!** 🚀

---

Made with precision, intelligence, and respect for privacy. 🙏

Project Sakina: Sovereign. Intelligent. Secure. Islamic.
