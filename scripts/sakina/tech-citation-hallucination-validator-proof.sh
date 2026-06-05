#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'CITATION_HALLUCINATION_VALIDATOR_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql
require_cmd python3
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
export VLLM_URL="${VLLM_URL:-http://localhost:18080}"
export SAKINA_FEATURE_QURAN=true
export SAKINA_RAG_QURAN_ENABLED=true
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
started_embeddings=0
embedding_log_file="${TMPDIR:-/tmp}/sakina-citation-validator-embedding-provider.log"
backend_log_file="${TMPDIR:-/tmp}/sakina-citation-validator-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  if [[ "${started_embeddings}" = "1" ]]; then
    kill "$embedding_pid" 2>/dev/null
    wait "$embedding_pid" 2>/dev/null
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

if ! curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
  rm -f "$embedding_log_file"
  python3 scripts/sakina/local_feature_hash_embedding_provider.py >"$embedding_log_file" 2>&1 &
  embedding_pid=$!
  started_embeddings=1
  wait_ready "$VLLM_URL/v1/models" 60 \
    || fail "local embedding provider did not become reachable; log: $embedding_log_file"
fi

python3 scripts/sakina/index-approved-rag-corpus.py

cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null
if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$backend_log_file"
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_ready "$api_base/health/ready" 180 \
    || fail "backend did not become ready; log: $backend_log_file"
fi

rag_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d '{"query":"Quran 2:184 mentions allowances around fasting for illness or travel and later make-up days.","language":"en","top_k":5}')"
printf '%s\n' "$rag_response" | jq .

valid_citation_id="$(printf '%s\n' "$rag_response" | jq -r '.citations[0].id // empty')"
[[ -n "$valid_citation_id" ]] || fail "RAG did not return a citation ID for validator proof"

valid_eval="$(jq -n --arg citation "$valid_citation_id" '{
  answer: "The answer is grounded in the retrieved Islamic source.",
  citations: [$citation],
  language: "en",
  grounded_in_islamic_sources: true,
  safety_level: "safe",
  tone: "calm"
}' | curl -fsS -X POST "$api_base/api/evaluation/check" -H "Content-Type: application/json" -d @-)"
printf '%s\n' "$valid_eval" | jq .
printf '%s\n' "$valid_eval" | jq -e '.review_result == "PASS" and .citation_present == true and .grounding_present == true' >/dev/null \
  || fail "valid DB-backed citation was not accepted by evaluator"

fabricated_eval="$(jq -n '{
  answer: "This answer invents a religious citation.",
  citations: ["00000000-0000-0000-0000-000000000000"],
  language: "en",
  grounded_in_islamic_sources: true,
  safety_level: "safe",
  tone: "calm"
}' | curl -fsS -X POST "$api_base/api/evaluation/check" -H "Content-Type: application/json" -d @-)"
printf '%s\n' "$fabricated_eval" | jq .
printf '%s\n' "$fabricated_eval" | jq -e '.review_result == "FAIL" and .grounding_present == false and (.reason | test("citation validator rejected"))' >/dev/null \
  || fail "fabricated citation was not rejected"

ungrounded_eval="$(jq -n '{
  answer: "This answer gives religious guidance without source support.",
  citations: [],
  language: "en",
  grounded_in_islamic_sources: false,
  safety_level: "safe",
  tone: "calm"
}' | curl -fsS -X POST "$api_base/api/evaluation/check" -H "Content-Type: application/json" -d @-)"
printf '%s\n' "$ungrounded_eval" | jq .
printf '%s\n' "$ungrounded_eval" | jq -e '.review_result == "FAIL"' >/dev/null \
  || fail "ungrounded answer without citations was not rejected"

rg -n "citation_exists|all_citations_exist|citation validator rejected|grounding_present = false" sakina-backend/src/handlers/evaluation.rs \
  || fail "evaluation handler does not show DB-backed citation validation"

printf 'CITATION_HALLUCINATION_VALIDATOR_OK real citations pass and fabricated/ungrounded claims fail.\n'
