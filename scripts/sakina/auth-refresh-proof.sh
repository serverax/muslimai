#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'AUTH_REFRESH_BLOCKER %s\n' "$1" >&2
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
backend_log_file="${TMPDIR:-/tmp}/sakina-auth-refresh-backend.log"

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

rg -n "refreshWithToken|/auth/refresh|sakina_refresh_token|logout\\(" \
  sakina-frontend/lib/services sakina-backend/src >/tmp/sakina-auth-refresh-code-paths.txt \
  || fail "refresh endpoint and frontend refresh code paths are missing"
cat /tmp/sakina-auth-refresh-code-paths.txt

email="auth-refresh-$run_id@example.com"
password="$(printf '%s' 'StrongPassword123!')"

register_response="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email" --arg password "$password" '{
    email:$email,
    password:$password,
    display_name:"Refresh Proof User"
  }')")"
printf '%s\n' "$register_response" | jq '{user_id,email,has_access_token:(.access_token != null),has_refresh_token:(.refresh_token != null)}'
printf '%s\n' "$register_response" | jq -e '.user_id and .access_token and .refresh_token' >/dev/null \
  || fail "register did not issue access and refresh tokens"

login_response="$(curl -fsS -X POST "$api_base/auth/login" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "$email" --arg password "$password" '{email:$email,password:$password}')")"
printf '%s\n' "$login_response" | jq '{user_id,email,access_token_format:(.access_token|test("^[^.]+[.][^.]+[.][^.]+$")),refresh_token_format:(.refresh_token|test("^[^.]+[.][^.]+[.][^.]+$"))}'
access_token="$(printf '%s\n' "$login_response" | jq -r '.access_token')"
refresh_token="$(printf '%s\n' "$login_response" | jq -r '.refresh_token')"
user_id="$(printf '%s\n' "$login_response" | jq -r '.user_id')"
[[ "$access_token" == *.*.* && "$refresh_token" == *.*.* ]] \
  || fail "login did not return JWT access and refresh tokens"

refresh_response="$(curl -fsS -X POST "$api_base/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg refresh_token "$refresh_token" '{refresh_token:$refresh_token}')")"
printf '%s\n' "$refresh_response" | jq '{user_id,email,access_token_format:(.access_token|test("^[^.]+[.][^.]+[.][^.]+$")),refresh_token_format:(.refresh_token|test("^[^.]+[.][^.]+[.][^.]+$"))}'
new_access_token="$(printf '%s\n' "$refresh_response" | jq -r '.access_token')"
new_refresh_token="$(printf '%s\n' "$refresh_response" | jq -r '.refresh_token')"
[[ "$new_access_token" == *.*.* && "$new_refresh_token" == *.*.* ]] \
  || fail "refresh did not return rotated JWT pair"
[[ "$new_refresh_token" != "$refresh_token" ]] \
  || fail "refresh token was not rotated"

reuse_status="$(curl -sS -o /tmp/sakina-auth-refresh-reuse.json -w "%{http_code}" \
  -X POST "$api_base/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg refresh_token "$refresh_token" '{refresh_token:$refresh_token}')")"
printf 'old_refresh_reuse_status=%s\n' "$reuse_status"
cat /tmp/sakina-auth-refresh-reuse.json | jq .
[[ "$reuse_status" == "401" ]] || fail "old refresh token reuse was not rejected"

invalid_status="$(curl -sS -o /tmp/sakina-auth-refresh-invalid.json -w "%{http_code}" \
  -X POST "$api_base/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"invalid.refresh.token"}')"
printf 'invalid_refresh_status=%s\n' "$invalid_status"
cat /tmp/sakina-auth-refresh-invalid.json | jq .
[[ "$invalid_status" == "401" ]] || fail "invalid refresh token was not rejected"

curl -fsS "$api_base/auth/me" -H "Authorization: Bearer $new_access_token" \
  | jq '{user_id,email}'

logout_response="$(curl -fsS -X POST "$api_base/auth/logout" \
  -H "Authorization: Bearer $new_access_token" \
  -H "Content-Type: application/json" \
  -d '{}')"
printf '%s\n' "$logout_response" | jq .

revoked_status="$(curl -sS -o /tmp/sakina-auth-refresh-revoked-access.json -w "%{http_code}" \
  "$api_base/auth/me" \
  -H "Authorization: Bearer $new_access_token")"
printf 'revoked_access_status=%s\n' "$revoked_status"
cat /tmp/sakina-auth-refresh-revoked-access.json | jq .
[[ "$revoked_status" == "401" ]] || fail "logout-revoked access token was not rejected"

refresh_after_logout_status="$(curl -sS -o /tmp/sakina-auth-refresh-after-logout.json -w "%{http_code}" \
  -X POST "$api_base/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg refresh_token "$new_refresh_token" '{refresh_token:$refresh_token}')")"
printf 'refresh_after_logout_status=%s\n' "$refresh_after_logout_status"
cat /tmp/sakina-auth-refresh-after-logout.json | jq .
[[ "$refresh_after_logout_status" == "401" ]] || fail "logout-revoked refresh token was not rejected"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "SELECT COUNT(*) AS session_count FROM public.auth_sessions WHERE user_id = '$user_id';"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "SELECT COUNT(*) AS used_refresh_tokens FROM public.auth_refresh_tokens WHERE user_id = '$user_id' AND used_at IS NOT NULL;"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "SELECT COUNT(*) AS revoked_refresh_tokens FROM public.auth_refresh_tokens WHERE user_id = '$user_id' AND revoked_at IS NOT NULL;"

db_counts="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT
     (SELECT COUNT(*) FROM public.auth_sessions WHERE user_id = '$user_id'),
     (SELECT COUNT(*) FROM public.auth_refresh_tokens WHERE user_id = '$user_id' AND used_at IS NOT NULL),
     (SELECT COUNT(*) FROM public.auth_refresh_tokens WHERE user_id = '$user_id' AND revoked_at IS NOT NULL);")"
IFS='|' read -r session_count used_refresh_count revoked_refresh_count <<<"$db_counts"
(( session_count >= 2 )) || fail "DB did not record rotated sessions"
(( used_refresh_count >= 1 )) || fail "DB did not mark old refresh token used"
(( revoked_refresh_count >= 2 )) || fail "DB did not revoke rotated/logout refresh tokens"

printf 'AUTH_REFRESH_OK refresh endpoint rotates tokens, rejects reuse/invalid/revoked tokens, and DB proves session state.\n'
