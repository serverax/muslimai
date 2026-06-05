#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'AGENT_FEEDBACK_EXPORT_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql

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
run_id="agent-feedback-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-agent-feedback-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/migrations/019_agent_feedback.sql

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

credential="$(printf '%s%s%s' 'Strong' 'Password' '123!')"
register_user() {
  local email="$1"
  curl -fsS -X POST "$api_base/auth/register" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg email "$email" --arg credential "$credential" '{
      email:$email,
      password:$credential,
      display_name:"Agent Feedback Proof User"
    }')"
}

register_a="$(register_user "$run_id-a@example.com")"
register_b="$(register_user "$run_id-b@example.com")"
token_a="$(printf '%s\n' "$register_a" | jq -r '.access_token')"
token_b="$(printf '%s\n' "$register_b" | jq -r '.access_token')"
user_a="$(printf '%s\n' "$register_a" | jq -r '.user_id')"
user_b="$(printf '%s\n' "$register_b" | jq -r '.user_id')"
[[ "$token_a" == *.*.* && "$token_b" == *.*.* ]] || fail "registration did not return JWTs"

trace_id="$run_id-trace"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v trace_id="$trace_id" \
  -v user_id="$user_a" <<'SQL'
INSERT INTO sakina_ai.brain_decision_traces (
    request_id, user_id, input_type, intent, language, risk_level,
    selected_agent, selected_model, selected_pipeline, source_strategy,
    evaluation_result, final_action, audit_event_id, execution_trace
)
VALUES (
    :'trace_id',
    :'user_id',
    'question',
    'fiqh',
    'en',
    'safe',
    'Islamic Guidance Agent',
    'lite_llm',
    'mother_brain>agentic_researcher>quran_rag>validator',
    'quran_rag',
    'PASS:0.91',
    'answer_returned',
    'agent-feedback-proof',
    '[{"step":"orchestrator","outcome":"researcher"},{"step":"researcher","outcome":"quran_rag"},{"step":"validator","outcome":"allow"}]'::jsonb
);
SQL

missing_auth_status="$(curl -sS -o /tmp/sakina-agent-feedback-missing-auth.json -w '%{http_code}' \
  -X POST "$api_base/api/agent/feedback" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg trace_id "$trace_id" '{trace_id:$trace_id,rating:true}')")"
printf 'Missing-auth feedback status=%s\n' "$missing_auth_status"
cat /tmp/sakina-agent-feedback-missing-auth.json | jq .
[[ "$missing_auth_status" = "401" ]] || fail "feedback accepted missing JWT"

cross_user_status="$(curl -sS -o /tmp/sakina-agent-feedback-cross-user.json -w '%{http_code}' \
  -X POST "$api_base/api/agent/feedback" \
  -H "Authorization: Bearer $token_b" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg trace_id "$trace_id" '{trace_id:$trace_id,rating:true}')")"
printf 'Cross-user feedback status=%s user_b=%s trace_owner=%s\n' "$cross_user_status" "$user_b" "$user_a"
cat /tmp/sakina-agent-feedback-cross-user.json | jq .
[[ "$cross_user_status" = "401" ]] || fail "feedback accepted cross-user trace"

feedback_response="$(curl -fsS -X POST "$api_base/api/agent/feedback" \
  -H "Authorization: Bearer $token_a" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg trace_id "$trace_id" '{trace_id:$trace_id,rating:true}')")"
printf '%s\n' "$feedback_response" | jq .
printf '%s\n' "$feedback_response" | jq -e --arg trace_id "$trace_id" '.trace_id == $trace_id and .label == "positive" and .feedback_id' >/dev/null \
  || fail "feedback response did not include persisted positive label"

feedback_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.agent_feedback WHERE trace_id = '$trace_id' AND user_id = '$user_a' AND rating = true;")"
printf 'Agent feedback DB rows=%s\n' "$feedback_count"
[[ "$feedback_count" = "1" ]] || fail "agent feedback DB row missing"

dataset_path="reports/final-hardening-evidence/922-agent-gold-dataset.jsonl"
bash scripts/sakina/export-gold-dataset.sh "$dataset_path"
grep -F "$trace_id" "$dataset_path" >/dev/null \
  || fail "gold dataset export does not include feedback trace"

printf 'AGENT_FEEDBACK_EXPORT_OK feedback API requires JWT, blocks cross-user trace labels, persists DB feedback, and exports JSONL gold dataset evidence.\n'
