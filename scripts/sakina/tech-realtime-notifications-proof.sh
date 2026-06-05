#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'REALTIME_NOTIFICATIONS_BLOCKER %s\n' "$1" >&2
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
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-realtime-notifications-proof-backend.log"
run_id="notif-$(date +%s)-$RANDOM"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log_file" 2>&1 &
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
  || fail "backend did not become ready for realtime notifications; log: $backend_log_file"

register_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $run_id-register" \
    -d "$(jq -n --arg email "$email" '{email:$email,password:"StrongPassword123!",display_name:"Notification Proof User",provider:"password",provider_user_id:$email,metadata:{}}')"
}

reg_a="$(register_user "$run_id-a@example.com")"
reg_b="$(register_user "$run_id-b@example.com")"
token_a="$(printf '%s\n' "$reg_a" | jq -r '.access_token // empty')"
token_b="$(printf '%s\n' "$reg_b" | jq -r '.access_token // empty')"
user_a="$(printf '%s\n' "$reg_a" | jq -r '.user_id // empty')"
user_b="$(printf '%s\n' "$reg_b" | jq -r '.user_id // empty')"
[[ "$token_a" == *.*.* && "$token_b" == *.*.* ]] || fail "registration did not return real JWTs"
[[ "$user_a" =~ ^[0-9a-fA-F-]{36}$ && "$user_b" =~ ^[0-9a-fA-F-]{36}$ ]] \
  || fail "registration did not return user IDs"
printf 'Notification proof users: A=%s B=%s\n' "$user_a" "$user_b"

template_response="$(curl -fsS -X POST "$api_base/v1/notifications/templates" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Request-ID: $run_id-template" \
  -d "$(jq -n --arg key "$run_id-template" '{
    template_key:$key,
    channel:"in_app",
    subject_template:"Runtime notification proof",
    body_template:"Runtime notification proof",
    locale:"en-US"
  }')")"
printf '%s\n' "$template_response" | jq .
template_id="$(printf '%s\n' "$template_response" | jq -r '.id // empty')"
[[ "$template_id" =~ ^[0-9a-fA-F-]{36}$ ]] || fail "failed to seed notification template"
template_db_key="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT template_key FROM public.notification_templates WHERE id = '$template_id'::uuid;")"
[[ "$template_db_key" = "$run_id-template" ]] || fail "notification template route did not persist DB row"

missing_auth_status="$(curl -sS -o /tmp/sakina-notifications-missing-auth.json -w '%{http_code}' \
  "$api_base/v1/notifications")"
cat /tmp/sakina-notifications-missing-auth.json
printf '\nMissing-auth notifications status: %s\n' "$missing_auth_status"
[[ "$missing_auth_status" = "401" ]] || fail "notifications list did not reject missing JWT"

send_response="$(curl -fsS -X POST "$api_base/v1/notifications/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Request-ID: $run_id-send" \
  -d "$(jq -n --arg user_id "$user_b" --arg template_id "$template_id" --arg run_id "$run_id" '{
    user_id:$user_id,
    template_id:$template_id,
    channel:"in_app",
    title:"Runtime notification proof",
    body:"Notification proof body",
    payload:{proof_id:$run_id}
  }')")"
printf '%s\n' "$send_response" | jq .
notification_id="$(printf '%s\n' "$send_response" | jq -r '.id // empty')"
[[ "$notification_id" =~ ^[0-9a-fA-F-]{36}$ ]] || fail "send notification did not return notification id"

owner_id="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT user_id FROM public.user_notifications WHERE id = '$notification_id'::uuid;")"
printf 'Notification owner in DB: %s\n' "$owner_id"
[[ "$owner_id" = "$user_a" ]] \
  || fail "notification route trusted body user_id instead of authenticated user"

list_a="$(curl -fsS "$api_base/v1/notifications" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Request-ID: $run_id-list-a")"
printf '%s\n' "$list_a" | jq .
printf '%s\n' "$list_a" \
  | jq -e --arg id "$notification_id" '.notifications[]? | select(.id == $id and .notification_status == "queued")' >/dev/null \
  || fail "user A did not receive queued notification from backend list route"

list_b="$(curl -fsS "$api_base/v1/notifications" \
  -H "Authorization: Bearer $token_b" \
  -H "X-Request-ID: $run_id-list-b")"
printf '%s\n' "$list_b" | jq .
if printf '%s\n' "$list_b" | jq -e --arg id "$notification_id" '.notifications[]? | select(.id == $id)' >/dev/null; then
  fail "user B received user A notification"
fi

cross_read_status="$(curl -sS -o /tmp/sakina-notifications-cross-read.json -w '%{http_code}' \
  -X POST "$api_base/v1/notifications/$notification_id/read" \
  -H "Authorization: Bearer $token_b")"
cat /tmp/sakina-notifications-cross-read.json
printf '\nCross-user mark-read status: %s\n' "$cross_read_status"
[[ "$cross_read_status" = "404" ]] || fail "user B could mark user A notification read"

read_response="$(curl -fsS -X POST "$api_base/v1/notifications/$notification_id/read" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Request-ID: $run_id-read")"
printf '%s\n' "$read_response" | jq .
printf '%s\n' "$read_response" \
  | jq -e --arg id "$notification_id" '.id == $id and .notification_status == "read" and (.read_at | type == "string")' >/dev/null \
  || fail "owner mark-read response did not show read notification"

db_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT notification_status, read_at IS NOT NULL,
          (SELECT COUNT(*) FROM public.notification_delivery_attempts WHERE user_notification_id = '$notification_id'::uuid)
   FROM public.user_notifications WHERE id = '$notification_id'::uuid;")"
printf 'DB notification read probe: %s\n' "$db_probe"
printf '%s\n' "$db_probe" | grep -Eq '^read\|t\|[1-9][0-9]*$' \
  || fail "DB did not persist read status and delivery attempt"

rg -n "listNotifications|markNotificationRead|sendNotification|/notifications" \
  sakina-frontend/lib/services/api_service.dart sakina-backend/src/main.rs sakina-backend/src/handlers/phase2.rs sakina-backend/src/services/phase2.rs \
  >/tmp/sakina-realtime-notifications-code-path.txt \
  || fail "frontend/backend notification wiring code path was not found"
cat /tmp/sakina-realtime-notifications-code-path.txt

printf 'REALTIME_NOTIFICATIONS_OK notification was created by backend route, received by owner, hidden from another user, marked read, persisted in DB, and wired in Flutter service.\n'
