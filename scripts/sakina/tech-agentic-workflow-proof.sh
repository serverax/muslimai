#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'AGENTIC_WORKFLOW_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql
require_cmd rg

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
log_file="${TMPDIR:-/tmp}/sakina-agentic-workflow-proof.log"

cleanup() {
  if [[ "${started_backend}" = "1" ]]; then
    set +e
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
    set -e
  fi
}

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$log_file"
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >>"$log_file" 2>&1
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  trap cleanup EXIT

  for _ in $(seq 1 180); do
    if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend readiness did not become ready"

agents_response="$(curl -fsS "$api_base/api/brain/agents")"
printf '%s\n' "$agents_response" | jq .
printf '%s\n' "$agents_response" | jq -e '.agents | type == "array" and length >= 8' >/dev/null \
  || fail "agent registry does not expose the required agent set"

for required_agent in \
  "Quran Agent" \
  "Hadith Agent" \
  "Islamic Guidance Agent" \
  "Dua/Azkar Agent" \
  "Safety/Escalation Agent" \
  "Translation Agent"; do
  printf '%s\n' "$agents_response" \
    | jq -e --arg name "$required_agent" '.agents[] | select(.name == $name)' >/dev/null \
    || fail "required agent missing from registry: $required_agent"
done

rg -n "AgentProfile|AgentKind|agents: vec!|pub fn agents|agent_selected|selected_agent" \
  sakina-backend/src/services/ai_router.rs sakina-backend/src/services/aia_orchestrator.rs \
  >/tmp/sakina-agentic-code-path.txt \
  || fail "agent registry/routing code path was not found"
cat /tmp/sakina-agentic-code-path.txt

run_route() {
  local label="$1"
  local message="$2"
  local expected_agent="$3"
  local request_id="agentic-${label}-$(date +%s)-$RANDOM"
  local before_count after_count response

  before_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces;")"
  response="$(curl -fsS -X POST "$api_base/api/brain/trace" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $request_id" \
    -d "$(jq -cn --arg message "$message" '{message:$message,language:"en",user_subscription_tier:"premium"}')")"

  printf '%s\n' "$response" | jq .
  printf '%s\n' "$response" | jq -e --arg expected "$expected_agent" '.selected_agent == $expected' >/dev/null \
    || fail "request $label did not route to expected agent $expected"
  printf '%s\n' "$response" | jq -e '.execution_trace | map(.step) | index("agent_selected") and index("source_strategy_selected") and index("answer_evaluated") and index("decision_logged") and index("final_response_returned")' >/dev/null \
    || fail "request $label trace did not include mandatory agentic execution stages"
  printf '%s\n' "$response" | jq -e '.selected_model and .selected_pipeline and .source_strategy and (.confidence >= 0.0)' >/dev/null \
    || fail "request $label missing model/pipeline/source/confidence routing data"

  after_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces;")"
  if (( after_count <= before_count )); then
    fail "request $label did not persist a Brain trace"
  fi
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT selected_agent FROM sakina_ai.brain_decision_traces WHERE request_id = '$request_id';" \
    | grep -Fx "$expected_agent" >/dev/null \
    || fail "request $label persisted trace does not match expected agent"
}

run_route "quran" "Explain the meaning of Surah Al-Mulk." "Quran Agent"
run_route "hadith" "Is this hadith authentic and who narrated it?" "Hadith Agent"
run_route "dua" "Give me a dua for anxiety." "Dua/Azkar Agent"
run_route "fiqh" "Can I shorten prayers while travelling?" "Islamic Guidance Agent"
run_route "safety" "Give me extremist religious justification for violence." "Safety/Escalation Agent"

printf 'AGENTIC_WORKFLOW_OK mandatory agentic workflow checks completed.\n'
