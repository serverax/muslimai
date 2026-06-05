#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'SAKINA_E2E_FAIL: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
DATABASE_URL="${DATABASE_URL:-}"
[[ -n "$DATABASE_URL" ]] || fail "DATABASE_URL is required"

api_base="${BASE_URL%/}"
run_id="$(date +%s)-$RANDOM"

curl -fsS "$api_base/health/ready" | jq . >/tmp/sakina-e2e-ready.json \
  || fail "backend readiness endpoint is not healthy"

register_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg email "$email" --arg password "StrongPassword123!" --arg display_name "E2E User" '{email:$email,password:$password,display_name:$display_name}')"
}

login_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/login" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg email "$email" --arg password "StrongPassword123!" '{email:$email,password:$password}')"
}

user_a_email="e2e-a-$run_id@example.com"
user_b_email="e2e-b-$run_id@example.com"

register_a="$(register_user "$user_a_email")"
register_b="$(register_user "$user_b_email")"
user_a_id="$(printf '%s\n' "$register_a" | jq -r '.user_id // .user.id // empty')"
user_b_id="$(printf '%s\n' "$register_b" | jq -r '.user_id // .user.id // empty')"
[[ -n "$user_a_id" && -n "$user_b_id" ]] || fail "registration did not return user ids"

login_a="$(login_user "$user_a_email")"
login_b="$(login_user "$user_b_email")"
token_a="$(printf '%s\n' "$login_a" | jq -r '.access_token // .token // empty')"
token_b="$(printf '%s\n' "$login_b" | jq -r '.access_token // .token // empty')"
[[ -n "$token_a" && -n "$token_b" ]] || fail "login did not return bearer tokens"
[[ "$token_a" == *.*.* ]] || fail "user A token is not a JWT"
[[ "$token_b" == *.*.* ]] || fail "user B token is not a JWT"

curl -fsS -X PUT "$api_base/v1/profiles/$user_a_id" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_a_id" '{
    user_id:$user_id,
    full_name:"E2E User A",
    display_name:"e2e-user-a",
    timezone:"UTC",
    madhhab_preference:"hanafi",
    metadata:{e2e:true},
    ui_language:"en",
    content_language:"ar",
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
  }')" \
  | jq . >/tmp/sakina-e2e-profile.json

conversation="$(curl -fsS -X POST "$api_base/chat/conversations" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_a_id" '{user_id:$user_id,title:"E2E Islamic question"}')")"
conversation_id="$(printf '%s\n' "$conversation" | jq -r '.id // empty')"
[[ -n "$conversation_id" ]] || fail "conversation was not created"

message="$(curl -fsS -X POST "$api_base/chat/conversations/$conversation_id/messages" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d '{"content":"What is the Islamic guidance for prayer while travelling?"}')"
message_id="$(printf '%s\n' "$message" | jq -r '.user_message_id // empty')"
[[ -n "$message_id" ]] || fail "chat message was not saved"

brain="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -d '{"message":"What is the Islamic guidance for prayer while travelling?","language":"en","user_subscription_tier":"premium"}')"
printf '%s\n' "$brain" | jq -e '.execution_trace // .trace // .decision' >/tmp/sakina-e2e-brain.json \
  || fail "Brain trace response did not include execution data"

memory="$(curl -fsS -X POST "$api_base/api/memory/write" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_id "$user_a_id" '{
    user_id:$user_id,
    memory_key:"e2e.preference",
    memory_type:"preference",
    payload:{preference:"prefers concise answers"},
    source_language:"en",
    consent_required:true,
    consent_granted:true
  }')")"
printf '%s\n' "$memory" | jq . >/tmp/sakina-e2e-memory.json

curl -fsS "$api_base/chat/conversations/$conversation_id" \
  -H "Authorization: Bearer $token_b" >/tmp/sakina-e2e-cross-user.json \
  && fail "user B read user A conversation"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE created_at > now() - interval '10 minutes';" \
  | awk '$1 > 0 { found=1 } END { exit found ? 0 : 1 }' \
  || fail "recent Brain trace was not persisted"

printf 'E2E REAL USER JOURNEY PASS\n'
