<#
  PHASE 6B - Sakina local web/LAN testing launcher (Windows / PowerShell).
  Brings up the local Docker QA stack with a safe local CORS allowlist (incl. this
  machine's LAN IP), waits for API health, and prints every API base URL the owner
  can test from (localhost, LAN, Android emulator). Optionally runs Flutter web in Chrome.

  Usage:
    pwsh ./scripts/sakina-local-web.ps1                 # start stack + print URLs
    pwsh ./scripts/sakina-local-web.ps1 -Web            # also launch Flutter web in Chrome
    pwsh ./scripts/sakina-local-web.ps1 -OpenFirewall   # add inbound firewall rule for 28080 (admin)

  Not public deployment. Local beta testing only. Never marks LIVE_READY.
#>
param(
  [switch]$Web,
  [switch]$OpenFirewall,
  [int]$ApiPort = 28080,
  [int]$WebPort = 8090
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$compose = Join-Path $repo "sakina-infra/docker-compose.qa.yml"

# 1. Detect LAN IP (prefer a real 192.168.x / 10.x on Wi-Fi/Ethernet, skip WSL/virtual).
$lan = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
    $_.InterfaceAlias -notmatch 'WSL|vEthernet|Loopback'
  } |
  Sort-Object { if ($_.IPAddress -like '192.168.*') {0} elseif ($_.IPAddress -like '10.*') {1} else {2} } |
  Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $lan) { $lan = "127.0.0.1" }
Write-Host "LAN IP detected: $lan" -ForegroundColor Cyan

# 2. Build a safe, explicit CORS allowlist (NO wildcard) including localhost + LAN web origins.
$origins = @(
  "http://localhost:$WebPort","http://127.0.0.1:$WebPort","http://${lan}:$WebPort",
  "http://localhost:8091","http://127.0.0.1:8091","http://${lan}:8091"
) -join ","
$env:CORS_ALLOWED_ORIGINS = $origins
if (-not $env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD = "sakina_local_pw" }
if (-not $env:JWT_SECRET)        { $env:JWT_SECRET = "local-dev-jwt-secret-change-me" }
if (-not $env:ENCRYPTION_KEY)    { $env:ENCRYPTION_KEY = "local-dev-encryption-key-change" }

# 3. Optional: open Windows firewall for cross-device LAN access (requires admin).
if ($OpenFirewall) {
  Write-Host "Adding inbound firewall rule for TCP $ApiPort ..." -ForegroundColor Yellow
  New-NetFirewallRule -DisplayName "Sakina Local API $ApiPort" -Direction Inbound `
    -Action Allow -Protocol TCP -LocalPort $ApiPort -Profile Private -ErrorAction SilentlyContinue | Out-Null
}

# 4. Start / refresh the Docker QA stack so the new CORS env takes effect.
Write-Host "Starting Docker QA stack ..." -ForegroundColor Cyan
docker compose -f $compose up -d
docker compose -f $compose up -d --force-recreate api   # re-read CORS env on the api container

# 5. Wait for API health (bounded).
$healthUrl = "http://localhost:$ApiPort/health"
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  try { if ((Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { $ok = $true; break } } catch {}
  Start-Sleep -Seconds 2
}
if (-not $ok) { Write-Host "API health FAILED at $healthUrl" -ForegroundColor Red; exit 1 }
Write-Host "API health OK: $healthUrl" -ForegroundColor Green

# 6. Print every API base URL the owner can use.
Write-Host ""
Write-Host "=== Sakina local API base URLs (append /v1 for the app) ===" -ForegroundColor Green
Write-Host "  This machine browser : http://localhost:$ApiPort/v1"
Write-Host "  Same machine (alt)   : http://127.0.0.1:$ApiPort/v1"
Write-Host "  Another LAN device   : http://${lan}:$ApiPort/v1   (phone on same Wi-Fi)"
Write-Host "  Android emulator     : http://10.0.2.2:$ApiPort/v1"
Write-Host ""
Write-Host "Flutter web (Chrome):" -ForegroundColor Cyan
Write-Host "  flutter run -d chrome --web-port $WebPort --dart-define=SAKINA_API_BASE_URL=http://localhost:$ApiPort/v1"
Write-Host "APK for LAN phone:" -ForegroundColor Cyan
Write-Host "  flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://${lan}:$ApiPort/v1"
Write-Host ""

# 7. Optionally launch Flutter web in Chrome against the local API.
if ($Web) {
  Push-Location (Join-Path $repo "sakina-frontend")
  Write-Host "Launching Flutter web in Chrome on port $WebPort ..." -ForegroundColor Cyan
  flutter run -d chrome --web-port $WebPort --dart-define="SAKINA_API_BASE_URL=http://localhost:$ApiPort/v1"
  Pop-Location
}
