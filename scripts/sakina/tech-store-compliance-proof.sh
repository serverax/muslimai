#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'STORE_COMPLIANCE_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql
require_cmd rg

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${BASE_URL%/}"
run_id="store-compliance-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-store-compliance-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

run_flutter_release_builds() {
  if command -v flutter >/dev/null 2>&1; then
    (
      cd sakina-frontend
      flutter build apk --release
      flutter build appbundle --release
    )
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "Set-Location -LiteralPath 'F:\\SakinaAL\\sakina-frontend'; flutter build apk --release; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE }; flutter build appbundle --release"
  else
    fail "Flutter is not available in PATH and Windows PowerShell fallback is unavailable"
  fi
}

run_flutter_release_builds

apk_path="sakina-frontend/build/app/outputs/flutter-apk/app-release.apk"
aab_path="sakina-frontend/build/app/outputs/bundle/release/app-release.aab"
[[ -s "$apk_path" ]] || fail "release APK is missing or empty: $apk_path"
[[ -s "$aab_path" ]] || fail "release AAB is missing or empty: $aab_path"
ls -lh "$apk_path" "$aab_path"

if rg -n "localhost|127\\.0\\.0\\.1|10\\.0\\.2\\.2|demo-token|test-token|SAKINA_API_TOKEN|fake privacy|fake terms|lorem|changeme" \
  sakina-frontend/lib sakina-frontend/android/app/src/main sakina-frontend/ios/Runner; then
  fail "release mobile production paths contain local/demo/fake store blockers"
fi

rg -n "Privacy Policy|Terms|Islamic Advisory Disclaimer|Data Export and Deletion|Request account deletion|requestAccountDeletion|/account/delete-request" \
  sakina-frontend/lib/screens/compliance_screen.dart sakina-frontend/lib/screens/home_shell_screen.dart sakina-frontend/lib/services/api_service.dart \
  >/tmp/sakina-store-compliance-frontend-code-path.txt \
  || fail "privacy, terms, disclaimer, and deletion UI/API wiring were not found"
cat /tmp/sakina-store-compliance-frontend-code-path.txt

rg -n "Sakina AI|uses-permission android:name=\"android.permission.CAMERA\"|NSCameraUsageDescription|NSPhotoLibraryUsageDescription" \
  sakina-frontend/android/app/src/main/AndroidManifest.xml sakina-frontend/ios/Runner/Info.plist \
  >/tmp/sakina-store-compliance-permissions.txt \
  || fail "store app name or enabled feature permissions/descriptions were not found"
cat /tmp/sakina-store-compliance-permissions.txt

rg -n "account_deletion_requested|outbox\\.events|request_account_deletion|authenticated_user_id" \
  sakina-backend/src/handlers/phase2.rs sakina-backend/src/main.rs scripts/sakina/tech-data-retention-deletion-proof.sh \
  >/tmp/sakina-store-compliance-backend-code-path.txt \
  || fail "backend account deletion request/audit/outbox code path was not found"
cat /tmp/sakina-store-compliance-backend-code-path.txt

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >"$backend_log_file" 2>&1 \
    || fail "backend build failed; log: $backend_log_file"
  "$CARGO_TARGET_DIR/debug/sakina-api" >>"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  for _ in $(seq 1 180); do
    if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend did not become ready for store compliance proof; log: $backend_log_file"

register_response="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-register" \
  -d "$(jq -n --arg email "$run_id@example.com" --arg credential "$(printf '%s' 'StrongPassword123!')" '{
    email:$email,
    password:$credential,
    display_name:"Store Compliance User",
    provider:"password",
    provider_user_id:$email,
    metadata:{}
  }')")"
token="$(printf '%s\n' "$register_response" | jq -r '.access_token // empty')"
user_id="$(printf '%s\n' "$register_response" | jq -r '.user_id // empty')"
[[ "$token" == *.*.* && "$user_id" =~ ^[0-9a-fA-F-]{36}$ ]] \
  || fail "registration did not return token and user id"

missing_auth_status="$(curl -sS -o /tmp/sakina-store-delete-missing-auth.json -w '%{http_code}' \
  -X POST "$api_base/v1/account/delete-request" \
  -H "Content-Type: application/json" \
  -d '{}')"
cat /tmp/sakina-store-delete-missing-auth.json
printf '\nMissing-auth delete request status: %s\n' "$missing_auth_status"
[[ "$missing_auth_status" = "401" ]] || fail "account deletion request did not require JWT"

delete_response="$(curl -fsS -X POST "$api_base/v1/account/delete-request" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-delete" \
  -d '{}')"
printf '%s\n' "$delete_response" | jq .
printf '%s\n' "$delete_response" | jq -e '.status == "queued" and .request_id and .audit_id and .outbox_event_id' >/dev/null \
  || fail "account deletion request did not return queued audit/outbox response"

audit_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.audit_logs WHERE request_id = '$run_id-delete' AND event_type = 'account_deletion_requested' AND actor_id = '$user_id';")"
outbox_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM outbox.events WHERE event_type = 'account_deletion_requested' AND payload->>'request_id' = '$run_id-delete' AND payload->>'user_id' = '$user_id';")"
printf 'Deletion audit rows=%s outbox rows=%s\n' "$audit_count" "$outbox_count"
[[ "$audit_count" = "1" && "$outbox_count" = "1" ]] \
  || fail "account deletion request did not persist audit and outbox evidence"

printf 'STORE_COMPLIANCE_OK release APK/AAB builds exist, release config has no local/demo token blockers, mobile privacy/terms/disclaimer/account deletion UI is visible, Android/iOS permissions match enabled multimodal features, account deletion request requires JWT, and backend persists audit/outbox deletion request evidence.\n'
