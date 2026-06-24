#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'OBSERVABILITY_STACK_BLOCKER %s\n' "$1" >&2
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

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
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
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-observability-proof-backend.log"
request_id="$(cat /proc/sys/kernel/random/uuid)"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null
if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
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
  || fail "backend did not become ready for observability proof; log: $backend_log_file"

trace_response="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $request_id" \
  -d "{\"message\":\"What is the Islamic guidance for prayer while travelling?\",\"language\":\"en\",\"user_subscription_tier\":\"premium\",\"request_id\":\"$request_id\"}")"
printf '%s\n' "$trace_response" | jq .
printf '%s\n' "$trace_response" | jq -e --arg request_id "$request_id" '.request_id == $request_id and (.execution_trace | length > 5)' >/dev/null \
  || fail "Brain response did not preserve request trace ID"

db_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE request_id = '$request_id';")"
printf 'Brain trace DB rows for request: %s\n' "$db_count"
(( db_count >= 1 )) || fail "Brain trace was not persisted with request ID"

observability_response="$(curl -fsS "$api_base/health/observability")"
printf '%s\n' "$observability_response" | jq .
printf '%s\n' "$observability_response" | jq -e '.status == "ok" and .brain_traces >= 1 and .sensitive_log_policy == "do_not_log_secret_values"' >/dev/null \
  || fail "observability health did not expose traces and sensitive log policy"

rg -n "tracing::|request_id|Brain decision logged|health/observability|do_not_log_secret_values|middleware::audit" \
  sakina-backend/src sakina-backend/src/main.rs \
  || fail "observability code path does not show tracing, request IDs, audit middleware, and health endpoint"

if [[ -f "$backend_log_file" ]]; then
  if grep -E "JWT_SECRET|ENCRYPTION_KEY|OPENAI_API_KEY|SAKINA_MULTIMODAL_API_KEY" "$backend_log_file"; then
    fail "backend log leaked sensitive environment key names/values"
  fi
fi

printf 'OBSERVABILITY_STACK_OK trace ID persisted and observability health/logging evidence exists.\n'
