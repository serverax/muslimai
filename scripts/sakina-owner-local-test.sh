#!/usr/bin/env bash
# CURSOR PHASE 6G — Linux owner local test (APK-first; web diagnostic optional)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$REPO/sakina-infra"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.qa.yml"
FRONTEND="$REPO/sakina-frontend"
API_PORT="${API_PORT:-28080}"
WEB_PORT="${WEB_PORT:-8090}"
BUILD_APK="${BUILD_APK:-0}"
SKIP_WEB="${SKIP_WEB:-0}"

LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
LAN_IP="${LAN_IP:-127.0.0.1}"
API_BASE="http://localhost:${API_PORT}/v1"
EMULATOR_API="http://10.0.2.2:${API_PORT}/v1"
LAN_API="http://${LAN_IP}:${API_PORT}/v1"
APK_PATH="$FRONTEND/build/app/outputs/flutter-apk/app-debug.apk"

APK_DEFINES=(
  "--dart-define=SAKINA_API_BASE_URL=${LAN_API}"
  "--dart-define=SAKINA_LOCAL_TEST=true"
  "--dart-define=SAKINA_FEATURE_QURAN=true"
  "--dart-define=SAKINA_FEATURE_PRAYER=true"
  "--dart-define=SAKINA_FEATURE_KNOWLEDGE=true"
  "--dart-define=SAKINA_FEATURE_COMMUNITY=true"
  "--dart-define=SAKINA_SUBSCRIPTION_TIER=founding"
)

echo "==> Sakina Phase 6G — THE REAL APP IS THE ANDROID APK"
echo "    Web :${WEB_PORT} is diagnostic only."

if [ ! -f "$COMPOSE_DIR/.env" ]; then
  cat >"$COMPOSE_DIR/.env" <<EOF
POSTGRES_PASSWORD=sakina_local_pw
JWT_SECRET=local-dev-jwt-secret-change-me-32chars
ENCRYPTION_KEY=local-dev-encryption-key-change-32
EOF
fi

echo "==> Starting Docker QA stack"
docker compose -f "$COMPOSE_FILE" up -d --build

echo "==> API health"
curl -sf "http://localhost:${API_PORT}/health" >/dev/null
echo "PASS: API health 200"

export PATH="/opt/flutter/bin:${PATH:-}"
if command -v flutter >/dev/null 2>&1; then
  echo "==> flutter analyze"
  (cd "$FRONTEND" && flutter pub get && flutter analyze)
  echo "PASS: flutter analyze"
else
  echo "WARN: flutter not on PATH"
fi

if [ "$BUILD_APK" = "1" ]; then
  echo "==> Building debug APK for LAN $LAN_API"
  (cd "$FRONTEND" && flutter build apk --debug "${APK_DEFINES[@]}")
  ls -lh "$APK_PATH"
fi

echo ""
echo "OWNER BACKEND: cd sakina-infra && docker compose -f docker-compose.qa.yml up -d"
echo "EMULATOR APK:  cd sakina-frontend && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=${EMULATOR_API} ..."
echo "PHONE APK:     cd sakina-frontend && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=${LAN_API} ..."
echo "APK PATH:      $APK_PATH"
echo "RUNBOOK:       docs/sakina-mobile-testing-runbook.md"
