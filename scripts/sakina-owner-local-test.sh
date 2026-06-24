#!/usr/bin/env bash
# CURSOR PHASE 6H — Linux owner local test (APK-first; web diagnostic optional)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$REPO/sakina-infra"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.qa.yml"
FRONTEND="$REPO/sakina-frontend"
API_PORT="${API_PORT:-28080}"
WEB_PORT="${WEB_PORT:-8090}"
BUILD_APK="${BUILD_APK:-0}"
SKIP_WEB="${SKIP_WEB:-0}"

detect_lan_ip() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')"
  fi
  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./ && $i !~ /^169\.254\./) {print $i; exit}}')"
  fi
  if [ -z "$ip" ]; then
    ip="YOUR_LAN_IP"
  fi
  printf '%s' "$ip"
}

LAN_IP="$(detect_lan_ip)"
if [ "$LAN_IP" = "YOUR_LAN_IP" ]; then
  LAN_API="http://YOUR_LAN_IP:${API_PORT}/v1  # replace YOUR_LAN_IP with your machine IP (ip route get 1.1.1.1)"
  PHONE_NOTE="Could not detect LAN IP. Run: ip route get 1.1.1.1 | awk '{print \$7}'"
else
  LAN_API="http://${LAN_IP}:${API_PORT}/v1"
  PHONE_NOTE="Detected LAN IP: ${LAN_IP}"
fi

API_BASE="http://localhost:${API_PORT}/v1"
EMULATOR_API="http://10.0.2.2:${API_PORT}/v1"
APK_PATH="$FRONTEND/build/app/outputs/flutter-apk/app-debug.apk"

APK_DEFINES=(
  "--dart-define=SAKINA_API_BASE_URL=${EMULATOR_API}"
  "--dart-define=SAKINA_LOCAL_TEST=true"
  "--dart-define=SAKINA_FEATURE_QURAN=true"
  "--dart-define=SAKINA_FEATURE_PRAYER=true"
  "--dart-define=SAKINA_FEATURE_KNOWLEDGE=true"
  "--dart-define=SAKINA_FEATURE_COMMUNITY=true"
  "--dart-define=SAKINA_SUBSCRIPTION_TIER=founding"
)

echo "==> Sakina Phase 6H — THE REAL APP IS THE ANDROID APK"
echo "    Web :${WEB_PORT} is diagnostic only."
echo "    $PHONE_NOTE"

if [ ! -f "$COMPOSE_DIR/.env" ]; then
  cat >"$COMPOSE_DIR/.env" <<EOF
POSTGRES_PASSWORD=sakina_local_pw
JWT_SECRET=local-dev-jwt-secret-change-me-32chars
ENCRYPTION_KEY=local-dev-encryption-key-change-32
EOF
fi

echo "==> Starting Docker QA stack"
docker compose -f "$COMPOSE_FILE" up -d --build postgres qdrant redis
sleep 3
docker compose -f "$COMPOSE_FILE" run --rm --no-deps api sakina-migrate || true
docker compose -f "$COMPOSE_FILE" up -d --build api

echo "==> API health"
curl -sf "http://localhost:${API_PORT}/health" >/dev/null
curl -sf "http://localhost:${API_PORT}/v1/features" >/dev/null || echo "WARN: /v1/features not ready yet"
echo "PASS: API health 200"

export PATH="/opt/flutter/bin:${PATH:-}"
if command -v flutter >/dev/null 2>&1; then
  echo "==> flutter analyze"
  (cd "$FRONTEND" && flutter pub get && flutter analyze)
  echo "==> flutter test"
  (cd "$FRONTEND" && flutter test)
  echo "PASS: flutter analyze + test"
else
  echo "WARN: flutter not on PATH"
fi

if [ "$BUILD_APK" = "1" ]; then
  if [ "$LAN_IP" = "YOUR_LAN_IP" ]; then
    echo "FAIL: Cannot build phone APK without LAN IP. Set manually in dart-define."
    exit 1
  fi
  PHONE_DEFINES=(
    "--dart-define=SAKINA_API_BASE_URL=${LAN_API%% *}"
    "--dart-define=SAKINA_LOCAL_TEST=true"
    "--dart-define=SAKINA_FEATURE_QURAN=true"
    "--dart-define=SAKINA_FEATURE_PRAYER=true"
    "--dart-define=SAKINA_FEATURE_KNOWLEDGE=true"
    "--dart-define=SAKINA_FEATURE_COMMUNITY=true"
    "--dart-define=SAKINA_SUBSCRIPTION_TIER=founding"
  )
  echo "==> Building debug APK for LAN ${LAN_API%% *}"
  (cd "$FRONTEND" && flutter build apk --debug "${PHONE_DEFINES[@]}")
  ls -lh "$APK_PATH"
fi

echo ""
echo "OWNER BACKEND: cd sakina-infra && docker compose -f docker-compose.qa.yml up -d"
echo "MIGRATE:       docker compose -f docker-compose.qa.yml run --rm api sakina-migrate"
echo "EMULATOR APK:  cd sakina-frontend && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=${EMULATOR_API} ..."
echo "PHONE APK:     cd sakina-frontend && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=${LAN_API%% *} ..."
echo "INSTALL:       adb install -r $APK_PATH"
echo "APK PATH:      $APK_PATH"
echo "RUNBOOK:       docs/sakina-mobile-testing-runbook.md"
echo ""
echo "TEST JOURNEYS: Guest home · Login · Ask AI · Quran · Prayer · Admin feature gates"
