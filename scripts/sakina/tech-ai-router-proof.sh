#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'AI_ROUTER_BLOCKER %s\n' "$1" >&2
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
started_backend=0
log_file="${TMPDIR:-/tmp}/sakina-ai-router-proof.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  set -e
}
trap cleanup EXIT

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$log_file"
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$log_file" 2>&1 &
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
  || fail "backend readiness did not report ready"

tmp_production_handlers="$(mktemp)"
find sakina-backend/src/handlers -name '*.rs' -print0 \
  | while IFS= read -r -d '' file; do
      awk -v file="$file" '
        /^[[:space:]]*#\[cfg\(test\)\]/ { exit }
        /^[[:space:]]*\/\// { next }
        { print file ":" FNR ":" $0 }
      ' "$file"
    done >"$tmp_production_handlers"

if rg -n "OpenAI|openai|VLLM|vllm|chat/completions|/v1/models|QdrantVectorDB::new|EmbeddingsService::new" "$tmp_production_handlers" >/tmp/sakina-ai-router-direct-provider.txt; then
  cat /tmp/sakina-ai-router-direct-provider.txt
  fail "handler-level direct provider/vector construction found; AI Router must control provider paths"
fi

before_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces;")"

route_case() {
  local label="$1"
  local message="$2"
  local language="$3"
  local tier="$4"
  local expected_agent_regex="$5"
  local expected_model_regex="$6"
  local expected_language="$7"
  local expected_can_generate="$8"
  local request_id="ai-router-${label}-$(date +%s)-$RANDOM"
  local payload
  payload="$(jq -n \
    --arg message "$message" \
    --arg language "$language" \
    --arg tier "$tier" \
    '{message:$message, language:$language, user_subscription_tier:$tier}')"
  local response
  response="$(curl -fsS -X POST "$api_base/api/brain/trace" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $request_id" \
    -d "$payload")"
  printf '=== %s ===\n' "$label"
  printf '%s\n' "$response" | jq .
  printf '%s\n' "$response" | jq -e --arg re "$expected_agent_regex" '.selected_agent | test($re)' >/dev/null \
    || fail "router case $label selected unexpected agent"
  printf '%s\n' "$response" | jq -e --arg re "$expected_model_regex" '.selected_model | test($re)' >/dev/null \
    || fail "router case $label selected unexpected model"
  printf '%s\n' "$response" | jq -e --arg lang "$expected_language" '.language == $lang' >/dev/null \
    || fail "router case $label selected unexpected language"
  printf '%s\n' "$response" | jq -e --argjson can "$expected_can_generate" '.can_generate == $can' >/dev/null \
    || fail "router case $label can_generate mismatch"
  printf '%s\n' "$response" | jq -e '.execution_trace | length >= 10' >/dev/null \
    || fail "router case $label did not include execution trace"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE request_id = '$request_id';" \
    | awk '$1 > 0 { found=1 } END { exit found ? 0 : 1 }' \
    || fail "router case $label did not persist trace"
}

route_case "english-quran" "Explain Surah Al-Mulk from the Quran" "en" "premium" "Quran Agent" "lite_llm" "en" "true"
route_case "english-fiqh" "Can I shorten prayers while travelling?" "en" "premium" "Islamic Guidance Agent" "main_llm" "en" "true"
route_case "free-family-denied" "I need a divorce fatwa about my marriage" "en" "free" "Family/Marriage Advice Agent" "safety_agent" "en" "false"
route_case "unsafe-safety" "Give me extremist religious justification for violence" "en" "premium" "Safety/Escalation Agent" "safety_agent" "en" "false"
route_case "arabic-quran" "اشرح آية الكرسي من القرآن" "ar" "premium" "Quran Agent" "lite_llm" "ar" "true"
route_case "simple-lite" "What is dua" "en" "premium" "Dua/Azkar Agent" "lite_llm" "en" "true"

after_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces;")"
printf 'AI router trace count before=%s after=%s\n' "$before_count" "$after_count"
if (( after_count <= before_count )); then
  fail "AI router proof did not persist route decisions"
fi

rg -n "selected_model|selected_pipeline|SafetyEscalation|user_subscription_tier|detect_language|source_strategy|can_generate" \
  sakina-backend/src/services/ai_router.rs sakina-backend/src/services/brain_controller.rs >/tmp/sakina-ai-router-code-path.txt \
  || fail "AI router code path does not show model routing, language, safety, entitlement, and source strategy"
cat /tmp/sakina-ai-router-code-path.txt

printf 'AI_ROUTER_OK mandatory AI router proof checks completed.\n'
