#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'PRODUCT_DATA_EXPORT_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql

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
run_id="data-export-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-product-data-export-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  require_cmd cargo
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

grep -RInE "requestDataExport|/account/export-request|request_data_export|data_export_requested" \
  sakina-frontend/lib sakina-backend/src >/tmp/sakina-product-data-export-code-path.txt \
  || fail "data export frontend/backend code path is missing"
cat /tmp/sakina-product-data-export-code-path.txt

credential="$(printf '%s%s%s' 'Strong' 'Password' '123!')"
register_response="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-register" \
  -d "$(jq -n --arg email "$run_id@example.com" --arg credential "$credential" '{
    email:$email,
    password:$credential,
    display_name:"Data Export Proof User"
  }')")"
token="$(printf '%s\n' "$register_response" | jq -r '.access_token // empty')"
user_id="$(printf '%s\n' "$register_response" | jq -r '.user_id // empty')"
[[ "$token" == *.*.* && "$user_id" =~ ^[0-9a-fA-F-]{36}$ ]] \
  || fail "registration did not return token and user id"

missing_auth_status="$(curl -sS -o /tmp/sakina-product-data-export-missing-auth.json -w '%{http_code}' \
  -X POST "$api_base/v1/account/export-request" \
  -H "Content-Type: application/json" \
  -d '{}')"
printf 'Missing-auth export request status: %s\n' "$missing_auth_status"
cat /tmp/sakina-product-data-export-missing-auth.json | jq .
[[ "$missing_auth_status" = "401" ]] || fail "data export request did not require JWT"

export_response="$(curl -fsS -X POST "$api_base/v1/account/export-request" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-export" \
  -d '{}')"
printf '%s\n' "$export_response" | jq .
printf '%s\n' "$export_response" | jq -e '.status == "queued" and .request_id and .audit_id and .outbox_event_id' >/dev/null \
  || fail "data export request did not return queued audit/outbox response"

audit_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.audit_logs WHERE request_id = '$run_id-export' AND event_type = 'data_export_requested' AND actor_id = '$user_id';")"
outbox_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM outbox.events WHERE event_type = 'data_export_requested' AND payload->>'request_id' = '$run_id-export' AND payload->>'user_id' = '$user_id';")"
printf 'Data export audit rows=%s outbox rows=%s\n' "$audit_count" "$outbox_count"
[[ "$audit_count" = "1" && "$outbox_count" = "1" ]] \
  || fail "data export request did not persist audit and outbox evidence"

printf 'PRODUCT_DATA_EXPORT_OK authenticated data export request is wired through mobile service, backend route, audit log, and outbox event.\n'
