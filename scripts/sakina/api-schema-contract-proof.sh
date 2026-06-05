#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'API_SCHEMA_CONTRACT_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
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
backend_log_file="${TMPDIR:-/tmp}/sakina-api-schema-contract-backend.log"

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

rg -n "PasswordAuthResponse|UserSummaryResponse|ProfileResponse|CreateConversationResponse|AddMessageResponse|MemoryWriteResponse|MemoryEntryResponse|traceId|assistantMessageId" \
  sakina-frontend/lib/services/api_service.dart >/tmp/sakina-api-schema-frontend-models.txt \
  || fail "frontend response models for required contracts are missing"
cat /tmp/sakina-api-schema-frontend-models.txt

rg -n "RegisterUserResponse|LoginResponse|UpsertProfileRequest|CreateConversationResponse|AddMessageResponse|MemoryWriteOutcome|MemoryEntry" \
  sakina-backend/src >/tmp/sakina-api-schema-backend-models.txt \
  || fail "backend response models for required contracts are missing"
cat /tmp/sakina-api-schema-backend-models.txt

email="schema-contract-$run_id@example.com"
password="StrongPassword123!"

register_response="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email" --arg password "$password" '{email:$email,password:$password,display_name:"Schema Contract User"}')")"
printf '%s\n' "$register_response" | jq .
printf '%s\n' "$register_response" | jq -e '.user_id and .email and .access_token and .refresh_token' >/dev/null \
  || fail "register schema missing user_id/email/access_token/refresh_token"

user_id="$(printf '%s\n' "$register_response" | jq -r '.user_id')"
token="$(printf '%s\n' "$register_response" | jq -r '.access_token')"

me_response="$(curl -fsS "$api_base/auth/me" -H "Authorization: Bearer $token")"
printf '%s\n' "$me_response" | jq .
printf '%s\n' "$me_response" | jq -e --arg user_id "$user_id" --arg email "$email" '.user_id == $user_id and .email == $email and .auth_provider' >/dev/null \
  || fail "auth/me schema does not match frontend UserSummaryResponse"

profile_response="$(curl -fsS -X PUT "$api_base/v1/profiles/$user_id" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_id" '{
    user_id:$user_id,
    display_name:"schema-contract-user",
    timezone:"UTC",
    metadata:{contract:"api-schema"},
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
printf '%s\n' "$profile_response" | jq -e --arg user_id "$user_id" '.profile_id and .user_id == $user_id' >/dev/null \
  || fail "profile schema missing profile_id/user_id"

conversation_response="$(curl -fsS -X POST "$api_base/chat/conversations" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_id" '{user_id:$user_id,title:"Schema contract chat"}')")"
printf '%s\n' "$conversation_response" | jq .
conversation_id="$(printf '%s\n' "$conversation_response" | jq -r '.id')"
printf '%s\n' "$conversation_response" | jq -e '.id and .title and .created_at and .updated_at' >/dev/null \
  || fail "conversation schema missing id/title/timestamps"

message_response="$(curl -fsS -X POST "$api_base/chat/conversations/$conversation_id/messages" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d '{"content":"What is the Islamic guidance for patience?"}')"
printf '%s\n' "$message_response" | jq .
printf '%s\n' "$message_response" | jq -e --arg cid "$conversation_id" '.conversation_id == $cid and .user_message_id and .assistant_message_id and .response and .trace_id' >/dev/null \
  || fail "message schema missing conversation/user/assistant/response/trace fields"

memory_key="schema.contract.$run_id"
memory_response="$(curl -fsS -X POST "$api_base/api/memory/write" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_id" --arg key "$memory_key" '{
    user_id:$user_id,
    memory_key:$key,
    memory_type:"preference",
    payload:{preference:"schema contract proof"},
    source_language:"en",
    consent_required:true,
    consent_granted:true
  }')")"
printf '%s\n' "$memory_response" | jq .
printf '%s\n' "$memory_response" | jq -e '.stored == true and .allowed == true and .memory_id and .sensitivity_level and .reason' >/dev/null \
  || fail "memory write schema missing stored/allowed/memory_id/sensitivity/reason"

memory_read="$(curl -fsS "$api_base/api/memory/read?user_id=$user_id&memory_key=$memory_key" \
  -H "Authorization: Bearer $token")"
printf '%s\n' "$memory_read" | jq .
printf '%s\n' "$memory_read" | jq -e --arg key "$memory_key" '.id and .user_id and .memory_key == $key and .payload and .allowed == true' >/dev/null \
  || fail "memory read schema missing id/user_id/memory_key/payload/allowed"

missing_auth_status="$(curl -sS -o /tmp/sakina-api-schema-missing-auth.json -w "%{http_code}" "$api_base/chat/conversations/$conversation_id")"
printf 'Missing auth conversation status=%s\n' "$missing_auth_status"
[[ "$missing_auth_status" == "401" ]] || fail "protected endpoint did not return 401 for missing auth"

not_found_status="$(curl -sS -o /tmp/sakina-api-schema-not-found.json -w "%{http_code}" \
  "$api_base/chat/conversations/00000000-0000-4000-8000-000000000000" \
  -H "Authorization: Bearer $token")"
printf 'Missing conversation status=%s\n' "$not_found_status"
[[ "$not_found_status" == "404" ]] || fail "missing conversation did not return 404"

printf 'API_SCHEMA_CONTRACT_OK real backend responses match frontend models for auth, profile, chat, memory, trace, and negative HTTP contracts.\n'
