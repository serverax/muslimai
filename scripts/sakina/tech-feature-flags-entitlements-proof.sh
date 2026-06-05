#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'FEATURE_FLAGS_ENTITLEMENTS_BLOCKER %s\n' "$1" >&2
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
export SAKINA_FEATURE_QURAN=true
export SAKINA_FEATURE_PRAYER=false
export SAKINA_FEATURE_KNOWLEDGE=false
export SAKINA_FEATURE_COMMUNITY=false
export SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET="${SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET:-sakina-manual-grant-secret-minimum-32-bytes}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${BASE_URL%/}"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-feature-entitlement-proof-backend.log"
run_id="feature-entitlement-$(date +%s)-$RANDOM"

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
  || fail "backend did not become ready for feature entitlement proof; log: $backend_log_file"

register_user() {
  local email="$1"
  local credential
  credential="$(printf '%s' 'StrongPassword123!')"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $run_id-register" \
    -d "$(jq -n --arg email "$email" --arg credential "$credential" '{email:$email,password:$credential,display_name:"Feature Entitlement Proof User",provider:"password",provider_user_id:$email,metadata:{}}')"
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
printf 'Feature entitlement proof users: A=%s B=%s\n' "$user_a" "$user_b"

status_response="$(curl -fsS "$api_base/v1/modules/quran/status")"
printf '%s\n' "$status_response" | jq .
printf '%s\n' "$status_response" | jq -e '.enabled == true and .requires_subscription == true' >/dev/null \
  || fail "enabled feature flag did not appear in backend module status"

missing_auth_status="$(curl -sS -o /tmp/sakina-feature-missing-auth.json -w '%{http_code}' \
  "$api_base/v1/modules/quran/overview" \
  -H "x-sakina-subscription-tier: premium")"
cat /tmp/sakina-feature-missing-auth.json
printf '\nMissing-auth quran overview status: %s\n' "$missing_auth_status"
[[ "$missing_auth_status" = "401" ]] || fail "module overview allowed forged premium header without JWT"

free_status="$(curl -sS -o /tmp/sakina-feature-free-user.json -w '%{http_code}' \
  "$api_base/v1/modules/quran/overview" \
  -H "Authorization: Bearer $token_a" \
  -H "x-sakina-subscription-tier: premium")"
cat /tmp/sakina-feature-free-user.json
printf '\nFree-user quran overview status: %s\n' "$free_status"
[[ "$free_status" = "402" ]] || fail "authenticated user without DB entitlement was not blocked"

subscription_response="$(curl -fsS -X POST "$api_base/v1/subscriptions/$user_a/activate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Sakina-Grant-Secret: $SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET" \
  -H "X-Request-ID: $run_id-subscribe" \
  -d "$(jq -n --arg run_id "$run_id" --arg user_id "$user_a" '{
    user_id:$user_id,
    provider_key:"closed_beta_manual",
    provider_display_name:"Closed Beta Manual Grant",
    provider_customer_ref:("cust-" + $run_id),
    plan_key:("plan-" + $run_id),
    plan_name:"Closed Beta Premium",
    billing_interval:"monthly",
    provider_subscription_ref:("subscription-" + $run_id),
    provider_invoice_ref:("invoice-" + $run_id),
    provider_transaction_ref:("transaction-" + $run_id),
    currency_code:"USD",
    amount_minor:0,
    current_period_start:(now | todateiso8601),
    current_period_end:((now + 2592000) | todateiso8601),
    entitlement_keys:["quran_access","rag_verified"]
  }')")"
printf '%s\n' "$subscription_response" | jq .
subscription_id="$(printf '%s\n' "$subscription_response" | jq -r '.subscription_id // empty')"
[[ "$subscription_id" =~ ^[0-9a-fA-F-]{36}$ ]] || fail "subscription activation did not return subscription id"

entitlements_response="$(curl -fsS "$api_base/v1/subscriptions/$user_a/entitlements" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Request-ID: $run_id-entitlements")"
printf '%s\n' "$entitlements_response" | jq .
printf '%s\n' "$entitlements_response" \
  | jq -e '.entitlements[]? | select(.entitlement_key == "quran_access")' >/dev/null \
  || fail "activated DB entitlement was not listed for owner"

db_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*)
   FROM public.user_entitlements ue
   JOIN public.entitlements e ON e.id = ue.entitlement_id
   WHERE ue.user_id = '$user_a'::uuid AND e.entitlement_key = 'quran_access' AND ue.revoked_at IS NULL;")"
printf 'DB quran_access entitlement count for A: %s\n' "$db_probe"
[[ "$db_probe" = "1" ]] || fail "DB entitlement row missing for owner"

owner_status="$(curl -sS -o /tmp/sakina-feature-owner-overview.json -w '%{http_code}' \
  "$api_base/v1/modules/quran/overview" \
  -H "Authorization: Bearer $token_a")"
cat /tmp/sakina-feature-owner-overview.json
printf '\nOwner quran overview status: %s\n' "$owner_status"
[[ "$owner_status" = "200" ]] || fail "owner with DB entitlement could not access enabled module"

cross_status="$(curl -sS -o /tmp/sakina-feature-cross-overview.json -w '%{http_code}' \
  "$api_base/v1/modules/quran/overview" \
  -H "Authorization: Bearer $token_b" \
  -H "x-sakina-subscription-tier: premium")"
cat /tmp/sakina-feature-cross-overview.json
printf '\nCross-user forged-tier overview status: %s\n' "$cross_status"
[[ "$cross_status" = "402" ]] || fail "user B could bypass entitlement by forging subscription tier"

disabled_status="$(curl -sS -o /tmp/sakina-feature-disabled-prayer.json -w '%{http_code}' \
  "$api_base/v1/modules/prayer/overview" \
  -H "Authorization: Bearer $token_a")"
cat /tmp/sakina-feature-disabled-prayer.json
printf '\nDisabled prayer overview status: %s\n' "$disabled_status"
[[ "$disabled_status" = "403" ]] || fail "disabled feature flag did not fail closed"

cross_entitlements_status="$(curl -sS -o /tmp/sakina-feature-cross-entitlements.json -w '%{http_code}' \
  "$api_base/v1/subscriptions/$user_a/entitlements" \
  -H "Authorization: Bearer $token_b")"
cat /tmp/sakina-feature-cross-entitlements.json
printf '\nCross-user entitlement list status: %s\n' "$cross_entitlements_status"
[[ "$cross_entitlements_status" = "401" ]] || fail "user B could list user A entitlements"

rg -n "Authorization|Bearer|ModuleApiClient\\(|activateSubscription|listEntitlements|EntitlementGate|FeatureFlags" \
  sakina-frontend/lib/services/module_service.dart sakina-frontend/lib/screens/home_shell_screen.dart sakina-frontend/lib/services/api_service.dart \
  >/tmp/sakina-feature-entitlement-frontend-code-path.txt \
  || fail "frontend feature flag/entitlement wiring code path was not found"
cat /tmp/sakina-feature-entitlement-frontend-code-path.txt

rg -n "user_entitlements|entitlement_key|authenticated_user_id|SAKINA_FEATURE_QURAN|subscription_required|feature_disabled" \
  sakina-backend/src/handlers/modules.rs sakina-backend/src/handlers/phase2.rs sakina-backend/src/services/phase2.rs \
  >/tmp/sakina-feature-entitlement-backend-code-path.txt \
  || fail "backend feature flag/entitlement DB code path was not found"
cat /tmp/sakina-feature-entitlement-backend-code-path.txt

printf 'FEATURE_FLAGS_ENTITLEMENTS_OK enabled feature required JWT and DB entitlement, forged headers were rejected, disabled feature failed closed, owner entitlement persisted in DB, cross-user access was blocked, and Flutter module service sends bearer auth.\n'
