#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'PII_REDACTION_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
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
export VLLM_URL="${VLLM_URL:-http://localhost:18080}"
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
backend_log_file="${TMPDIR:-/tmp}/sakina-pii-redaction-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

wait_ready() {
  local url="$1"
  local attempts="$2"
  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

cargo test --manifest-path sakina-backend/Cargo.toml pii_redaction -- --nocapture
cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$backend_log_file"
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_ready "$api_base/health/ready" 180 \
    || fail "backend did not become ready; log: $backend_log_file"
fi

pii_email="pii-proof-user@example.com"
pii_phone="07700900123"
pii_response="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg message "My email is $pii_email and my phone is $pii_phone. What dua can I read for patience?" '{message:$message,language:"en",user_subscription_tier:"premium"}')")"

printf '%s\n' "$pii_response" | jq .
printf '%s\n' "$pii_response" | jq -e '
  (.execution_trace[] | select(.step == "pii_redaction" and .outcome == "applied"))
  and (.execution_trace[] | select(.step == "prompt_injection_guard" and .outcome == "clear"))
' >/dev/null \
  || fail "Brain trace did not record PII redaction while allowing safe prompt"

if printf '%s\n' "$pii_response" | grep -F "$pii_email"; then
  fail "Brain response leaked raw email PII"
fi
if printf '%s\n' "$pii_response" | grep -F "$pii_phone"; then
  fail "Brain response leaked raw phone PII"
fi

if [[ -f "$backend_log_file" ]]; then
  if grep -F "$pii_email" "$backend_log_file"; then
    fail "backend log leaked raw email PII: $backend_log_file"
  fi
  if grep -F "$pii_phone" "$backend_log_file"; then
    fail "backend log leaked raw phone PII: $backend_log_file"
  fi
fi

rg -n "redact_pii|pii_redaction|REDACTED_EMAIL|REDACTED_NUMBER" \
  sakina-backend/src/services/pii_redaction.rs \
  sakina-backend/src/services/brain_controller.rs \
  sakina-backend/src/services/multimodal.rs \
  || fail "PII redaction is not wired through Brain and multimodal code paths"

printf 'PII_REDACTION_OK Brain trace applies PII redaction, raw PII is absent from response/logs, and multimodal uses the shared redactor.\n'
