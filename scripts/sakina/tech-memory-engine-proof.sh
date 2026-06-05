#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MEMORY_ENGINE_BLOCKER %s\n' "$1" >&2
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
log_file="${TMPDIR:-/tmp}/sakina-memory-engine-proof.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  set -e
}
trap cleanup EXIT

wait_ready() {
  for _ in $(seq 1 180); do
    if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$log_file"
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_ready || fail "backend did not become ready; log: $log_file"
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend readiness did not report ready"

suffix="$(date +%s)-$RANDOM"
credential="StrongPassword123!"
email_a="sakina-memory-a-$suffix@example.com"
email_b="sakina-memory-b-$suffix@example.com"
memory_key="quran-memory-$suffix"

register_a="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email_a" --arg credential "$credential" '{email:$email,password:$credential,display_name:"Memory User A"}')")"
printf '%s\n' "$register_a" | jq '{user_id,email,has_access_token:(.access_token != null)}'
access_jwt_a="$(printf '%s\n' "$register_a" | jq -r '.access_token')"
user_a="$(printf '%s\n' "$register_a" | jq -r '.user_id')"

register_b="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email_b" --arg credential "$credential" '{email:$email,password:$credential,display_name:"Memory User B"}')")"
printf '%s\n' "$register_b" | jq '{user_id,email,has_access_token:(.access_token != null)}'
access_jwt_b="$(printf '%s\n' "$register_b" | jq -r '.access_token')"
user_b="$(printf '%s\n' "$register_b" | jq -r '.user_id')"

if [[ "$access_jwt_a" = "null" || "$access_jwt_b" = "null" || "$user_a" = "null" || "$user_b" = "null" ]]; then
  fail "auth registration did not return real JWTs and user IDs"
fi

unauth_status="$(curl -sS -o /tmp/sakina-memory-unauth.json -w '%{http_code}' \
  "$api_base/v1/api/memory/read?user_id=$user_a&memory_key=$memory_key")"
printf 'Unauthenticated memory read status=%s\n' "$unauth_status"
cat /tmp/sakina-memory-unauth.json | jq .
[[ "$unauth_status" = "401" ]] || fail "memory read allowed missing JWT"

blocked_payload="$(jq -n \
  --arg user_id "$user_a" \
  --arg memory_key "$memory_key" \
  '{user_id:$user_id,memory_key:$memory_key,memory_type:"quran_memorisation",payload:{note:"quran memorisation family trauma"},source_language:"en",consent_required:true,consent_granted:false}')"
blocked_response="$(curl -fsS -X POST "$api_base/v1/api/memory/write" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_jwt_a" \
  -d "$blocked_payload")"
printf '%s\n' "$blocked_response" | jq .
printf '%s\n' "$blocked_response" | jq -e '.stored == false and .allowed == false and .memory_id == null' >/dev/null \
  || fail "sensitive memory without consent was stored"

blocked_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.user_memory_entries WHERE user_id = '$user_a'::uuid AND memory_key = '$memory_key';")"
[[ "$blocked_count" = "0" ]] || fail "blocked memory write persisted a DB row"

write_payload="$(jq -n \
  --arg user_id "$user_a" \
  --arg memory_key "$memory_key" \
  '{user_id:$user_id,memory_key:$memory_key,memory_type:"quran_memorisation",payload:{note:"quran memorisation daily revision",target:"Surah Al-Mulk"},source_language:"en",consent_required:true,consent_granted:true}')"
write_response="$(curl -fsS -X POST "$api_base/v1/api/memory/write" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $access_jwt_a" \
  -d "$write_payload")"
printf '%s\n' "$write_response" | jq .
printf '%s\n' "$write_response" | jq -e '.stored == true and .allowed == true and (.memory_id | type == "string")' >/dev/null \
  || fail "consented memory write did not persist"
memory_id="$(printf '%s\n' "$write_response" | jq -r '.memory_id')"

read_response="$(curl -fsS "$api_base/v1/api/memory/read?user_id=$user_a&memory_key=$memory_key" \
  -H "Authorization: Bearer $access_jwt_a")"
printf '%s\n' "$read_response" | jq .
printf '%s\n' "$read_response" | jq -e --arg memory_key "$memory_key" '.memory_key == $memory_key and .payload.note == "quran memorisation daily revision" and .consent_granted == true' >/dev/null \
  || fail "user A could not read own stored memory"

cross_status="$(curl -sS -o /tmp/sakina-memory-cross.json -w '%{http_code}' \
  "$api_base/v1/api/memory/read?user_id=$user_a&memory_key=$memory_key" \
  -H "Authorization: Bearer $access_jwt_b")"
printf 'Cross-user memory read status=%s\n' "$cross_status"
cat /tmp/sakina-memory-cross.json | jq .
[[ "$cross_status" = "401" ]] || fail "user B could read user A memory"

empty_b_status="$(curl -sS -o /tmp/sakina-memory-empty-b.json -w '%{http_code}' \
  "$api_base/v1/api/memory/read?user_id=$user_b&memory_key=$memory_key" \
  -H "Authorization: Bearer $access_jwt_b")"
printf 'User B own empty memory read status=%s\n' "$empty_b_status"
cat /tmp/sakina-memory-empty-b.json | jq .
[[ "$empty_b_status" = "404" ]] || fail "user B saw memory data for a key only user A wrote"

encrypted_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.user_memory_entries WHERE id = '$memory_id'::uuid AND position(convert_to('quran memorisation daily revision','UTF8') in encrypted_payload) = 0;")"
[[ "$encrypted_probe" = "1" ]] || fail "memory payload was not encrypted at rest"

audit_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_memory_events WHERE user_id = '$user_a'::uuid AND action IN ('write','read');")"
printf 'Memory audit events for user A: %s\n' "$audit_probe"
if (( audit_probe < 2 )); then
  fail "memory write/read audit events were not persisted"
fi

delete_response="$(curl -fsS -X DELETE "$api_base/v1/api/memory/delete?user_id=$user_a&memory_key=$memory_key" \
  -H "Authorization: Bearer $access_jwt_a")"
printf '%s\n' "$delete_response" | jq .
printf '%s\n' "$delete_response" | jq -e '.deleted >= 1' >/dev/null \
  || fail "memory delete did not remove the row"

after_delete_status="$(curl -sS -o /tmp/sakina-memory-after-delete.json -w '%{http_code}' \
  "$api_base/v1/api/memory/read?user_id=$user_a&memory_key=$memory_key" \
  -H "Authorization: Bearer $access_jwt_a")"
printf 'After delete memory read status=%s\n' "$after_delete_status"
cat /tmp/sakina-memory-after-delete.json | jq .
[[ "$after_delete_status" = "404" ]] || fail "deleted memory was still retrievable"

rg -n "writeMemory|readMemory|deleteMemory|MemoryWriteRequest|MemoryEntryResponse|Authorization|Bearer" \
  sakina-frontend/lib/services/api_service.dart >/tmp/sakina-memory-frontend-wiring.txt \
  || fail "Flutter ApiService does not expose real memory backend wiring"
cat /tmp/sakina-memory-frontend-wiring.txt

rg -n "aia\\.route|mother_brain|memory write|user_id does not match authenticated user|brain_memory_events|user_memory_entries|encrypt|decrypt" \
  sakina-backend/src/handlers/memory.rs sakina-backend/src/services/memory_engine.rs >/tmp/sakina-memory-backend-wiring.txt \
  || fail "backend memory path does not show Brain gating, auth isolation, DB, encryption, and audit wiring"
cat /tmp/sakina-memory-backend-wiring.txt

printf 'MEMORY_ENGINE_OK mandatory memory engine proof checks completed.\n'
