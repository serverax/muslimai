#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'OWASP_MASVS_MOBILE_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

[[ -d sakina-frontend/lib ]] || fail "Flutter lib directory is missing"
[[ -d sakina-frontend/android ]] || fail "Android project directory is missing"
[[ -d sakina-frontend/ios ]] || fail "iOS project directory is missing; MASVS/iOS release security cannot be proven"

rg -n "flutter_secure_storage|FlutterSecureStorage|Authorization: Bearer|setAuthToken|delete\\(key: _tokenKey\\)" sakina-frontend/lib \
  || fail "secure token storage and centralized bearer auth wiring are not proven"

if rg -n -i "SAKINA_API_TOKEN|demo-token|test-token|password123|localhost|127\\.0\\.0\\.1|10\\.0\\.2\\.2|dummy|placeholder|fake" sakina-frontend/lib sakina-frontend/android sakina-frontend/ios \
  | grep -v "placeholderIdentifier"; then
  fail "mobile production paths contain blocked static token/local/demo/fake markers"
fi

rg -n "uses-permission|android.permission.CAMERA|NSCameraUsageDescription|NSMicrophoneUsageDescription" sakina-frontend/android sakina-frontend/ios \
  || fail "release permissions are not declared/reviewable"

if command -v flutter >/dev/null 2>&1; then
  (cd sakina-frontend && flutter analyze && flutter test && flutter build apk --debug)
elif [[ -f /mnt/c/src/flutter/bin/flutter.bat ]] && command -v cmd.exe >/dev/null 2>&1; then
  cmd.exe /C "cd /D F:\\SakinaAL\\sakina-frontend && C:\\src\\flutter\\bin\\flutter.bat analyze && C:\\src\\flutter\\bin\\flutter.bat test && C:\\src\\flutter\\bin\\flutter.bat build apk --debug"
else
  fail "Flutter CLI is missing; MASVS mobile build proof cannot run"
fi

[[ -f sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk ]] \
  || fail "debug APK artifact is missing after build"

printf 'OWASP_MASVS_MOBILE_OK secure storage, permission declarations, static-token scan, and Flutter build proof completed.\n'
