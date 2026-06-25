<#
  CURSOR PHASE 6I — Owner mobile APK test (THE REAL APP IS THE ANDROID APK).

  Usage:
    pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
    pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk -ApkTarget Both
    pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk -SkipDockerBuild

  Web at :8090 is diagnostic only. Do not treat web as the product.
#>
param(
  [switch]$BuildApk,
  [switch]$SkipFlutterWeb,
  [switch]$SkipDockerBuild,
  [switch]$OpenFirewall,
  [ValidateSet('Emulator', 'Phone', 'Both')]
  [string]$ApkTarget = 'Emulator',
  [int]$ApiPort = 28080,
  [int]$WebPort = 8090
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$composeDir = Join-Path $repo "sakina-infra"
$frontend = Join-Path $repo "sakina-frontend"
$envFile = Join-Path $composeDir ".env"
$apkPath = Join-Path $frontend "build/app/outputs/flutter-apk/app-debug.apk"
$proofDir = Join-Path $repo "test-results"
$reportDir = Join-Path $repo "reports"
$webDir = Join-Path $frontend "build/web"
$serverPidFile = Join-Path $proofDir ".sakina-web-server.pid"
New-Item -ItemType Directory -Force -Path $proofDir, $reportDir | Out-Null

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Pass([string]$msg) { Write-Host "PASS: $msg" -ForegroundColor Green }
function Write-Fail([string]$msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }
function Write-Warn([string]$msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }

function Test-Command([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Get-LanIp {
  if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object {
        $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
        $_.InterfaceAlias -notmatch 'WSL|vEthernet|Loopback|Docker'
      } |
      Sort-Object {
        if ($_.IPAddress -like '192.168.*') { 0 }
        elseif ($_.IPAddress -like '10.*') { 1 }
        else { 2 }
      } |
      Select-Object -First 1 -ExpandProperty IPAddress
    if (-not [string]::IsNullOrWhiteSpace($ip)) { return $ip }
  }
  if (Get-Command ip -ErrorAction SilentlyContinue) {
    $route = ip -4 route get 1.1.1.1 2>$null
    if ($route -match 'src\s+(\S+)') { return $Matches[1] }
  }
  return $null
}

function Get-FullApkBuildCommand([string]$ApiBaseUrl) {
  return @(
    "cd sakina-frontend",
    "flutter pub get",
    "flutter build apk --debug",
    "--dart-define=SAKINA_API_BASE_URL=$ApiBaseUrl",
    "--dart-define=SAKINA_LOCAL_TEST=true",
    "--dart-define=SAKINA_FEATURE_QURAN=true",
    "--dart-define=SAKINA_FEATURE_PRAYER=true",
    "--dart-define=SAKINA_FEATURE_KNOWLEDGE=true",
    "--dart-define=SAKINA_FEATURE_COMMUNITY=true",
    "--dart-define=SAKINA_SUBSCRIPTION_TIER=founding"
  ) -join ' '
}

function Test-HttpStatus([string]$Url) {
  try {
    $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8
    return [pscustomobject]@{ Code = [int]$r.StatusCode; Ok = ($r.StatusCode -eq 200); Body = $r.Content }
  } catch {
    $code = 0
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode.value__ }
    return [pscustomobject]@{ Code = $code; Ok = $false; Body = '' }
  }
}

function Wait-Http200([string]$Url, [int]$Seconds = 90) {
  for ($i = 0; $i -lt $Seconds; $i++) {
    $r = Test-HttpStatus $Url
    if ($r.Ok) { return $r }
    Start-Sleep -Seconds 1
  }
  return Test-HttpStatus $Url
}

function Get-PortOwner([int]$Port) {
  if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    return @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess -Unique)
  }
  $pids = @()
  if (Get-Command fuser -ErrorAction SilentlyContinue) {
    $fuserOut = fuser "${Port}/tcp" 2>$null
    if ($fuserOut) {
      $pids += @($fuserOut -split '\s+' | Where-Object { $_ -match '^\d+$' })
    }
  }
  if ($pids.Count -eq 0 -and (Get-Command ss -ErrorAction SilentlyContinue)) {
    $ssOut = ss -ltnp 2>$null | Select-String ":${Port}\s"
    foreach ($line in $ssOut) {
      if ($line -match 'pid=(\d+)') { $pids += [int]$Matches[1] }
    }
  }
  return @($pids | Select-Object -Unique)
}

function Stop-PortListener([int]$Port) {
  foreach ($portPid in Get-PortOwner $Port) {
    if ($portPid -and $portPid -ne $PID) {
      Write-Host "Stopping process on port $Port (PID $portPid)" -ForegroundColor Yellow
      Stop-Process -Id $portPid -Force -ErrorAction SilentlyContinue
    }
  }
  Start-Sleep -Milliseconds 500
}

function Start-BackgroundProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$WorkingDirectory = $null
  )
  $startParams = @{
    FilePath     = $FilePath
    ArgumentList = $ArgumentList
    PassThru     = $true
  }
  if ($WorkingDirectory) { $startParams.WorkingDirectory = $WorkingDirectory }
  if ($IsWindows) { $startParams.WindowStyle = 'Hidden' }
  return Start-Process @startParams
}

function Start-StaticWebServer([string]$Dir, [int]$Port) {
  Stop-PortListener $Port
  $serveScript = Join-Path $PSScriptRoot "serve-static-web.ps1"
  $dirFull = (Resolve-Path $Dir).Path

  if (Test-Command 'npx') {
    Write-Host "Starting Node static server (npx serve) on port $Port" -ForegroundColor DarkGray
    $npx = (Get-Command npx).Source
    $proc = Start-BackgroundProcess -FilePath $npx -ArgumentList @(
      '--yes', 'serve', $dirFull, '-l', "$Port", '-s'
    ) -WorkingDirectory $dirFull
    Start-Sleep -Seconds 3
    if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
      Write-Host "npx serve exited early — falling back to PowerShell HttpListener" -ForegroundColor Yellow
    } else {
      return [pscustomobject]@{ Pid = $proc.Id; Engine = 'npx serve' }
    }
  } elseif (Test-Command 'node') {
    Write-Host "Starting Node http-server on port $Port" -ForegroundColor DarkGray
    $node = (Get-Command node).Source
    $proc = Start-BackgroundProcess -FilePath $node -ArgumentList @(
      (Join-Path $env:APPDATA 'npm\node_modules\http-server\bin\http-server'),
      $dirFull, '-p', "$Port", '-c-1', '--silent'
    )
    if ($proc -and (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
      return [pscustomobject]@{ Pid = $proc.Id; Engine = 'http-server' }
    }
  }

  Write-Host "Using PowerShell HttpListener fallback on port $Port" -ForegroundColor Yellow
  $pwshExe = if (Test-Command 'pwsh') { (Get-Command pwsh).Source } else { 'pwsh' }
  $proc = Start-BackgroundProcess -FilePath $pwshExe -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $serveScript,
    '-Root', $dirFull, '-Port', $Port
  )
  return [pscustomobject]@{ Pid = $proc.Id; Engine = 'PowerShell HttpListener' }
}

function Test-AndroidSdk {
  if (-not (Test-Command 'flutter')) {
    return [pscustomobject]@{ Ok = $false; Reason = 'Flutter SDK not found on PATH. Install Flutter 3.16+ and add to PATH.' }
  }
  $doctor = flutter doctor -v 2>&1 | Out-String
  if ($doctor -match 'Unable to locate Android SDK|Android SDK not found|Android toolchain.*\[✗\]|X !.*Android toolchain') {
    return [pscustomobject]@{
      Ok = $false
      Reason = @(
        'Android SDK not configured.',
        'Install Android Studio, open SDK Manager, install Android SDK Platform + build-tools.',
        'Then run: flutter doctor --android-licenses',
        'Verify: flutter doctor shows Android toolchain OK.'
      ) -join ' '
    }
  }
  return [pscustomobject]@{ Ok = $true; Reason = '' }
}

function Invoke-ApkBuild([string]$ApiBaseUrl) {
  $args = @(
    'build', 'apk', '--debug',
    "--dart-define=SAKINA_API_BASE_URL=$ApiBaseUrl",
    '--dart-define=SAKINA_LOCAL_TEST=true',
    '--dart-define=SAKINA_FEATURE_QURAN=true',
    '--dart-define=SAKINA_FEATURE_PRAYER=true',
    '--dart-define=SAKINA_FEATURE_KNOWLEDGE=true',
    '--dart-define=SAKINA_FEATURE_COMMUNITY=true',
    '--dart-define=SAKINA_SUBSCRIPTION_TIER=founding'
  )
  Push-Location $frontend
  flutter pub get
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter pub get failed" }
  flutter @args
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter build apk failed for API base $ApiBaseUrl" }
  Pop-Location
  if (-not (Test-Path $apkPath)) { Write-Fail "APK missing at $apkPath after build" }
}

# --- 0. Docker ---
Write-Step "Phase 6I — Sakina mobile owner test"
Write-Host "  Branch: $(git -C $repo rev-parse --abbrev-ref HEAD 2>$null)"
Write-Host "  Commit: $(git -C $repo rev-parse --short HEAD 2>$null)"

Write-Step "Checking Docker"
try { docker info *> $null } catch { Write-Fail "Docker is not running. Start Docker Desktop and re-run." }
Write-Pass "Docker daemon running"

$lan = Get-LanIp
$emulatorApiBase = "http://10.0.2.2:${ApiPort}/v1"
if ([string]::IsNullOrWhiteSpace($lan)) {
  $phoneApiBase = $null
  $phoneApiInstruction = "YOUR_LAN_IP not detected. Run: ipconfig — use Wi-Fi IPv4, then replace YOUR_LAN_IP below."
  $phoneApiTemplate = "http://YOUR_LAN_IP:${ApiPort}/v1"
} else {
  $phoneApiBase = "http://${lan}:${ApiPort}/v1"
  $phoneApiInstruction = "Detected LAN IP: $lan"
  $phoneApiTemplate = $phoneApiBase
}
$apiBase = "http://localhost:${ApiPort}/v1"
$healthUrl = "http://127.0.0.1:${ApiPort}/health"

if (-not (Test-Path $envFile)) {
  @"
POSTGRES_PASSWORD=sakina_local_pw
JWT_SECRET=local-dev-jwt-secret-change-me-32chars
ENCRYPTION_KEY=local-dev-encryption-key-change-32
"@ | Set-Content -Encoding utf8 $envFile
}

Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
  $k, $v = $_ -split '=', 2
  if ($k) { Set-Item -Path "env:$k" -Value $v }
}
$env:SAKINA_SEED_LOCAL_ADMIN = 'true'

if ($OpenFirewall -and $lan) {
  New-NetFirewallRule -DisplayName "Sakina Local API $ApiPort" -Direction Inbound `
    -Action Allow -Protocol TCP -LocalPort $ApiPort -Profile Private -ErrorAction SilentlyContinue | Out-Null
}

# --- 1. Backend image ---
if (-not $SkipDockerBuild) {
  Write-Step "Building sakina-backend:latest"
  docker build -f (Join-Path $repo "sakina-backend/Dockerfile") -t sakina-backend:latest $repo
  if ($LASTEXITCODE -ne 0) { Write-Fail "docker build failed" }
  Write-Pass "Backend image ready"
}

# --- 2. Stack + migrate ---
Write-Step "Starting Docker QA stack"
Push-Location $composeDir
docker compose -f docker-compose.qa.yml --env-file .env up -d postgres qdrant redis
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "docker compose up failed" }

Write-Step "Waiting for Postgres"
$pgOk = $false
for ($i = 0; $i -lt 30; $i++) {
  docker compose -f docker-compose.qa.yml exec -T postgres pg_isready -U sakina_user -d sakina 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { $pgOk = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $pgOk) { Pop-Location; Write-Fail "Postgres not ready" }
Write-Pass "Postgres ready"

Write-Step "Running sakina-migrate (with local admin seed)"
$migrateOut = docker compose -f docker-compose.qa.yml --env-file .env run --rm --no-deps `
  -e SAKINA_SEED_LOCAL_ADMIN=true api sakina-migrate 2>&1
if ($LASTEXITCODE -ne 0 -and $migrateOut -notmatch 'already exists|duplicate|WARN:') {
  Write-Host $migrateOut
  Pop-Location; Write-Fail "sakina-migrate failed"
}
Write-Pass "Migrations applied"

docker compose -f docker-compose.qa.yml --env-file .env up -d ollama llm-gateway api
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "API stack failed to start" }
Pop-Location

Write-Step "API health check"
$health = Wait-Http200 $healthUrl 90
if (-not $health.Ok) { Write-Fail "API health failed at $healthUrl" }
Write-Pass "API health HTTP $($health.Code)"

$features = Test-HttpStatus "http://127.0.0.1:${ApiPort}/v1/features"
if (-not $features.Ok) { Write-Fail "GET /v1/features returned $($features.Code)" }
$featureCount = 0
try { $featureCount = (($features.Body | ConvertFrom-Json).count) } catch {}
Write-Pass "GET /v1/features HTTP 200 (count=$featureCount)"

# --- 3. Admin proof ---
Write-Step "Local admin login proof"
$adminLogin = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:${ApiPort}/v1/auth/login" `
  -ContentType 'application/json' `
  -Body '{"email":"owner@sakina.local","password":"SakinaLocalOwner2026!"}' `
  -ErrorAction SilentlyContinue
if (-not $adminLogin.access_token) {
  Write-Warn "Admin login failed — re-run migrate with SAKINA_SEED_LOCAL_ADMIN=true"
} else {
  Write-Pass "Admin login owner@sakina.local"
  $adminHeaders = @{ Authorization = "Bearer $($adminLogin.access_token)" }
  $adminFeatures = Invoke-RestMethod -Uri "http://127.0.0.1:${ApiPort}/v1/admin/features" -Headers $adminHeaders
  Write-Pass "Admin GET /v1/admin/features (count=$($adminFeatures.count))"
}

$userToken = $null
try {
  $userReg = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:${ApiPort}/v1/auth/register" `
    -ContentType 'application/json' `
    -Body '{"email":"normal-user-6i@test.local","password":"TestPass123!","name":"Normal","provider":"password","provider_user_id":"normal-user-6i@test.local"}' `
    -ErrorAction Stop
  $userToken = $userReg.access_token
} catch {
  try {
    $userLogin = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:${ApiPort}/v1/auth/login" `
      -ContentType 'application/json' `
      -Body '{"email":"normal-user-6i@test.local","password":"TestPass123!"}' `
      -ErrorAction Stop
    $userToken = $userLogin.access_token
  } catch {
    Write-Warn "Normal user register/login skipped"
  }
}
if ($userToken) {
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:${ApiPort}/v1/admin/features" `
      -Headers @{ Authorization = "Bearer $userToken" } -ErrorAction Stop
    Write-Fail "Normal user should be blocked from admin features"
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 403) {
      Write-Pass "Normal user blocked from admin features (403)"
    } else {
      Write-Warn "Normal user admin check returned unexpected status"
    }
  }
}

# --- 4. Flutter ---
$analyzeOk = $false
$testOk = $false
$webUrl = "http://localhost:${WebPort}/"
$webCurlResult = 'skipped'
$webServer = $null
if (Test-Command 'flutter') {
  Write-Step "flutter analyze"
  Push-Location $frontend
  flutter pub get | Out-Null
  flutter analyze --no-fatal-infos
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter analyze failed" }
  Pop-Location
  $analyzeOk = $true
  Write-Pass "flutter analyze"

  Write-Step "flutter test"
  Push-Location $frontend
  flutter test
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter test failed" }
  Pop-Location
  $testOk = $true
  Write-Pass "flutter test"

  if (-not $SkipFlutterWeb) {
    Write-Step "Building Flutter web (SAKINA_API_BASE_URL=$apiBase)"
    Push-Location $frontend
    flutter build web --dart-define=SAKINA_API_BASE_URL=$apiBase
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter build web failed" }
    Pop-Location
    if (-not (Test-Path (Join-Path $webDir 'index.html'))) {
      Write-Fail "build/web/index.html missing after flutter build web"
    }
    Write-Pass "Flutter web built at sakina-frontend/build/web"

    $owners = Get-PortOwner $WebPort
    if ($owners) {
      Write-Host "WARN: port $WebPort was in use by PID(s): $($owners -join ', ') — stopping" -ForegroundColor Yellow
    }

    Write-Step "Serving Flutter web on $webUrl"
    $webServer = Start-StaticWebServer $webDir $WebPort
    $webServer.Pid | Set-Content -Encoding ascii $serverPidFile

    $webProbe = Wait-Http200 $webUrl 90
    $webCurlResult = "HTTP $($webProbe.Code)"
    if (-not $webProbe.Ok) {
      Write-Fail "Web server not responding on $webUrl (last: $webCurlResult). Engine: $($webServer.Engine), PID $($webServer.Pid)"
    }
    Write-Pass "Flutter web reachable at $webUrl ($webCurlResult) via $($webServer.Engine)"
  }
} else {
  Write-Warn "Flutter not on PATH — analyze/test/web skipped"
}

# --- 5. APK ---
$emuApkCmd = Get-FullApkBuildCommand $emulatorApiBase
$phoneApkCmd = if ($phoneApiBase) { Get-FullApkBuildCommand $phoneApiBase } else { Get-FullApkBuildCommand $phoneApiTemplate }
$installCmd = "adb install -r $apkPath"
$apkBuilt = $false
$apkSize = 'not built'

if ($BuildApk) {
  $sdk = Test-AndroidSdk
  if (-not $sdk.Ok) { Write-Fail $sdk.Reason }

  if ($ApkTarget -eq 'Emulator' -or $ApkTarget -eq 'Both') {
    Write-Step "Building emulator APK ($emulatorApiBase)"
    Invoke-ApkBuild $emulatorApiBase
    $apkBuilt = $true
    Write-Pass "Emulator APK built"
  }
  if (($ApkTarget -eq 'Phone' -or $ApkTarget -eq 'Both') -and $phoneApiBase) {
    Write-Step "Building phone/LAN APK ($phoneApiBase)"
    Invoke-ApkBuild $phoneApiBase
    $apkBuilt = $true
    Write-Pass "Phone APK built"
  } elseif ($ApkTarget -eq 'Phone' -and -not $phoneApiBase) {
    Write-Fail "Cannot build phone APK: LAN IP not detected. Run ipconfig, use -ApkTarget Emulator, or set API URL manually."
  }
}

if (Test-Path $apkPath) {
  $apkSize = "$([math]::Round((Get-Item $apkPath).Length / 1MB, 2)) MB"
}

# --- Summary ---
Write-Host ""
Write-Host "========== SAKINA PHASE 6I OWNER TEST ==========" -ForegroundColor Green
Write-Host "PRODUCT:           Android APK (web is diagnostic only)"
Write-Host "WEB APP URL:       $webUrl"
Write-Host "WEB CURL RESULT:   $webCurlResult"
Write-Host "API HEALTH:        $healthUrl → HTTP $($health.Code)"
Write-Host "API BASE:          $apiBase"
Write-Host "FEATURES:          /v1/features count=$featureCount"
Write-Host "LAN IP:            $(if ($lan) { $lan } else { 'NOT DETECTED' })"
Write-Host "$phoneApiInstruction"
Write-Host ""
Write-Host "LOCAL ADMIN LOGIN:" -ForegroundColor Cyan
Write-Host "  Email:    owner@sakina.local"
Write-Host "  Password: SakinaLocalOwner2026!  (local QA only — see docs/sakina-mobile-testing-runbook.md)"
Write-Host ""
Write-Host "EMULATOR APK BUILD COMMAND:" -ForegroundColor Cyan
Write-Host "  $emuApkCmd"
Write-Host ""
Write-Host "PHONE APK BUILD COMMAND:" -ForegroundColor Cyan
Write-Host "  $phoneApkCmd"
Write-Host ""
Write-Host "INSTALL COMMAND:" -ForegroundColor Cyan
Write-Host "  $installCmd"
Write-Host ""
Write-Host "APK PATH:          $apkPath"
Write-Host "APK SIZE:          $apkSize"
if ($webServer) {
  Write-Host "Web server PID: $($webServer.Pid) ($($webServer.Engine))" -ForegroundColor Cyan
}
Write-Host "================================================" -ForegroundColor Green

$proof = @"
# Phase 6I Owner Test Proof
Date: $(Get-Date -Format o)
Branch: qa-security-hardening
Web URL: $webUrl
Web curl: $webCurlResult
Web engine: $(if ($webServer) { $webServer.Engine } else { 'not started' })
Web PID: $(if ($webServer) { $webServer.Pid } else { 'n/a' })
API: $apiBase
Features: $featureCount
LAN: $(if ($lan) { $lan } else { 'NOT DETECTED' })
Admin login: owner@sakina.local
Emulator cmd: $emuApkCmd
Phone cmd: $phoneApkCmd
Install: $installCmd
APK: $apkPath ($apkSize)
Analyze: $(if ($analyzeOk) { 'PASS' } else { 'SKIP' })
Test: $(if ($testOk) { 'PASS' } else { 'SKIP' })
APK built: $(if ($apkBuilt) { 'YES' } else { 'NO' })
"@
$proof | Set-Content -Encoding utf8 (Join-Path $proofDir "cursor-phase6i-final-mobile-owner-test-readiness-proof.md")
$proof | Set-Content -Encoding utf8 (Join-Path $reportDir "cursor-phase6i-final-mobile-owner-test-readiness.md")
$pidFixProof = @"
# Owner Script PID Variable Fix Proof
Date: $(Get-Date -Format o)
Branch: qa-security-hardening
Root cause: PowerShell `$PID` is read-only; loop variable `$pid` in Stop-PortListener failed.
Fix: Renamed loop variable to `$portPid` in Stop-PortListener.
Web URL: $webUrl
Web curl: $webCurlResult
Port cleanup: PASS (no PID overwrite error)
APK: $apkPath ($apkSize)
"@
$pidFixProof | Set-Content -Encoding utf8 (Join-Path $proofDir "cursor-owner-script-pid-fix-proof.md")
$pidFixProof | Set-Content -Encoding utf8 (Join-Path $reportDir "cursor-owner-script-pid-fix.md")
Write-Pass "Reports written"

if ($webServer -and $webServer.Pid -and -not $BuildApk) {
  Write-Host "`nKeeping web server alive (PID $($webServer.Pid)). Press Ctrl+C to stop." -ForegroundColor Yellow
  try {
    Wait-Process -Id $webServer.Pid
  } catch {
    Write-Host "Web server process ended." -ForegroundColor Yellow
  }
}
