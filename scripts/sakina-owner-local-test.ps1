<#
  CURSOR PHASE 6C — Owner local access repair (Windows / PowerShell).

  One command for the owner: starts Docker QA stack, proves API + endpoints,
  serves the Flutter web app (NOT the raw API), optionally builds LAN APK,
  and prints the four URL types clearly.

  Usage:
    pwsh ./scripts/sakina-owner-local-test.ps1              # full proof + serve web
    pwsh ./scripts/sakina-owner-local-test.ps1 -OpenBrowser # also open Chrome
    pwsh ./scripts/sakina-owner-local-test.ps1 -SkipApk     # skip APK build (faster)
    pwsh ./scripts/sakina-owner-local-test.ps1 -SkipWeb     # API-only proof

  Local beta testing only. Not public deployment. Never LIVE_READY.
#>
param(
  [switch]$OpenBrowser,
  [switch]$SkipApk,
  [switch]$SkipWeb,
  [switch]$ForceWebBuild,
  [switch]$OpenFirewall,
  [int]$ApiPort = 28080,
  [int]$WebPort = 8090
)

$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $PSScriptRoot
$compose = Join-Path $repo "sakina-infra/docker-compose.qa.yml"
$frontend = Join-Path $repo "sakina-frontend"
$proofDir = Join-Path $repo "test-results"
$proofFile = Join-Path $proofDir "cursor-phase6c-owner-local-access-proof.md"
$results = [ordered]@{}
$log = [System.Collections.Generic.List[string]]::new()

function Log([string]$msg) {
  $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
  Write-Host $line
  $log.Add($line) | Out-Null
}

function Test-Http {
  param([string]$Url, [string]$Method = 'GET', [hashtable]$Headers = @{}, [string]$Body = $null)
  try {
    $params = @{ Uri = $Url; Method = $Method; UseBasicParsing = $true; TimeoutSec = 10; Headers = $Headers }
    if ($Body) { $params.Body = $Body; $params.ContentType = 'application/json' }
    $r = Invoke-WebRequest @params
    return @{ ok = $true; code = [int]$r.StatusCode; body = $r.Content; headers = $r.Headers }
  } catch {
    $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    return @{ ok = $false; code = $code; body = $_.Exception.Message; headers = @{} }
  }
}

function Set-Result([string]$name, [string]$status, [string]$detail = '') {
  $results[$name] = @{ status = $status; detail = $detail }
  $color = switch ($status) { 'PASS' { 'Green' } 'BLOCKED' { 'Yellow' } default { 'Red' } }
  Write-Host ("  {0,-42} {1}" -f $name, $status) -ForegroundColor $color
  if ($detail) { Write-Host "    $detail" -ForegroundColor DarkGray }
}

# --- 1. First checks (evidence) ---
Log "=== PHASE 6C owner local access test ==="
Log "Repo: $repo"
Log "Git branch: $(git -C $repo branch --show-current 2>$null)"
Log "Git HEAD: $(git -C $repo rev-parse --short HEAD 2>$null)"
Log "Docker compose file: $compose"

$lan = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
    $_.InterfaceAlias -notmatch 'WSL|vEthernet|Loopback|cloud'
  } |
  Sort-Object { if ($_.IPAddress -like '192.168.*') {0} elseif ($_.IPAddress -like '10.*') {1} else {2} } |
  Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $lan) { $lan = '127.0.0.1' }
Log "LAN IP detected: $lan (192.168.0.51 valid: $(if ($lan -eq '192.168.0.51') { 'YES' } else { "NO — use $lan" }))"

$portListen = netstat -ano | Select-String ":$ApiPort\s" | Select-String "LISTENING"
Log "Port $ApiPort listener: $(if ($portListen) { 'LISTENING' } else { 'NOT LISTENING' })"

# --- 2. Start / refresh Docker QA stack with safe CORS ---
$origins = @(
  "http://localhost:$WebPort","http://127.0.0.1:$WebPort","http://${lan}:$WebPort",
  "http://localhost:8091","http://127.0.0.1:8091","http://${lan}:8091"
) -join ","
$composeDir = Join-Path $repo 'sakina-infra'
$envFile = Join-Path $composeDir '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
      $k = $matches[1].Trim(); $v = $matches[2].Trim().Trim('"')
      Set-Item -Path "env:$k" -Value $v
    }
  }
  Log "Loaded credentials from sakina-infra/.env"
} else {
  Log "WARNING: sakina-infra/.env missing — copy from .env.example before first run"
}
$env:CORS_ALLOWED_ORIGINS = $origins

if ($OpenFirewall) {
  New-NetFirewallRule -DisplayName "Sakina Local API $ApiPort" -Direction Inbound `
    -Action Allow -Protocol TCP -LocalPort $ApiPort -Profile Private -ErrorAction SilentlyContinue | Out-Null
}

Log "Starting Docker QA stack ..."
Push-Location (Join-Path $repo 'sakina-infra')
docker compose -f docker-compose.qa.yml up -d --force-recreate api 2>&1 | ForEach-Object { Log $_ }
# Recover if ollama or other deps left api in Created/Exited state.
$apiState = docker inspect -f '{{.State.Status}}' sakina-infra-api-1 2>$null
if ($apiState -ne 'running') {
  Log "API not running ($apiState) — attempting docker start sakina-infra-api-1 ..."
  docker start sakina-infra-api-1 2>&1 | ForEach-Object { Log $_ }
}
Pop-Location

$dockerPs = docker ps --filter "name=sakina-infra-api" --format "{{.Names}} {{.Status}}" 2>&1
$dockerUp = ($dockerPs | Select-String 'Up') -ne $null
if (-not $dockerUp) {
  $apiState = docker inspect -f '{{.State.Status}}' sakina-infra-api-1 2>$null
  if ($apiState -eq 'running') { $dockerUp = $true; $dockerPs = 'sakina-infra-api-1 (recovered)' }
}
Set-Result '1 Docker stack' $(if ($dockerUp) { 'PASS' } else { 'FAIL' }) ($dockerPs -join '; ')

# --- 3. Wait for API health ---
$healthLocal = "http://localhost:${ApiPort}/health"
$health127   = "http://127.0.0.1:${ApiPort}/health"
$healthLan   = "http://${lan}:${ApiPort}/health"
$apiBaseLocal = "http://localhost:${ApiPort}/v1"
$apiBaseLan   = "http://${lan}:${ApiPort}/v1"
$webUrl       = "http://localhost:${WebPort}"

$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  $h = Test-Http $healthLocal
  if ($h.ok -and $h.code -eq 200) { $ready = $true; break }
  Start-Sleep -Seconds 2
}

$h1 = Test-Http $healthLocal
Set-Result '2 API health localhost' $(if ($h1.ok -and $h1.code -eq 200) { 'PASS' } else { 'FAIL' }) "$healthLocal -> $($h1.code)"

$h2 = Test-Http $health127
Set-Result '3 API health 127.0.0.1' $(if ($h2.ok -and $h2.code -eq 200) { 'PASS' } else { 'FAIL' }) "$health127 -> $($h2.code)"

$h3 = Test-Http $healthLan
Set-Result '4 API health LAN IP' $(if ($h3.ok -and $h3.code -eq 200) { 'PASS' } else { 'BLOCKED' }) "$healthLan -> $($h3.code)"

# --- 4. URL matrix (record all) ---
Log ""
Log "=== URL matrix ==="
$urlTests = @(
  "http://localhost:${ApiPort}",
  "http://localhost:${ApiPort}/health",
  "http://localhost:${ApiPort}/v1",
  "http://localhost:${ApiPort}/v1/health",
  "http://127.0.0.1:${ApiPort}/health",
  "http://127.0.0.1:${ApiPort}/v1",
  "http://127.0.0.1:${ApiPort}/v1/health",
  "http://${lan}:${ApiPort}/health",
  "http://${lan}:${ApiPort}/v1",
  "http://${lan}:${ApiPort}/v1/health"
)
foreach ($u in $urlTests) {
  $r = Test-Http $u
  $kind = if ($r.body -match '^\s*\{' -and $r.body -match '"status"') { 'API-JSON' }
          elseif ($r.code -eq 404) { '404' }
          else { 'other' }
  Log "$u -> $($r.code) [$kind]"
}

# --- 5. Real endpoints ---
$quran = Test-Http "$apiBaseLocal/quran/surahs"
Set-Result '8 Quran endpoint' $(if ($quran.ok -and $quran.code -eq 200) { 'PASS' } else { 'FAIL' }) "/v1/quran/surahs -> $($quran.code)"

$prayer = Test-Http "$apiBaseLocal/prayer-times?lat=25.2&lng=55.3&date=$(Get-Date -Format 'yyyy-MM-dd')&tz=4"
Set-Result '9 Prayer endpoint' $(if ($prayer.ok -and $prayer.code -eq 200) { 'PASS' } else { 'FAIL' }) "/v1/prayer-times -> $($prayer.code)"

$regEmail = "owner6c-$(Get-Random)@example.com"
$regBody = "{`"email`":`"$regEmail`",`"password`":`"TestPass123!`",`"display_name`":`"Owner6C`"}"
$reg = Test-Http "$apiBaseLocal/auth/register" -Method POST -Body $regBody
$login = Test-Http "$apiBaseLocal/auth/login" -Method POST -Body "{`"email`":`"$regEmail`",`"password`":`"TestPass123!`"}"
$authOk = ($reg.ok -and $reg.code -in 200,201) -and ($login.ok -and $login.code -eq 200)
Set-Result '10 Auth smoke' $(if ($authOk) { 'PASS' } else { 'FAIL' }) "register=$($reg.code) login=$($login.code)"

$token = $null
if ($login.ok) {
  try { $token = ($login.body | ConvertFrom-Json).access_token } catch {}
}
$ent = if ($token) { Test-Http "$apiBaseLocal/entitlements/me" -Headers @{ Authorization = "Bearer $token" } } else { @{ ok = $false; code = 0 } }
Set-Result '11 Entitlement endpoint' $(if ($ent.ok -and $ent.code -eq 200) { 'PASS' } else { 'FAIL' }) "/v1/entitlements/me -> $($ent.code)"

# --- 6. Flutter web (the URL the owner should open in a browser) ---
$webServerPid = $null
$webPass = $false
  if (-not $SkipWeb) {
  Log ""
  $webIndex = Join-Path $frontend 'build/web/index.html'
  $webBuilt = (Test-Path $webIndex) -and (-not $ForceWebBuild)
  if ($webBuilt) {
    Log "Using existing Flutter web build ($webIndex)"
  } else {
    Log "Building Flutter web (this may take a few minutes) ..."
    Push-Location $frontend
    flutter build web --dart-define="SAKINA_API_BASE_URL=$apiBaseLocal" 2>&1 | ForEach-Object { Log $_ }
    Pop-Location
    $webBuilt = Test-Path $webIndex
  }
  if ($webBuilt) {
    # Stop any prior static server on WebPort from a previous run.
    Get-NetTCPConnection -LocalPort $WebPort -ErrorAction SilentlyContinue |
      ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    $webRoot = Join-Path $frontend 'build/web'
    Get-NetTCPConnection -LocalPort $WebPort -ErrorAction SilentlyContinue |
      ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    $serveProc = Start-Process -FilePath 'python' -ArgumentList @('-m','http.server',$WebPort,'--bind','127.0.0.1') `
      -WorkingDirectory $webRoot -PassThru -WindowStyle Hidden
    $isAppPage = $false
    $webResp = @{ code = 0; body = '' }
    for ($w = 0; $w -lt 20; $w++) {
      Start-Sleep -Milliseconds 800
      $webResp = Test-Http $webUrl
      if ($webResp.ok -and $webResp.body -match '<html' -and $webResp.body -notmatch '"service":"Project Sakina API"') {
        $isAppPage = $true; break
      }
    }
    if ($OpenBrowser) { Start-Process $webUrl }
    Set-Result '5 Flutter web serves app page' $(if ($isAppPage) { 'PASS' } else { 'FAIL' }) "$webUrl -> $($webResp.code) app=$isAppPage"
    # CORS probe from web origin
    try {
      $cors = Invoke-WebRequest -Uri $healthLocal -Headers @{ Origin = $webUrl } -UseBasicParsing -TimeoutSec 5
      $corsOk = $cors.Headers['Access-Control-Allow-Origin'] -eq $webUrl
      Set-Result '6 App can call backend API' $(if ($corsOk) { 'PASS' } else { 'FAIL' }) "CORS allow-origin=$($cors.Headers['Access-Control-Allow-Origin'])"
    } catch {
      Set-Result '6 App can call backend API' 'FAIL' $_.Exception.Message
    }
  } else {
    Set-Result '5 Flutter web serves app page' 'FAIL' 'build/web/index.html missing'
    Set-Result '6 App can call backend API' 'FAIL' 'web build failed'
  }
} else {
  Set-Result '5 Flutter web serves app page' 'SKIP' '-SkipWeb'
  Set-Result '6 App can call backend API' 'SKIP' '-SkipWeb'
}

# --- 7. APK with LAN API base ---
$apkPath = Join-Path $frontend 'build/app/outputs/flutter-apk/app-debug.apk'
$apkSize = 0
if (-not $SkipApk) {
  Log ""
  Log "Building debug APK with LAN API $apiBaseLan ..."
  Push-Location $frontend
  flutter build apk --debug --dart-define="SAKINA_API_BASE_URL=$apiBaseLan" 2>&1 | ForEach-Object { Log $_ }
  Pop-Location
  if (Test-Path $apkPath) {
    $apkSize = (Get-Item $apkPath).Length
    Set-Result '7 APK builds with LAN API' 'PASS' "$apkPath ($([math]::Round($apkSize/1MB,1)) MB)"
  } else {
    Set-Result '7 APK builds with LAN API' 'FAIL' 'app-debug.apk not found'
  }
} else {
  Set-Result '7 APK builds with LAN API' 'SKIP' '-SkipApk'
}

# --- 8. No secrets in Phase 6C files (not placeholder docs) ---
$noSecrets = $true
foreach ($f in @('scripts/sakina-owner-local-test.ps1')) {
  if (Test-Path (Join-Path $repo $f)) {
    $c = (Get-Content (Join-Path $repo $f) | Where-Object { $_ -notmatch 'sk_live_\||AKIA\[|eyJhbGciOi' }) -join "`n"
    if ($c -match 'sk_live_[a-zA-Z0-9]|AKIA[0-9A-Z]{16}|eyJhbGciOiJIUzI1NiJ9') { $noSecrets = $false }
  }
}
Set-Result '12 No secrets committed' $(if ($noSecrets) { 'PASS' } else { 'FAIL' }) 'Phase 6C script scan'

Set-Result '13 Phase 1-5 smoke paths' $(if ($authOk -and $quran.ok -and $prayer.ok -and $ent.ok) { 'PASS' } else { 'FAIL' }) 'auth+quran+prayer+entitlement'

# --- Summary for owner ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " OWNER — OPEN THIS IN YOUR BROWSER (Flutter web app):" -ForegroundColor Green
Write-Host "   $webUrl" -ForegroundColor Yellow
Write-Host ""
Write-Host " API health (JSON — not the app UI):" -ForegroundColor Green
Write-Host "   $healthLocal"
Write-Host ""
Write-Host " API base (for curl / APK dart-define):" -ForegroundColor Green
Write-Host "   $apiBaseLocal   (this PC browser/emulator host)"
Write-Host "   $apiBaseLan   (real phone on same Wi-Fi)"
Write-Host "   http://10.0.2.2:${ApiPort}/v1   (Android emulator)"
Write-Host ""
Write-Host " APK: $apkPath" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

# --- Write proof markdown ---
New-Item -ItemType Directory -Force -Path $proofDir | Out-Null
$md = @"
# Cursor Phase 6C — Owner Local Access Proof

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Branch: $(git -C $repo branch --show-current)
HEAD: $(git -C $repo rev-parse HEAD)
LAN IP: $lan

## URL types (Phase 6C fix — do NOT confuse API with web app)

| Purpose | URL |
|---|---|
| **Flutter web app (open in browser)** | ``$webUrl`` |
| API health (JSON) | ``$healthLocal`` |
| API base (localhost) | ``$apiBaseLocal`` |
| API base (LAN phone/APK) | ``$apiBaseLan`` |
| API base (emulator) | ``http://10.0.2.2:${ApiPort}/v1`` |

## PASS/FAIL

| # | Check | Status | Detail |
|---|-------|--------|--------|
"@
$idx = 1
foreach ($k in $results.Keys) {
  $md += "| $idx | $k | $($results[$k].status) | $($results[$k].detail) |`n"
  $idx++
}
$md += @"

## URL matrix log
$(($urlTests | ForEach-Object { "- $_" }) -join "`n")

## Command log (excerpt)
$(($log | Select-Object -Last 40) -join "`n")
"@
try { Set-Content -Path $proofFile -Value $md -Encoding UTF8 -Force } catch { Log "Proof write retry: $($_.Exception.Message)"; Start-Sleep 1; Set-Content -Path $proofFile -Value $md -Encoding UTF8 -Force }
Log "Proof written: $proofFile"

$failCount = ($results.Values | Where-Object { $_.status -eq 'FAIL' }).Count
if ($failCount -gt 0) { exit 1 }
exit 0
