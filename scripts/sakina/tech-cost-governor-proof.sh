#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'COST_GOVERNOR_BLOCKER %s\n' "$1" >&2
  exit 1
}

command -v cargo >/dev/null 2>&1 || fail "cargo is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v rg >/dev/null 2>&1 || fail "rg is required"

if [[ -f tasks/AGENTS.md ]]; then cat tasks/AGENTS.md >/dev/null; fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export CARGO_TARGET_DIR
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-cost-governor-backend.log"
cleanup() {
  set +e
  if [[ "$started_backend" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

cargo test --manifest-path sakina-backend/Cargo.toml cost_governor -- --nocapture \
  > reports/final-hardening-evidence/710-cost-governor-cargo-tests.txt 2>&1 \
  || fail "cost governor unit tests failed or are missing: reports/final-hardening-evidence/710-cost-governor-cargo-tests.txt"

if ! curl -fsS "$BASE_URL/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  for _ in $(seq 1 180); do
    if curl -fsS "$BASE_URL/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi
curl -fsS "$BASE_URL/health/ready" >/dev/null \
  || fail "backend did not become ready for cost governor proof; log: $backend_log_file"

response="$(curl -fsS -X POST "$BASE_URL/api/brain/trace" \
  -H "Content-Type: application/json" \
  -d '{"message":"What is prayer while travelling?","language":"en","user_subscription_tier":"free"}')"
printf '%s\n' "$response" | jq . > reports/final-hardening-evidence/710-cost-governor-brain-trace.json
printf '%s\n' "$response" | jq -e '.execution_trace[] | select(.step == "cost_governor" and (.outcome | contains("estimated_units=")))' >/dev/null \
  || fail "Brain trace did not include cost governor stage"

blocked_message="$(python3 - <<'PY'
print("explain " + ("zakat " * 7000))
PY
)"
blocked_response="$(jq -n --arg message "$blocked_message" '{message:$message,language:"en",user_subscription_tier:"free"}' \
  | curl -fsS -X POST "$BASE_URL/api/brain/trace" -H "Content-Type: application/json" -d @-)"
printf '%s\n' "$blocked_response" | jq . > reports/final-hardening-evidence/710-cost-governor-block-trace.json
printf '%s\n' "$blocked_response" | jq -e '.can_generate == false and (.execution_trace[] | select(.step == "cost_governor" and (.outcome | contains("decision=block"))))' >/dev/null \
  || fail "over-budget request was not blocked by Brain cost governor"

rg -n "cost_governor|evaluate_cost_budget|estimated_units|budget_units" sakina-backend/src/services/brain_controller.rs \
  > reports/final-hardening-evidence/710-cost-governor-code-paths.txt \
  || fail "cost governor code path is missing"

printf 'COST_GOVERNOR_OK Brain cost governor estimates cost, records trace, and blocks over-budget requests.\n'
