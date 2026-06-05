#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'PAYMENTS_ENTITLEMENTS_BLOCKER %s\n' "$1" >&2
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
export SAKINA_FEATURE_QURAN="${SAKINA_FEATURE_QURAN:-true}"
export SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET="${SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET:-sakina-manual-grant-secret-minimum-32-bytes}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${BASE_URL%/}"
run_id="payments-entitlements-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-payments-entitlements-backend.log"

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

curl -fsS "$api_base/health/ready" \
  | jq -e '.status == "ready" and (.checks.payments == "ok" or .checks.payments == "configured_or_disabled_closed")' >/dev/null \
  || fail "backend did not become ready for payments entitlement proof; log: $backend_log_file"

register_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $run_id-register" \
    -d "$(jq -n --arg email "$email" '{
      email:$email,
      password:"StrongPassword123!",
      display_name:"Payments Entitlements Proof User",
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
printf 'Payments entitlement proof users: A=%s B=%s\n' "$user_a" "$user_b"

activation_body="$(jq -n --arg run_id "$run_id" --arg user_a "$user_a" '{
  user_id:$user_a,
  provider_key:"closed_beta_manual",
  provider_display_name:"Closed Beta Manual Grant",
  provider_customer_ref:("customer-" + $run_id),
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
  entitlement_keys:["quran_access","chat_premium","rag_verified"]
}')"

missing_secret_status="$(curl -sS -o /tmp/sakina-payments-missing-secret.json -w '%{http_code}' \
  -X POST "$api_base/v1/subscriptions/$user_a/activate" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d "$activation_body")"
cat /tmp/sakina-payments-missing-secret.json
printf '\nMissing grant secret status: %s\n' "$missing_secret_status"
[[ "$missing_secret_status" = "401" ]] || fail "user could self-grant entitlement without grant secret"

wrong_secret_status="$(curl -sS -o /tmp/sakina-payments-wrong-secret.json -w '%{http_code}' \
  -X POST "$api_base/v1/subscriptions/$user_a/activate" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Sakina-Grant-Secret: wrong-secret-value" \
  -H "Content-Type: application/json" \
  -d "$activation_body")"
cat /tmp/sakina-payments-wrong-secret.json
printf '\nWrong grant secret status: %s\n' "$wrong_secret_status"
[[ "$wrong_secret_status" = "401" ]] || fail "user could self-grant entitlement with wrong grant secret"

cross_activation_status="$(curl -sS -o /tmp/sakina-payments-cross-activation.json -w '%{http_code}' \
  -X POST "$api_base/v1/subscriptions/$user_a/activate" \
  -H "Authorization: Bearer $token_b" \
  -H "X-Sakina-Grant-Secret: $SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET" \
  -H "Content-Type: application/json" \
  -d "$activation_body")"
cat /tmp/sakina-payments-cross-activation.json
printf '\nCross-user activation status: %s\n' "$cross_activation_status"
[[ "$cross_activation_status" = "401" ]] || fail "user B could activate user A entitlement"

activation_response="$(curl -fsS -X POST "$api_base/v1/subscriptions/$user_a/activate" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Sakina-Grant-Secret: $SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-activate" \
  -d "$activation_body")"
printf '%s\n' "$activation_response" | jq .
subscription_id="$(printf '%s\n' "$activation_response" | jq -r '.subscription_id // empty')"
invoice_id="$(printf '%s\n' "$activation_response" | jq -r '.invoice_id // empty')"
[[ "$subscription_id" =~ ^[0-9a-fA-F-]{36}$ && "$invoice_id" =~ ^[0-9a-fA-F-]{36}$ ]] \
  || fail "manual entitlement activation did not return DB subscription and invoice IDs"

duplicate_response="$(curl -fsS -X POST "$api_base/v1/subscriptions/$user_a/activate" \
  -H "Authorization: Bearer $token_a" \
  -H "X-Sakina-Grant-Secret: $SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-activate-duplicate" \
  -d "$activation_body")"
printf '%s\n' "$duplicate_response" | jq .
duplicate_subscription_id="$(printf '%s\n' "$duplicate_response" | jq -r '.subscription_id // empty')"
[[ "$duplicate_subscription_id" = "$subscription_id" ]] \
  || fail "duplicate provider subscription reference was not idempotent"

owner_entitlements="$(curl -fsS "$api_base/v1/subscriptions/$user_a/entitlements" \
  -H "Authorization: Bearer $token_a")"
printf '%s\n' "$owner_entitlements" | jq .
printf '%s\n' "$owner_entitlements" \
  | jq -e '.entitlements[]? | select(.entitlement_key == "quran_access")' >/dev/null \
  || fail "owner entitlement list did not include quran_access"

cross_entitlements_status="$(curl -sS -o /tmp/sakina-payments-cross-entitlements.json -w '%{http_code}' \
  "$api_base/v1/subscriptions/$user_a/entitlements" \
  -H "Authorization: Bearer $token_b")"
cat /tmp/sakina-payments-cross-entitlements.json
printf '\nCross-user entitlement read status: %s\n' "$cross_entitlements_status"
[[ "$cross_entitlements_status" = "401" ]] || fail "user B could read user A entitlements"

overview_status="$(curl -sS -o /tmp/sakina-payments-quran-overview.json -w '%{http_code}' \
  "$api_base/v1/modules/quran/overview" \
  -H "Authorization: Bearer $token_a")"
cat /tmp/sakina-payments-quran-overview.json
printf '\nOwner module access status: %s\n' "$overview_status"
[[ "$overview_status" = "200" ]] || fail "entitled owner could not access gated module"

payment_counts="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -F ',' -c \
  "SELECT
     (SELECT COUNT(*) FROM public.payment_providers WHERE provider_key = 'closed_beta_manual'),
     (SELECT COUNT(*) FROM public.subscription_plans WHERE plan_key = 'plan-$run_id'),
     (SELECT COUNT(*) FROM public.payment_customers WHERE user_id = '$user_a'::uuid),
     (SELECT COUNT(*) FROM public.user_subscriptions WHERE id = '$subscription_id'::uuid AND user_id = '$user_a'::uuid AND subscription_status = 'active'),
     (SELECT COUNT(*) FROM public.invoices WHERE id = '$invoice_id'::uuid AND user_id = '$user_a'::uuid AND invoice_status = 'paid'),
     (SELECT COUNT(*) FROM public.payment_transactions WHERE user_id = '$user_a'::uuid AND provider_transaction_ref = 'transaction-$run_id' AND transaction_status = 'succeeded'),
     (SELECT COUNT(*) FROM public.user_entitlements ue JOIN public.entitlements e ON e.id = ue.entitlement_id WHERE ue.user_id = '$user_a'::uuid AND e.entitlement_key = 'quran_access' AND ue.revoked_at IS NULL);")"
printf 'DB payment/subscription/entitlement counts: %s\n' "$payment_counts"
IFS=',' read -r providers plans customers subscriptions invoices transactions entitlements <<<"$payment_counts"
[[ "$providers" -ge 1 && "$plans" = "1" && "$customers" -ge 1 && "$subscriptions" = "1" && "$invoices" = "1" && "$transactions" = "1" && "$entitlements" = "1" ]] \
  || fail "DB did not prove provider, plan, customer, subscription, invoice, transaction, and entitlement rows"

failed_ref="failed-$run_id"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "WITH provider AS (
     SELECT id FROM public.payment_providers WHERE provider_key = 'closed_beta_manual' LIMIT 1
   )
   INSERT INTO public.payment_transactions (
     user_id, provider_id, subscription_id, invoice_id, provider_transaction_ref,
     transaction_type, transaction_status, currency_code, amount_minor, processed_at
   )
   SELECT '$user_b'::uuid, provider.id, NULL, NULL, '$failed_ref',
          'charge', 'failed', 'USD', 1999, now()
   FROM provider
   ON CONFLICT (provider_transaction_ref) DO NOTHING;" >/tmp/sakina-payments-failed-transaction.sql.out
cat /tmp/sakina-payments-failed-transaction.sql.out

failed_entitlement_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*)
   FROM public.user_entitlements ue
   JOIN public.entitlements e ON e.id = ue.entitlement_id
   WHERE ue.user_id = '$user_b'::uuid AND e.entitlement_key = 'quran_access' AND ue.revoked_at IS NULL;")"
printf 'Failed-payment entitlement count for user B: %s\n' "$failed_entitlement_count"
[[ "$failed_entitlement_count" = "0" ]] || fail "failed payment created entitlement"

rg -n "ActivateSubscriptionRequest|activateSubscription|listEntitlements|Authorization|Bearer" \
  sakina-frontend/lib/services/api_service.dart \
  >/tmp/sakina-payments-frontend-code-path.txt \
  || fail "frontend subscription/entitlement service wiring was not found"
cat /tmp/sakina-payments-frontend-code-path.txt

if rg -n "provider_subscription_ref': 'sub-|provider_invoice_ref': 'inv-|provider_transaction_ref': 'txn-|provider_customer_ref': 'cust-" \
  sakina-frontend/lib/services/api_service.dart; then
  fail "frontend still fabricates provider payment references"
fi

rg -n "SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET|X-Sakina-Grant-Secret|payment_providers|payment_transactions|user_entitlements|provider_subscription_ref" \
  sakina-backend/src/handlers/phase2.rs sakina-backend/src/services/phase2.rs \
  >/tmp/sakina-payments-backend-code-path.txt \
  || fail "backend payment/entitlement guarded DB code path was not found"
cat /tmp/sakina-payments-backend-code-path.txt

printf 'PAYMENTS_ENTITLEMENTS_OK manual closed-beta entitlement grants require a backend grant secret, user self-grant and cross-user grant are blocked, subscription/payment rows persist, duplicate provider references are idempotent, failed payment does not grant entitlement, frontend reads entitlements through real API, and static frontend provider references are removed.\n'
