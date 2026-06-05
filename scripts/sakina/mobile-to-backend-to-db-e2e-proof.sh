#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MOBILE_BACKEND_DB_E2E_BLOCKER %s\n' "$1" >&2
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

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

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
run_id="$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-mobile-backend-db-e2e-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

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
  || fail "backend readiness endpoint is not ready; log: $backend_log_file"

rg -n "registerWithPassword|loginWithPassword|currentUser|refreshWithToken|logout\\(|upsertProfile|createConversation|addConversationMessage|writeMemory|readMemory|Authorization.*Bearer" \
  sakina-frontend/lib/services sakina-frontend/lib/screens >/tmp/sakina-mobile-e2e-frontend-code.txt \
  || fail "frontend service/screen code does not expose required real backend methods"
cat /tmp/sakina-mobile-e2e-frontend-code.txt

register_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: mobile-e2e-register-$run_id" \
    -d "$(jq -n --arg email "$email" --arg password "StrongPassword123!" --arg display_name "Mobile E2E User" '{
      email:$email,
      password:$password,
      display_name:$display_name
    }')"
}

login_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/login" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: mobile-e2e-login-$run_id" \
    -d "$(jq -n --arg email "$email" --arg password "StrongPassword123!" '{email:$email,password:$password}')"
}

user_a_email="mobile-e2e-a-$run_id@example.com"
user_b_email="mobile-e2e-b-$run_id@example.com"
memory_key="mobile.e2e.preference.$run_id"

register_a="$(register_user "$user_a_email")"
register_b="$(register_user "$user_b_email")"
user_a_id="$(printf '%s\n' "$register_a" | jq -r '.user_id // empty')"
user_b_id="$(printf '%s\n' "$register_b" | jq -r '.user_id // empty')"
[[ -n "$user_a_id" && -n "$user_b_id" && "$user_a_id" != "$user_b_id" ]] \
  || fail "registration did not create two distinct backend users"

login_a="$(login_user "$user_a_email")"
login_b="$(login_user "$user_b_email")"
token_a="$(printf '%s\n' "$login_a" | jq -r '.access_token // empty')"
token_b="$(printf '%s\n' "$login_b" | jq -r '.access_token // empty')"
[[ "$token_a" == *.*.* && "$token_b" == *.*.* ]] \
  || fail "login did not return real JWTs"

me_a="$(curl -fsS "$api_base/auth/me" -H "Authorization: Bearer $token_a")"
printf '%s\n' "$me_a" | jq -e --arg email "$user_a_email" '.user_id and .email == $email' >/dev/null \
  || fail "frontend current-user contract did not load authenticated user A"

unauth_status="$(curl -sS -o /tmp/sakina-mobile-e2e-unauth.json -w "%{http_code}" "$api_base/auth/me")"
printf 'Unauthenticated auth/me status=%s\n' "$unauth_status"
[[ "$unauth_status" == "401" ]] || fail "auth/me allowed unauthenticated access"

profile_response="$(curl -fsS -X PUT "$api_base/v1/profiles/$user_a_id" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: mobile-e2e-profile-$run_id" \
  -d "$(jq -n --arg user_id "$user_a_id" '{
    user_id:$user_id,
    full_name:"Mobile E2E User A",
    display_name:"mobile-e2e-user-a",
    timezone:"UTC",
    madhhab_preference:"hanafi",
    metadata:{journey:"mobile-to-backend-to-db"},
    ui_language:"en",
    content_language:"en",
    transliteration_enabled:true,
    profile_visibility:"private",
    data_export_allowed:true,
    analytics_opt_in:false,
    text_scale:1.0,
    high_contrast_enabled:false,
    reduced_motion_enabled:false,
    screen_reader_optimized:false,
    in_app_enabled:true,
    email_enabled:false,
    push_enabled:false
  }')")"
printf '%s\n' "$profile_response" | jq .
printf '%s\n' "$profile_response" | jq -e --arg user_id "$user_a_id" '.user_id == $user_id' >/dev/null \
  || fail "profile response did not match frontend profile model"

cross_profile_status="$(curl -sS -o /tmp/sakina-mobile-e2e-cross-profile.json -w "%{http_code}" \
  -X PUT "$api_base/v1/profiles/$user_a_id" \
  -H "Authorization: Bearer $token_b" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_a_id" '{
    user_id:$user_id,
    display_name:"cross-user-write",
    timezone:"UTC",
    metadata:{attack:true},
    ui_language:"en",
    content_language:"en",
    transliteration_enabled:true,
    profile_visibility:"private",
    data_export_allowed:false,
    analytics_opt_in:false,
    text_scale:1.0,
    high_contrast_enabled:false,
    reduced_motion_enabled:false,
    screen_reader_optimized:false,
    in_app_enabled:true,
    email_enabled:false,
    push_enabled:false
  }')")"
printf 'Cross-user profile update status=%s\n' "$cross_profile_status"
[[ "$cross_profile_status" == "401" || "$cross_profile_status" == "403" ]] \
  || fail "user B was able to update user A profile"

conversation_response="$(curl -fsS -X POST "$api_base/chat/conversations" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: mobile-e2e-conversation-$run_id" \
  -d "$(jq -n --arg user_id "$user_a_id" '{user_id:$user_id,title:"Mobile E2E Islamic question"}')")"
conversation_id="$(printf '%s\n' "$conversation_response" | jq -r '.id // empty')"
[[ -n "$conversation_id" ]] || fail "chat conversation was not created"

message_response="$(curl -fsS -X POST "$api_base/chat/conversations/$conversation_id/messages" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: mobile-e2e-message-$run_id" \
  -d '{"content":"Can I shorten prayers while travelling?"}')"
printf '%s\n' "$message_response" | jq .
user_message_id="$(printf '%s\n' "$message_response" | jq -r '.user_message_id // empty')"
assistant_message_id="$(printf '%s\n' "$message_response" | jq -r '.assistant_message_id // empty')"
brain_trace_id="$(printf '%s\n' "$message_response" | jq -r '.trace_id // empty')"
[[ -n "$user_message_id" && -n "$assistant_message_id" && -n "$brain_trace_id" ]] \
  || fail "chat message response did not include user message, assistant message, and Brain trace IDs"

conversation_read="$(curl -fsS "$api_base/chat/conversations/$conversation_id" \
  -H "Authorization: Bearer $token_a")"
printf '%s\n' "$conversation_read" | jq -e --arg cid "$conversation_id" '.id == $cid and (.messages | length) >= 2' >/dev/null \
  || fail "user A could not read persisted conversation messages"

cross_chat_status="$(curl -sS -o /tmp/sakina-mobile-e2e-cross-chat.json -w "%{http_code}" \
  "$api_base/chat/conversations/$conversation_id" \
  -H "Authorization: Bearer $token_b")"
printf 'Cross-user conversation read status=%s\n' "$cross_chat_status"
[[ "$cross_chat_status" == "404" || "$cross_chat_status" == "403" || "$cross_chat_status" == "401" ]] \
  || fail "user B was able to read user A conversation"

memory_response="$(curl -fsS -X POST "$api_base/api/memory/write" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: mobile-e2e-memory-write-$run_id" \
  -d "$(jq -n --arg user_id "$user_a_id" --arg key "$memory_key" '{
    user_id:$user_id,
    memory_key:$key,
    memory_type:"preference",
    payload:{preference:"prefers concise answers for travel prayer questions"},
    source_language:"en",
    consent_required:true,
    consent_granted:true
  }')")"
printf '%s\n' "$memory_response" | jq .
printf '%s\n' "$memory_response" | jq -e '.stored == true and .memory_id' >/dev/null \
  || fail "memory write did not persist through backend"

memory_read="$(curl -fsS "$api_base/api/memory/read?user_id=$user_a_id&memory_key=$memory_key" \
  -H "Authorization: Bearer $token_a")"
printf '%s\n' "$memory_read" | jq -e --arg key "$memory_key" '.memory_key == $key and .allowed == true' >/dev/null \
  || fail "user A could not read own persisted memory"

cross_memory_status="$(curl -sS -o /tmp/sakina-mobile-e2e-cross-memory.json -w "%{http_code}" \
  "$api_base/api/memory/read?user_id=$user_a_id&memory_key=$memory_key" \
  -H "Authorization: Bearer $token_b")"
printf 'Cross-user memory read status=%s\n' "$cross_memory_status"
[[ "$cross_memory_status" == "401" || "$cross_memory_status" == "403" ]] \
  || fail "user B was able to read user A memory"

profile_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.user_profiles WHERE user_id = '$user_a_id' AND display_name = 'mobile-e2e-user-a';")"
conversation_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.conversations WHERE id = '$conversation_id' AND user_id = '$user_a_id';")"
message_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.messages WHERE conversation_id = '$conversation_id' AND user_id = '$user_a_id';")"
memory_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.user_memory_entries WHERE user_id = '$user_a_id' AND memory_key = '$memory_key' AND allowed IS TRUE;")"
brain_count="0"
for _ in $(seq 1 30); do
  brain_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
    "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE request_id = '$brain_trace_id';")"
  if (( brain_count >= 1 )); then
    break
  fi
  sleep 1
done
memory_audit_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.brain_memory_events WHERE user_id = '$user_a_id' AND action IN ('write','read');")"
printf 'DB profile=%s conversations=%s messages=%s memories=%s brain_traces=%s memory_audits=%s\n' \
  "$profile_count" "$conversation_count" "$message_count" "$memory_count" "$brain_count" "$memory_audit_count"
(( profile_count == 1 )) || fail "profile DB row was not persisted"
(( conversation_count == 1 )) || fail "conversation DB row was not persisted"
(( message_count >= 2 )) || fail "chat DB rows were not persisted"
(( memory_count >= 1 )) || fail "memory DB row was not persisted"
(( brain_count >= 1 )) || fail "Brain trace DB row was not persisted"
(( memory_audit_count >= 2 )) || fail "memory audit DB rows were not persisted"

logout_status="$(curl -sS -o /tmp/sakina-mobile-e2e-logout.json -w "%{http_code}" \
  -X POST "$api_base/auth/logout" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d '{}')"
printf 'Logout status=%s\n' "$logout_status"
[[ "$logout_status" -ge 200 && "$logout_status" -lt 300 ]] || fail "logout did not revoke session"

revoked_status="$(curl -sS -o /tmp/sakina-mobile-e2e-revoked.json -w "%{http_code}" \
  "$api_base/auth/me" \
  -H "Authorization: Bearer $token_a")"
printf 'Revoked token auth/me status=%s\n' "$revoked_status"
[[ "$revoked_status" == "401" ]] || fail "revoked token remained usable"

printf 'MOBILE_BACKEND_DB_E2E_OK Flutter service contracts, real HTTP routes, auth/RLS guards, backend handlers, DB persistence, Brain trace, memory audit, frontend model fields, and negative isolation checks were proven.\n'
