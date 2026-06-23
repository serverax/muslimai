#!/usr/bin/env bash
# PHASE 6B - Sakina local web/LAN testing launcher (Git Bash / Bash).
# Brings up the local Docker QA stack with a safe local CORS allowlist (incl. this
# machine's LAN IP), waits for API health, and prints every API base URL the owner
# can test from. Not public deployment. Local beta testing only. Never LIVE_READY.
#
# Usage:
#   ./scripts/sakina-local-web.sh            # start stack + print URLs
#   ./scripts/sakina-local-web.sh --web      # also run Flutter web in Chrome
set -euo pipefail

API_PORT="${API_PORT:-28080}"
WEB_PORT="${WEB_PORT:-8090}"
RUN_WEB="no"
[ "${1:-}" = "--web" ] && RUN_WEB="yes"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE="$REPO/sakina-infra/docker-compose.qa.yml"

# 1. Detect LAN IP (prefer 192.168.x, then 10.x; skip WSL/virtual 172.x).
LAN="$(powershell.exe -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {\$_.IPAddress -notlike '127.*' -and \$_.IPAddress -notlike '169.*' -and \$_.InterfaceAlias -notmatch 'WSL|vEthernet|Loopback'} | Sort-Object {if(\$_.IPAddress -like '192.168.*'){0}elseif(\$_.IPAddress -like '10.*'){1}else{2}} | Select-Object -First 1 -ExpandProperty IPAddress)" 2>/dev/null | tr -d '\r')"
[ -z "$LAN" ] && LAN="127.0.0.1"
echo "LAN IP detected: $LAN"

# 2. Safe explicit CORS allowlist (NO wildcard): localhost + LAN web origins.
export CORS_ALLOWED_ORIGINS="http://localhost:$WEB_PORT,http://127.0.0.1:$WEB_PORT,http://$LAN:$WEB_PORT,http://localhost:8091,http://127.0.0.1:8091,http://$LAN:8091"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-sakina_local_pw}"
export JWT_SECRET="${JWT_SECRET:-local-dev-jwt-secret-change-me}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-local-dev-encryption-key-change}"

# 3. Start / refresh the stack so the CORS env takes effect on the api container.
echo "Starting Docker QA stack ..."
docker compose -f "$COMPOSE" up -d
docker compose -f "$COMPOSE" up -d --force-recreate api

# 4. Wait for API health (bounded).
for i in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://localhost:$API_PORT/health" || true)"
  [ "$code" = "200" ] && break
  sleep 2
done
[ "${code:-}" = "200" ] || { echo "API health FAILED on :$API_PORT"; exit 1; }
echo "API health OK: http://localhost:$API_PORT/health"

# 5. Print every API base URL (append /v1 for the app).
cat <<EOF

=== Sakina local API base URLs (append /v1 for the app) ===
  This machine browser : http://localhost:$API_PORT/v1
  Same machine (alt)   : http://127.0.0.1:$API_PORT/v1
  Another LAN device   : http://$LAN:$API_PORT/v1   (phone on same Wi-Fi)
  Android emulator     : http://10.0.2.2:$API_PORT/v1

Flutter web (Chrome):
  flutter run -d chrome --web-port $WEB_PORT --dart-define=SAKINA_API_BASE_URL=http://localhost:$API_PORT/v1
APK for LAN phone:
  flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://$LAN:$API_PORT/v1
EOF

# 6. Optionally run Flutter web in Chrome.
if [ "$RUN_WEB" = "yes" ]; then
  cd "$REPO/sakina-frontend"
  flutter run -d chrome --web-port "$WEB_PORT" --dart-define="SAKINA_API_BASE_URL=http://localhost:$API_PORT/v1"
fi
