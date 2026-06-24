<#
  CURSOR PHASE 6G — Mobile-first APK testing (web is diagnostic only).

  One owner command: Docker QA stack + API health + Flutter web build + stable
  static server on :8090 (Node serve preferred, PowerShell HttpListener fallback).
  Waits for HTTP 200 before opening the browser. Keeps the web server alive.

  Usage:
    pwsh ./scripts/sakina-owner-local-test.ps1
    pwsh ./scripts/sakina-owner-local-test.ps1 -OpenFirewall
    pwsh ./scripts/sakina-owner-local-test.ps1 -SkipFlutterWeb
    pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
    pwsh ./scripts/sakina-owner-local-test.ps1 -SkipDockerBuild

  NOT public deployment. Local beta only.
#>
param(
  [switch]$OpenFirewall,
  [switch]$SkipFlutterWeb,
  [switch]$BuildApk,
  [switch]$SkipDockerBuild,
  [switch]$NoBrowser,
  [int]$ApiPort = 28080,
  [int]$WebPort = 8090
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$composeDir = Join-Path $repo "sakina-infra"
$compose = Join-Path $composeDir "docker-compose.qa.yml"
$frontend = Join-Path $repo "sakina-frontend"
$envFile = Join-Path $composeDir ".env"
$webDir = Join-Path $frontend "build/web"
$proofDir = Join-Path $repo "test-results"
$reportDir = Join-Path $repo "reports"
$proofFile = Join-Path $proofDir "cursor-phase6g-mobile-workflows-user-journeys-proof.md"
$reportFile = Join-Path $reportDir "cursor-phase6g-mobile-workflows-user-journeys-proof.md"
$apkDartDefines = @(
  "SAKINA_API_BASE_URL={0}",
  "SAKINA_LOCAL_TEST=true",
  "SAKINA_FEATURE_QURAN=true",
  "SAKINA_FEATURE_PRAYER=true",
  "SAKINA_FEATURE_KNOWLEDGE=true",
  "SAKINA_FEATURE_COMMUNITY=true",
  "SAKINA_SUBSCRIPTION_TIER=founding"
) -join " --dart-define="
$serverPidFile = Join-Path $proofDir ".sakina-web-server.pid"
New-Item -ItemType Directory -Force -Path $proofDir, $reportDir | Out-Null

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Pass([string]$msg) { Write-Host "PASS: $msg" -ForegroundColor Green }
function Write-Fail([string]$msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }

function Get-LanIp {
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
  if (-not $ip) { return "127.0.0.1" }
  return $ip
}

function Ensure-EnvFile {
  if (Test-Path $envFile) { return }
  Write-Step "Creating sakina-infra/.env with local dev placeholders"
  @"
POSTGRES_PASSWORD=sakina_local_pw
JWT_SECRET=local-dev-jwt-secret-change-me-32chars
ENCRYPTION_KEY=local-dev-encryption-key-change-32
"@ | Set-Content -Encoding utf8 $envFile
}

function Test-HttpStatus([string]$Url) {
  try {
    $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    return [pscustomobject]@{ Url = $Url; Code = [int]$r.StatusCode; Ok = ($r.StatusCode -eq 200); Body = $r.Content }
  } catch {
    $code = 0
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode.value__ }
    return [pscustomobject]@{ Url = $Url; Code = $code; Ok = $false; Body = '' }
  }
}

function Wait-Http200([string]$Url, [int]$Seconds = 60) {
  for ($i = 0; $i -lt $Seconds; $i++) {
    $r = Test-HttpStatus $Url
    if ($r.Ok) { return $r }
    Start-Sleep -Seconds 1
  }
  return Test-HttpStatus $Url
}

function Get-PortOwner([int]$Port) {
  Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique
}

function Stop-PortListener([int]$Port) {
  foreach ($pid in Get-PortOwner $Port) {
    if ($pid -and $pid -ne $PID) {
      Write-Host "Stopping process on port $Port (PID $pid)" -ForegroundColor Yellow
      Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }
  }
  Start-Sleep -Milliseconds 500
}

function Test-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  return [bool]$cmd
}

function Start-StaticWebServer([string]$Dir, [int]$Port) {
  Stop-PortListener $Port
  $serveScript = Join-Path $PSScriptRoot "serve-static-web.ps1"
  $dirFull = (Resolve-Path $Dir).Path

  if (Test-Command 'npx') {
    Write-Host "Starting Node static server (npx serve) on port $Port" -ForegroundColor DarkGray
    $npx = (Get-Command npx).Source
    $proc = Start-Process -FilePath $npx -ArgumentList @(
      '--yes', 'serve', $dirFull, '-l', "$Port", '-s'
    ) -PassThru -WindowStyle Hidden -WorkingDirectory $dirFull
    Start-Sleep -Seconds 3
    if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
      Write-Host "npx serve exited early — falling back to PowerShell HttpListener" -ForegroundColor Yellow
    } else {
      return [pscustomobject]@{ Pid = $proc.Id; Engine = 'npx serve' }
    }
  } elseif (Test-Command 'node') {
    Write-Host "Starting Node http-server on port $Port" -ForegroundColor DarkGray
    $node = (Get-Command node).Source
    $proc = Start-Process -FilePath $node -ArgumentList @(
      (Join-Path $env:APPDATA 'npm\node_modules\http-server\bin\http-server'),
      $dirFull, '-p', "$Port", '-c-1', '--silent'
    ) -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
    if ($proc -and (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
      return [pscustomobject]@{ Pid = $proc.Id; Engine = 'http-server' }
    }
  }

  Write-Host "Using PowerShell HttpListener fallback on port $Port" -ForegroundColor Yellow
  $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $serveScript,
    '-Root', $dirFull, '-Port', $Port
  ) -PassThru -WindowStyle Hidden
  return [pscustomobject]@{ Pid = $proc.Id; Engine = 'PowerShell HttpListener' }
}

# --- Diagnostics header ---
Write-Step "Phase 6D diagnostics"
Write-Host "  git branch: $(git -C $repo rev-parse --abbrev-ref HEAD 2>$null)"
Write-Host "  build/web exists: $(Test-Path (Join-Path $webDir 'index.html'))"
Write-Host "  port $WebPort listeners: $((Get-PortOwner $WebPort) -join ', ')"
Write-Host "  flutter: $(if (Test-Command 'flutter') { 'yes' } else { 'MISSING' })"
Write-Host "  node: $(if (Test-Command 'node') { (node --version) } else { 'MISSING (PS fallback used)' })"

# --- 0. Docker ---
Write-Step "Checking Docker"
try { docker info *> $null } catch {
  Write-Fail "Docker is not running. Start Docker Desktop, wait until Running, then re-run."
}
Write-Pass "Docker daemon is running"

$lan = Get-LanIp
Write-Host "LAN IP detected: $lan (used for APK only — not hardcoded in web build)" -ForegroundColor Yellow

$origins = @(
  "http://localhost:$WebPort", "http://127.0.0.1:$WebPort", "http://${lan}:$WebPort",
  "http://localhost:8091", "http://127.0.0.1:8091", "http://${lan}:8091"
) -join ","
$env:CORS_ALLOWED_ORIGINS = $origins
Ensure-EnvFile

Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
  $k, $v = $_ -split '=', 2
  if ($k) { Set-Item -Path "env:$k" -Value $v }
}

if ($OpenFirewall) {
  New-NetFirewallRule -DisplayName "Sakina Local API $ApiPort" -Direction Inbound `
    -Action Allow -Protocol TCP -LocalPort $ApiPort -Profile Private -ErrorAction SilentlyContinue | Out-Null
}

# --- 1. Build backend image ---
if (-not $SkipDockerBuild) {
  Write-Step "Building sakina-backend:latest"
  docker build -f (Join-Path $repo "sakina-backend/Dockerfile") -t sakina-backend:latest $repo
  if ($LASTEXITCODE -ne 0) { Write-Fail "docker build failed" }
  Write-Pass "sakina-backend:latest ready"
} else {
  docker image inspect sakina-backend:latest *> $null
  if ($LASTEXITCODE -ne 0) { Write-Fail "sakina-backend:latest not found. Re-run without -SkipDockerBuild." }
}

# --- 2. Docker stack ---
Write-Step "Starting Docker QA stack"
Push-Location $composeDir
docker compose -f docker-compose.qa.yml --env-file .env up -d postgres qdrant redis
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "docker compose up (core) failed" }

Write-Step "Waiting for Postgres"
$pgOk = $false
for ($i = 0; $i -lt 30; $i++) {
  docker compose -f docker-compose.qa.yml exec -T postgres pg_isready -U sakina_user -d sakina 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { $pgOk = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $pgOk) { Pop-Location; Write-Fail "Postgres did not become ready" }
Write-Pass "Postgres ready"

Write-Step "Running sakina-migrate"
$migrateOut = docker compose -f docker-compose.qa.yml --env-file .env run --rm --no-deps api sakina-migrate 2>&1
if ($LASTEXITCODE -ne 0) {
  if ($migrateOut -match 'already exists|duplicate') {
    Write-Host "WARN: migrate reported existing schema — continuing" -ForegroundColor Yellow
  } else {
    Write-Host $migrateOut
    Pop-Location; Write-Fail "sakina-migrate failed"
  }
} else {
  Write-Pass "Migrations applied"
}

Write-Step "Starting ollama + llm-gateway (optional)"
docker compose -f docker-compose.qa.yml --env-file .env up -d ollama llm-gateway 2>&1 | Out-Null

Write-Step "Starting API on 0.0.0.0:$ApiPort"
docker compose -f docker-compose.qa.yml --env-file .env up -d --force-recreate api
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "API container failed to start" }
Pop-Location

$healthUrl = "http://127.0.0.1:$ApiPort/health"
$healthV1Url = "http://127.0.0.1:$ApiPort/v1/health"
Write-Step "Waiting for API health"
$healthProbe = Wait-Http200 $healthUrl 60
if (-not $healthProbe.Ok) {
  Write-Fail "API health FAILED at $healthUrl — check: docker compose -f sakina-infra/docker-compose.qa.yml logs api"
}
Write-Pass "API health OK ($($healthProbe.Code)) at $healthUrl"

$healthV1 = Test-HttpStatus $healthV1Url
Write-Host "  /v1/health → $($healthV1.Code)" -ForegroundColor $(if ($healthV1.Ok) { 'Green' } else { 'Yellow' })

# --- 3. API smoke ---
Write-Step "API endpoint smoke"
$prayerDate = (Get-Date -Format "yyyy-MM-dd")
$quran = Test-HttpStatus "http://127.0.0.1:$ApiPort/v1/quran/surahs"
$prayer = Test-HttpStatus "http://127.0.0.1:$ApiPort/v1/prayer-times?lat=51.5&lng=-0.12&method=2&date=$prayerDate"
if (-not $quran.Ok) { Write-Fail "GET /v1/quran/surahs returned $($quran.Code)" }
if (-not $prayer.Ok) { Write-Fail "GET /v1/prayer-times returned $($prayer.Code)" }
Write-Pass "Quran + prayer-times endpoints return 200"

# --- 4. Flutter web ---
$webUrl = "http://localhost:$WebPort/"
$apiBase = "http://localhost:$ApiPort/v1"
$lanApiBase = "http://${lan}:$ApiPort/v1"
$emulatorApiBase = "http://10.0.2.2:$ApiPort/v1"
$apkPath = Join-Path $frontend "build/app/outputs/flutter-apk/app-debug.apk"
$webCurlResult = 'not started'
$webServer = $null
$analyzeOk = $false

if (-not $SkipFlutterWeb) {
  if (-not (Test-Command 'flutter')) {
    Write-Fail "Flutter SDK not found on PATH. Install Flutter 3.16+ and re-run."
  }

  Write-Step "flutter analyze"
  Push-Location $frontend
  flutter pub get
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter pub get failed" }
  flutter analyze --no-fatal-infos
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter analyze failed" }
  Pop-Location
  $analyzeOk = $true
  Write-Pass "flutter analyze passed"

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

  if (-not $NoBrowser) {
    Write-Step "Opening browser (after HTTP 200 confirmed)"
    Start-Process $webUrl
  }
}

if ($BuildApk) {
  Write-Step "Building debug APK (LAN API $lanApiBase)"
  $apkDefineArgs = ($apkDartDefines -f $lanApiBase) -split ' --dart-define=' | ForEach-Object { if ($_) { "--dart-define=$_" } }
  Push-Location $frontend
  flutter build apk --debug @apkDefineArgs
  if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "flutter build apk failed" }
  Pop-Location
  Write-Pass "APK built at $apkPath"
}

function Format-ApkCmd([string]$apiUrl) {
  $args = ($apkDartDefines -f $apiUrl) -split ' --dart-define=' | ForEach-Object { if ($_) { "--dart-define=$_" } }
  return "cd sakina-frontend && flutter build apk --debug $($args -join ' ')"
}

$apkSize = if (Test-Path $apkPath) { "$([math]::Round((Get-Item $apkPath).Length/1MB,1)) MB" } else { 'not built (use -BuildApk)' }
$phoneApkCmd = Format-ApkCmd $lanApiBase
$emuApkCmd = Format-ApkCmd $emulatorApiBase
$dockerPs = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null

# --- Owner summary ---
Write-Host ""
Write-Host "========== SAKINA MOBILE APK TEST (PHASE 6G) ==========" -ForegroundColor Green
Write-Host "REAL APP:          Install the Android APK (web :8090 is diagnostic only)"
Write-Host "WEB APP URL:       $webUrl"
Write-Host "WEB CURL RESULT:   $webCurlResult"
Write-Host "API HEALTH URL:    $healthUrl"
Write-Host "API HEALTH CURL:   HTTP $($healthProbe.Code)"
Write-Host "API BASE URL:      $apiBase"
Write-Host "PHONE APK CMD:     $phoneApkCmd"
Write-Host "EMULATOR APK CMD:  $emuApkCmd"
Write-Host "APK PATH:          $apkPath"
Write-Host "APK SIZE:          $apkSize"
Write-Host ""
Write-Host "Web server PID: $($webServer.Pid) ($($webServer.Engine)) — script stays alive until Ctrl+C" -ForegroundColor Cyan
Write-Host "Stop server: Stop-Process -Id $($webServer.Pid)" -ForegroundColor DarkGray
Write-Host "======================================================" -ForegroundColor Green

$proofBody = @"
# Cursor Phase 6D — Working Web Interface Proof

Date: $(Get-Date -Format o)
Branch: qa-security-hardening
Machine LAN IP: $lan

## Root causes fixed (Phase 6C → 6D)
- Python-only ``Start-Job`` http.server exited when the script ended (nothing on :8090).
- Browser opened before confirming HTTP 200 in some failure modes.
- No Flutter web test dashboard for API connectivity checks.
- Replaced with **Node npx serve** (or PowerShell HttpListener fallback), wait-for-200, then browser.

## Diagnostics (start of run)
- build/web existed before build: $(Test-Path (Join-Path $webDir 'index.html'))
- Docker: running
- flutter analyze: $(if ($analyzeOk) { 'PASS' } else { 'skipped' })

## curl proof
- ``curl $webUrl`` → $webCurlResult
- ``curl $healthUrl`` → HTTP $($healthProbe.Code)
- ``curl $healthV1Url`` → HTTP $($healthV1.Code)

## API smoke
- GET /v1/quran/surahs → $($quran.Code)
- GET /v1/prayer-times → $($prayer.Code)

## URLs
| Purpose | URL |
|---------|-----|
| Web app | $webUrl |
| API health | $healthUrl |
| API base | $apiBase |
| Phone/LAN API | $lanApiBase |
| Emulator API | $emulatorApiBase |

## Web server
- Engine: $($webServer.Engine)
- PID: $($webServer.Pid)
- PID file: test-results/.sakina-web-server.pid

## Docker
``````
$dockerPs
``````
"@

$proofBody | Set-Content -Encoding utf8 $proofFile
$proofBody | Set-Content -Encoding utf8 $reportFile
Write-Pass "Proof written to test-results/ and reports/"

if ($webServer -and $webServer.Pid) {
  Write-Host "`nKeeping web server alive (PID $($webServer.Pid)). Press Ctrl+C to stop." -ForegroundColor Yellow
  try {
    Wait-Process -Id $webServer.Pid
  } catch {
    Write-Host "Web server process ended." -ForegroundColor Yellow
  }
}
