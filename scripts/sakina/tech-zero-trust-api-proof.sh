#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'ZERO_TRUST_API_BLOCKER %s\n' "$1" >&2
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
run_id="zero-trust-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-zero-trust-api-backend.log"

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
  || fail "backend did not become ready for zero-trust proof; log: $backend_log_file"

register_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $run_id-register" \
    -d "$(jq -n --arg email "$email" '{
      email:$email,
      password:"StrongPassword123!",
      display_name:"Zero Trust Proof User",
      provider:"password",
      provider_user_id:$email,
      metadata:{}
    }')"
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
printf 'Zero-trust proof users: A=%s B=%s\n' "$user_a" "$user_b"

missing_auth_status="$(curl -sS -o /tmp/sakina-zero-missing-auth.json -w '%{http_code}' "$api_base/auth/me")"
cat /tmp/sakina-zero-missing-auth.json
printf '\nMissing auth status: %s\n' "$missing_auth_status"
[[ "$missing_auth_status" = "401" ]] || fail "unauthenticated protected request was not rejected"

invalid_jwt_status="$(curl -sS -o /tmp/sakina-zero-invalid-jwt.json -w '%{http_code}' \
  "$api_base/auth/me" \
  -H "Authorization: Bearer invalid.invalid.invalid")"
cat /tmp/sakina-zero-invalid-jwt.json
printf '\nInvalid JWT status: %s\n' "$invalid_jwt_status"
[[ "$invalid_jwt_status" = "401" ]] || fail "invalid JWT was not rejected"

owner_me="$(curl -fsS "$api_base/auth/me" -H "Authorization: Bearer $token_a")"
printf '%s\n' "$owner_me" | jq .
printf '%s\n' "$owner_me" | jq -e --arg user_a "$user_a" '.user_id == $user_a' >/dev/null \
  || fail "owner JWT did not resolve to authenticated user"

cross_profile_status="$(curl -sS -o /tmp/sakina-zero-cross-profile.json -w '%{http_code}' \
  -X PUT "$api_base/v1/profiles/$user_a" \
  -H "Authorization: Bearer $token_b" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_a "$user_a" '{
    user_id:$user_a,
    display_name:"Cross User Update",
    timezone:"UTC",
    metadata:{proof:"zero-trust-cross-user"},
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
cat /tmp/sakina-zero-cross-profile.json
printf '\nCross-user profile update status: %s\n' "$cross_profile_status"
[[ "$cross_profile_status" = "401" ]] || fail "cross-user profile update was not rejected"

cross_entitlements_status="$(curl -sS -o /tmp/sakina-zero-cross-entitlements.json -w '%{http_code}' \
  "$api_base/v1/subscriptions/$user_a/entitlements" \
  -H "Authorization: Bearer $token_b")"
cat /tmp/sakina-zero-cross-entitlements.json
printf '\nCross-user entitlement read status: %s\n' "$cross_entitlements_status"
[[ "$cross_entitlements_status" = "401" ]] || fail "cross-user entitlement read was not rejected"

invalid_input_status="$(curl -sS -o /tmp/sakina-zero-invalid-input.json -w '%{http_code}' \
  -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "invalid-$run_id@example.com" '{email:$email,password:"short",display_name:"Invalid"}')")"
cat /tmp/sakina-zero-invalid-input.json
printf '\nInvalid weak-password input status: %s\n' "$invalid_input_status"
[[ "$invalid_input_status" -ge 400 ]] || fail "invalid weak-password input was accepted"

oversized_status="$(python3 - <<'PY' | curl -sS -o /tmp/sakina-zero-oversized.json -w '%{http_code}' -X POST "$api_base/api/multimodal/analyze" -H "Authorization: Bearer $token_a" -H "Content-Type: application/json" --data-binary @-
print('{"asset_type":"text","content":"' + ('a' * 300000) + '"}')
PY
)"
cat /tmp/sakina-zero-oversized.json
printf '\nOversized payload status: %s\n' "$oversized_status"
[[ "$oversized_status" -ge 400 ]] || fail "oversized request was accepted"

cors_headers="$(curl -sS -i -X OPTIONS "$api_base/auth/login" \
  -H "Origin: http://evil.invalid" \
  -H "Access-Control-Request-Method: POST")"
printf '%s\n' "$cors_headers" > /tmp/sakina-zero-cors.txt
cat /tmp/sakina-zero-cors.txt
if grep -qi '^Access-Control-Allow-Origin: http://evil.invalid' /tmp/sakina-zero-cors.txt; then
  fail "CORS allowed an untrusted origin"
fi

rate_limited_seen=0
rate_key="203.0.113.$((RANDOM % 200 + 1))"
for attempt in $(seq 1 7); do
  status="$(curl -sS -o "/tmp/sakina-zero-waitlist-$attempt.json" -w '%{http_code}' \
    -X POST "$api_base/v1/waitlist" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: $rate_key" \
    -d "$(jq -n --arg email "$run_id-waitlist-$attempt@example.com" '{
      name:"Zero Trust Rate Limit",
      email:$email,
      preferred_language:"en",
      platform:"android",
      message:"runtime rate limit proof",
      source:"zero-trust-proof"
    }')")"
  printf 'Waitlist attempt %s status=%s\n' "$attempt" "$status"
  if [[ "$status" = "429" ]]; then
    rate_limited_seen=1
    break
  fi
done
[[ "$rate_limited_seen" = "1" ]] || fail "rate limit was not enforced on repeated requests"

security_request_id="$run_id-security-audit"
security_status="$(curl -sS -o /tmp/sakina-zero-security-log.json -w '%{http_code}' \
  -X POST "$api_base/v1/security/logs" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg user_a "$user_a" --arg request_id "$security_request_id" '{
    event_type:"zero_trust_negative_checks",
    severity:"high",
    user_id:$user_a,
    ip_address:"203.0.113.10",
    request_id:$request_id,
    details:{
      missing_auth:"401",
      invalid_jwt:"401",
      cross_user_profile:"401",
      cross_user_entitlements:"401",
      oversized:"blocked",
      rate_limited:"429"
    }
  }')")"
cat /tmp/sakina-zero-security-log.json
printf '\nSecurity log status: %s\n' "$security_status"
[[ "$security_status" = "201" ]] || fail "security event audit route did not persist event"

security_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.security_logs WHERE request_id = '$security_request_id' AND event_type = 'zero_trust_negative_checks';")"
printf 'Security audit rows for %s: %s\n' "$security_request_id" "$security_count"
[[ "$security_count" = "1" ]] || fail "security event audit row was not found in DB"

logout_status="$(curl -sS -o /tmp/sakina-zero-logout.json -w '%{http_code}' \
  -X POST "$api_base/auth/logout" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d '{}')"
cat /tmp/sakina-zero-logout.json
printf '\nLogout status: %s\n' "$logout_status"
[[ "$logout_status" -ge 200 && "$logout_status" -lt 300 ]] || fail "logout did not revoke session"

revoked_status="$(curl -sS -o /tmp/sakina-zero-revoked.json -w '%{http_code}' \
  "$api_base/auth/me" \
  -H "Authorization: Bearer $token_a")"
cat /tmp/sakina-zero-revoked.json
printf '\nRevoked token status: %s\n' "$revoked_status"
[[ "$revoked_status" = "401" ]] || fail "revoked JWT was still accepted"

revoked_db_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.auth_sessions WHERE user_id = '$user_a'::uuid AND revoked_at IS NOT NULL;")"
printf 'Revoked DB sessions for A: %s\n' "$revoked_db_count"
(( revoked_db_count >= 1 )) || fail "revoked session was not persisted in DB"

rg -n "authenticated_user_id|bearer_token|revoked_at|requested user_id does not match authenticated user|rate_limited|allowed_origin|security_logs|WaitlistRateLimiter" \
  sakina-backend/src sakina-frontend/lib scripts/sakina/security-regression.sh \
  >/tmp/sakina-zero-trust-code-paths.txt \
  || fail "zero-trust API guard code paths were not found"
cat /tmp/sakina-zero-trust-code-paths.txt

printf 'ZERO_TRUST_API_OK runtime proof rejected missing/invalid/revoked JWTs, blocked cross-user read/update, blocked oversized and invalid input, enforced rate limiting, restricted CORS, persisted security audit evidence, and confirmed backend/frontend guard code paths.\n'
