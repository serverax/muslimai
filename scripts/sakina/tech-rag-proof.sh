#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'RAG_TECH_BLOCKER %s\n' "$1" >&2
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
export QDRANT_COLLECTION="${QDRANT_COLLECTION:-sakina_islamic_chunks_en}"
export VLLM_URL="${VLLM_URL:-http://localhost:18080}"
export REDIS_URL="${REDIS_URL:-redis://localhost:6380}"
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
qdrant_base="${QDRANT_URL%/}"
started_backend=0
started_embeddings=0
log_file="${TMPDIR:-/tmp}/sakina-rag-proof.log"
embedding_log_file="${TMPDIR:-/tmp}/sakina-local-embedding-provider.log"

cleanup() {
  if [[ "${started_embeddings}" = "1" ]]; then
    set +e
    kill "$embedding_pid" 2>/dev/null
    wait "$embedding_pid" 2>/dev/null
    set -e
  fi
  if [[ "${started_backend}" = "1" ]]; then
    set +e
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
    set -e
  fi
}

if ! curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
  rm -f "$embedding_log_file"
  python3 scripts/sakina/local_feature_hash_embedding_provider.py >"$embedding_log_file" 2>&1 &
  embedding_pid=$!
  started_embeddings=1
  trap cleanup EXIT

  for _ in $(seq 1 60); do
    if curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

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

curl -fsS "$qdrant_base/collections" | jq . \
  || fail "Qdrant collections endpoint is not reachable"

curl -fsS "$qdrant_base/collections" \
  | jq -e --arg collection "$QDRANT_COLLECTION" '.result.collections[]? | select(.name == $collection)' >/dev/null \
  || fail "required Qdrant collection is missing: $QDRANT_COLLECTION"

curl -fsS "$VLLM_URL/v1/models" | jq . \
  || fail "embedding provider /v1/models is not reachable at $VLLM_URL"

embedding_probe="$(curl -fsS -X POST "$VLLM_URL/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d '{"model":"sakina-local-embedding","input":"Can I shorten prayers while travelling?"}')"
printf '%s\n' "$embedding_probe" | jq .
printf '%s\n' "$embedding_probe" | jq -e '.data[0].embedding | type == "array" and length >= 8' >/dev/null \
  || fail "embedding provider did not return a vector"

python3 scripts/sakina/index-approved-rag-corpus.py

source_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.islamic_chunks WHERE review_status IN ('verified','approved') AND source_status = 'approved';")"
if (( source_count < 10 )); then
  fail "fewer than 10 approved Islamic chunks exist in Postgres"
fi
printf 'Approved Islamic chunks in DB: %s\n' "$source_count"

request_id="rag-proof-$(date +%s)-$RANDOM"
rag_user_id="00000000-0000-0000-0000-000000000001"
before_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces;")"
rag_response="$(curl -fsS -X POST "$api_base/v1/rag/query" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $request_id" \
  -H "x-sakina-subscription-tier: premium" \
  -d "{\"query\":\"Quran 2:184 mentions allowances around fasting for a limited number of days and references concession for illness or travel with later make-up days.\",\"user_id\":\"$rag_user_id\",\"madhhab_filter\":\"all\"}")"
printf '%s\n' "$rag_response" | jq .

printf '%s\n' "$rag_response" | jq -e '.guardrail_triggered == false' >/dev/null \
  || fail "RAG query was blocked by guardrail or weak evidence"
printf '%s\n' "$rag_response" | jq -e '.sources | type == "array" and length > 0' >/dev/null \
  || fail "RAG query did not return citations/source references"
printf '%s\n' "$rag_response" | jq -e '.confidence > 0' >/dev/null \
  || fail "RAG query did not return a positive confidence"

after_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces;")"
if (( after_count <= before_count )); then
  fail "RAG query did not pass through Brain or persist a decision trace"
fi

rg -n "aia\\.route|EmbeddingsService|QdrantVectorDB|source_from_payload|guardrails\\.check" sakina-backend/src/handlers/rag.rs sakina-backend/src/services/hybrid_rag.rs \
  >/tmp/sakina-rag-code-path.txt \
  || fail "RAG handler/service code path does not show Brain, embeddings, Qdrant, and guardrail wiring"
cat /tmp/sakina-rag-code-path.txt

printf 'RAG_TECH_OK mandatory RAG proof checks completed.\n'
