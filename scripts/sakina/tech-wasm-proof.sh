#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'WASM_BLOCKER %s\n' "$1" >&2
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
export QDRANT_COLLECTION="${QDRANT_COLLECTION:-sakina_islamic_chunks_en}"
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
wasm_file="sakina-wasm/fatwa-policy-gate/pkg/sakina_fatwa_policy_gate_bg.wasm"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-wasm-proof-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

[[ -s "$wasm_file" ]] || fail "WASM artifact is missing or empty: $wasm_file"
printf 'WASM artifact bytes: '
wc -c <"$wasm_file"

cargo test --manifest-path sakina-wasm/fatwa-policy-gate/Cargo.toml -- --nocapture
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

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready" and .checks.redis_valkey == "ok"' >/dev/null \
  || fail "backend readiness did not report ready with Redis/Valkey; log: $backend_log_file"

trace_response="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -d '{"message":"What is the Islamic guidance for prayer while travelling?","language":"en","user_subscription_tier":"premium"}')"
printf '%s\n' "$trace_response" | jq .
printf '%s\n' "$trace_response" | jq -e '.wasm_required == true and (.selected_pipeline | test("wasm_policy"))' >/dev/null \
  || fail "Brain trace did not require WASM policy stage for Islamic guidance"

request_id="$(cat /proc/sys/kernel/random/uuid)"
event_payload="$(jq -n --arg request_id "$request_id" '{
  request_id: $request_id,
  module_name: "sakina_fatwa_policy_gate",
  decision_type: "fatwa_publication_policy",
  input_hash: "sha256:wasm-proof",
  output_decision: {"decision":"defer_to_scholar","reason":"proof high-risk policy"},
  policy_version: "fatwa-policy-gate-v1",
  runtime_mode: "wasm"
}')"

event_response=""
for path in /v1/safety/wasm-events /safety/wasm-events; do
  if event_response="$(curl -fsS -X POST "$api_base$path" -H "Content-Type: application/json" -d "$event_payload" 2>/dev/null)"; then
    break
  fi
done
[[ -n "$event_response" ]] || fail "WASM verification event route is not reachable"
printf '%s\n' "$event_response" | jq .
event_id="$(printf '%s\n' "$event_response" | jq -r '.id // empty')"
[[ -n "$event_id" ]] || fail "WASM event route did not return an event id"

db_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.wasm_verification_events WHERE request_id = '$request_id' AND runtime_mode = 'wasm';")"
printf 'WASM DB event rows: %s\n' "$db_count"
(( db_count >= 1 )) || fail "WASM verification event was not persisted"

rg -n "sakina_fatwa_policy_gate|evaluate_fatwa_policy|wasm_required|wasm_policy|wasm_verification_events" \
  sakina-backend/src sakina-backend/Cargo.toml sakina-wasm/fatwa-policy-gate/src \
  || fail "WASM policy code path is not wired in backend and WASM crate"

printf 'WASM_OK artifact, crate tests, Brain WASM stage, and DB event proof completed.\n'
