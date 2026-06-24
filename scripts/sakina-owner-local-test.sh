#!/usr/bin/env bash
# CURSOR PHASE 6I — Linux owner mobile APK test (web diagnostic only)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$REPO/sakina-infra"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.qa.yml"
FRONTEND="$REPO/sakina-frontend"
API_PORT="${API_PORT:-28080}"
BUILD_APK="${BUILD_APK:-0}"
APK_TARGET="${APK_TARGET:-emulator}"

detect_lan_ip() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')"
  fi
  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i !~ /^127\./ && $i !~ /^169\.254\./) {print $i; exit}}')"
  fi
  printf '%s' "$ip"
}

format_apk_cmd() {
  local api_base="$1"
  printf 'cd sakina-frontend && flutter pub get && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=%s --dart-define=SAKINA_LOCAL_TEST=true --dart-define=SAKINA_FEATURE_QURAN=true --dart-define=SAKINA_FEATURE_PRAYER=true --dart-define=SAKINA_FEATURE_KNOWLEDGE=true --dart-define=SAKINA_FEATURE_COMMUNITY=true --dart-define=SAKINA_SUBSCRIPTION_TIER=founding' "$api_base"
}

LAN_IP="$(detect_lan_ip)"
EMULATOR_API="http://10.0.2.2:${API_PORT}/v1"
if [ -n "$LAN_IP" ]; then
  PHONE_API="http://${LAN_IP}:${API_PORT}/v1"
  PHONE_NOTE="Detected LAN IP: ${LAN_IP}"
else
  PHONE_API="http://YOUR_LAN_IP:${API_PORT}/v1"
  PHONE_NOTE="LAN IP not detected — replace YOUR_LAN_IP with: ip route get 1.1.1.1 | awk '{print \$7}'"
fi

API_BASE="http://localhost:${API_PORT}/v1"
APK_PATH="$FRONTEND/build/app/outputs/flutter-apk/app-debug.apk"
INSTALL_CMD="adb install -r ${APK_PATH}"

echo "==> Sakina Phase 6I — THE REAL APP IS THE ANDROID APK"
echo "    Web is diagnostic only."
echo "    ${PHONE_NOTE}"

if [ ! -f "$COMPOSE_DIR/.env" ]; then
  cat >"$COMPOSE_DIR/.env" <<EOF
POSTGRES_PASSWORD=sakina_local_pw
JWT_SECRET=local-dev-jwt-secret-change-me-32chars
ENCRYPTION_KEY=local-dev-encryption-key-change-32
EOF
fi

echo "==> Starting Docker QA stack"
docker compose -f "$COMPOSE_FILE" up -d postgres qdrant redis
sleep 5
echo "==> Running sakina-migrate (local admin seed)"
docker compose -f "$COMPOSE_FILE" run --rm --no-deps -e SAKINA_SEED_LOCAL_ADMIN=true api sakina-migrate || true
docker compose -f "$COMPOSE_FILE" up -d api ollama llm-gateway

echo "==> API health"
curl -sf "http://localhost:${API_PORT}/health" >/dev/null
FEATURES="$(curl -sf "http://localhost:${API_PORT}/v1/features")"
FEATURE_COUNT="$(echo "$FEATURES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo 0)"
echo "PASS: API health 200, features count=${FEATURE_COUNT}"

echo "==> Admin login proof"
ADMIN_JSON="$(curl -sf -X POST "http://localhost:${API_PORT}/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@sakina.local","password":"SakinaLocalOwner2026!"}' || echo '{}')"
ADMIN_TOKEN="$(echo "$ADMIN_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo '')"
if [ -n "$ADMIN_TOKEN" ]; then
  echo "PASS: admin login owner@sakina.local"
  curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" "http://localhost:${API_PORT}/v1/admin/features" >/dev/null
  echo "PASS: admin GET /v1/admin/features"
else
  echo "WARN: admin login failed — check SAKINA_SEED_LOCAL_ADMIN migration"
fi

export PATH="/opt/flutter/bin:${PATH:-}"
if command -v flutter >/dev/null 2>&1; then
  echo "==> flutter analyze && test"
  (cd "$FRONTEND" && flutter pub get && flutter analyze && flutter test)
  echo "PASS: flutter analyze + test"
else
  echo "WARN: flutter not on PATH"
fi

EMULATOR_CMD="$(format_apk_cmd "$EMULATOR_API")"
PHONE_CMD="$(format_apk_cmd "$PHONE_API")"

if [ "$BUILD_APK" = "1" ]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "FAIL: Flutter SDK not found on PATH"
    exit 1
  fi
  if ! flutter doctor -v 2>&1 | grep -q "Android toolchain" || flutter doctor 2>&1 | grep -q "Unable to locate Android SDK"; then
    echo "FAIL: Android SDK not configured. Install Android Studio, SDK Platform, run: flutter doctor --android-licenses"
    exit 1
  fi
  if [ "$APK_TARGET" = "emulator" ] || [ "$APK_TARGET" = "both" ]; then
    echo "==> Building emulator APK"
    eval "$EMULATOR_CMD"
  fi
  if [ "$APK_TARGET" = "phone" ] || [ "$APK_TARGET" = "both" ]; then
    if [ -z "$LAN_IP" ]; then
      echo "FAIL: Cannot build phone APK without LAN IP"
      exit 1
    fi
    echo "==> Building phone APK"
    eval "$(format_apk_cmd "$PHONE_API")"
  fi
  ls -lh "$APK_PATH"
fi

echo ""
echo "LOCAL ADMIN: owner@sakina.local / SakinaLocalOwner2026! (local QA only)"
echo "EMULATOR APK BUILD COMMAND:"
echo "  ${EMULATOR_CMD}"
echo "PHONE APK BUILD COMMAND:"
echo "  ${PHONE_CMD}"
echo "INSTALL COMMAND:"
echo "  ${INSTALL_CMD}"
echo "APK PATH: ${APK_PATH}"
echo "RUNBOOK: docs/sakina-mobile-testing-runbook.md"
