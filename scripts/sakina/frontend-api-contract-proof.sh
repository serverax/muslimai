#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'FRONTEND_API_CONTRACT_BLOCKER %s\n' "$1" >&2
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
backend_log_file="${TMPDIR:-/tmp}/sakina-frontend-api-contract-backend.log"

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

rg -n "registerWithPassword|loginWithPassword|refreshWithToken|currentUser|logout\\(|Authorization.*Bearer|flutter_secure_storage|sakina_refresh_token" \
  sakina-frontend/lib/services >/tmp/sakina-frontend-auth-contract-code.txt \
  || fail "frontend auth API contract code paths are missing"
cat /tmp/sakina-frontend-auth-contract-code.txt

email="frontend-contract-$run_id@example.com"
password="StrongPassword123!"

register_response="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email" --arg password "$password" '{
    email:$email,
    password:$password,
    name:"Frontend Contract User",
    provider:"password",
    provider_user_id:$email,
    metadata:{display_name:"Frontend Contract User"}
  }')")"
printf '%s\n' "$register_response" | jq .
printf '%s\n' "$register_response" | jq -e '.user_id and .access_token and .refresh_token' >/dev/null \
  || fail "register response does not match frontend PasswordAuthResponse contract"

login_response="$(curl -fsS -X POST "$api_base/auth/login" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email" --arg password "$password" '{email:$email,password:$password}')")"
printf '%s\n' "$login_response" | jq .
access_token="$(printf '%s\n' "$login_response" | jq -r '.access_token')"
refresh_token="$(printf '%s\n' "$login_response" | jq -r '.refresh_token')"
[[ "$access_token" == *.*.* && "$refresh_token" == *.*.* ]] \
  || fail "login did not return JWT access and refresh tokens"

me_response="$(curl -fsS "$api_base/auth/me" -H "Authorization: Bearer $access_token")"
printf '%s\n' "$me_response" | jq .
printf '%s\n' "$me_response" | jq -e --arg email "$email" '.user_id and .email == $email' >/dev/null \
  || fail "auth/me response does not match frontend UserSummaryResponse contract"

refresh_response="$(curl -fsS -X POST "$api_base/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg refresh_token "$refresh_token" '{refresh_token:$refresh_token}')")"
printf '%s\n' "$refresh_response" | jq .
new_access_token="$(printf '%s\n' "$refresh_response" | jq -r '.access_token')"
new_refresh_token="$(printf '%s\n' "$refresh_response" | jq -r '.refresh_token')"
[[ "$new_access_token" == *.*.* && "$new_refresh_token" == *.*.* ]] \
  || fail "refresh did not return rotated JWT pair"
[[ "$new_refresh_token" != "$refresh_token" ]] \
  || fail "refresh token was not rotated"

reuse_status="$(curl -sS -o /tmp/sakina-refresh-reuse.json -w "%{http_code}" \
  -X POST "$api_base/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg refresh_token "$refresh_token" '{refresh_token:$refresh_token}')")"
printf 'Refresh token reuse status=%s\n' "$reuse_status"
[[ "$reuse_status" == "401" ]] || fail "old refresh token reuse was not rejected"

logout_status="$(curl -sS -o /tmp/sakina-logout.json -w "%{http_code}" \
  -X POST "$api_base/auth/logout" \
  -H "Authorization: Bearer $new_access_token" \
  -H "Content-Type: application/json" \
  -d '{}')"
printf 'Logout status=%s\n' "$logout_status"
[[ "$logout_status" -ge 200 && "$logout_status" -lt 300 ]] || fail "logout did not return success"

revoked_status="$(curl -sS -o /tmp/sakina-revoked-me.json -w "%{http_code}" \
  "$api_base/auth/me" \
  -H "Authorization: Bearer $new_access_token")"
printf 'Revoked token /auth/me status=%s\n' "$revoked_status"
[[ "$revoked_status" == "401" ]] || fail "revoked access token was not rejected"

for code_path in 400 401 403 404 409 422 429 500; do
  rg -n "$code_path" sakina-frontend/lib/services sakina-frontend/lib/screens >/dev/null \
    || fail "frontend error mapping for HTTP $code_path is not present"
done

db_session_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.auth_sessions s JOIN public.users u ON u.id = s.user_id WHERE u.email = '$email';")"
db_refresh_used="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.auth_refresh_tokens rt JOIN public.users u ON u.id = rt.user_id WHERE u.email = '$email' AND rt.used_at IS NOT NULL;")"
printf 'DB sessions=%s used_refresh_tokens=%s\n' "$db_session_count" "$db_refresh_used"
(( db_session_count >= 2 && db_refresh_used >= 1 )) \
  || fail "DB did not prove session creation and refresh rotation"

printf 'FRONTEND_API_CONTRACT_OK register/login/refresh/me/logout/error contracts match frontend models and backend runtime.\n'
