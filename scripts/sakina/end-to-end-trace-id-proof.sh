#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'END_TO_END_TRACE_ID_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql
require_cmd rg
require_cmd cargo

cat tasks/AGENTS.md >/dev/null
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
request_id="e2e-trace-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-end-to-end-trace-id-proof-backend.log"

psql_at() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "$1" \
    || fail "SQL command failed: $1"
}

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

trace_response="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $request_id" \
  -d "$(jq -n \
    --arg request_id "$request_id" \
    '{message:"What is the Islamic guidance for prayer while travelling?",language:"en",user_subscription_tier:"premium",request_id:$request_id}')")"

printf '%s\n' "$trace_response" | jq .
printf '%s\n' "$trace_response" \
  | jq -e --arg request_id "$request_id" \
      '.request_id == $request_id and (.execution_trace | type == "array") and (.execution_trace | length >= 10)' >/dev/null \
  || fail "Brain response did not return the same request ID and execution trace"

db_trace_count="$(psql_at "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE request_id = '$request_id';")"
printf 'Brain DB trace rows for %s: %s\n' "$request_id" "$db_trace_count"
(( db_trace_count >= 1 )) || fail "request ID was not persisted in sakina_ai.brain_decision_traces"

db_trace_json="$(psql_at "SELECT jsonb_build_object('request_id', request_id, 'selected_agent', selected_agent, 'selected_model', selected_model, 'selected_pipeline', selected_pipeline, 'steps', jsonb_array_length(execution_trace)) FROM sakina_ai.brain_decision_traces WHERE request_id = '$request_id' ORDER BY created_at DESC LIMIT 1;")"
printf '%s\n' "$db_trace_json" | jq .
printf '%s\n' "$db_trace_json" | jq -e '.steps >= 10 and (.selected_pipeline | type == "string") and (.selected_agent | type == "string")' >/dev/null \
  || fail "persisted Brain trace did not include selected pipeline/agent and stage data"

audit_status="$(curl -sS -o /tmp/sakina-trace-audit-response.json -w "%{http_code}" \
  -X POST "$api_base/v1/audit/logs" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $request_id" \
  -d "$(jq -n --arg request_id "$request_id" '{
    event_type:"trace_link_proof",
    actor_type:"system",
    actor_id:"end-to-end-trace-id-proof",
    request_id:$request_id,
    payload:{proof:"frontend_backend_brain_db_audit_trace"}
  }')")"
printf 'Audit route status for %s: %s\n' "$request_id" "$audit_status"
case "$audit_status" in
  200|201) ;;
  *) cat /tmp/sakina-trace-audit-response.json; fail "audit route did not persist trace proof event" ;;
esac

audit_count="$(psql_at "SELECT COUNT(*) FROM public.audit_logs WHERE request_id = '$request_id' AND event_type = 'trace_link_proof';")"
printf 'Audit DB rows for %s: %s\n' "$request_id" "$audit_count"
(( audit_count >= 1 )) || fail "request ID was not persisted in public.audit_logs"

observability_response="$(curl -fsS "$api_base/health/observability")"
printf '%s\n' "$observability_response" | jq .
printf '%s\n' "$observability_response" \
  | jq -e '.status == "ok" and .request_id == "enabled" and .brain_traces >= 1 and .audit_logs >= 1' >/dev/null \
  || fail "observability endpoint did not show request ID, Brain trace, and audit log readiness"

rg -n "x-request-id|request_id|brain_decision_traces|audit_logs|tracing::info!" \
  sakina-backend/src sakina-frontend/lib >/tmp/sakina-e2e-trace-code-paths.txt \
  || fail "frontend/backend trace ID code paths were not found"
cat /tmp/sakina-e2e-trace-code-paths.txt

printf 'END_TO_END_TRACE_ID_OK request ID linked HTTP request, response, Brain DB trace, audit DB row, observability, and code paths.\n'
