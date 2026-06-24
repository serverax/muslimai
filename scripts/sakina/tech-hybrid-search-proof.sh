#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'HYBRID_SEARCH_BLOCKER %s\n' "$1" >&2
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

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

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
qdrant_base="${QDRANT_URL%/}"
started_backend=0
started_embeddings=0
log_file="${TMPDIR:-/tmp}/sakina-hybrid-search-proof.log"
embedding_log_file="${TMPDIR:-/tmp}/sakina-hybrid-embedding-provider.log"

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
  set -e
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

start_embeddings_if_needed() {
  if curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
    return 0
  fi
  rm -f "$embedding_log_file"
  python3 scripts/sakina/local_feature_hash_embedding_provider.py >"$embedding_log_file" 2>&1 &
  embedding_pid=$!
  started_embeddings=1
  wait_ready "$VLLM_URL/v1/models" 60 \
    || fail "local embedding provider did not become reachable; log: $embedding_log_file"
}

build_backend() {
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api
}

start_backend() {
  local mode="$1"
  rm -f "$log_file"
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_ready "$api_base/health/ready" 180 \
    || fail "backend did not become ready for $mode; log: $log_file"
}

stop_backend_if_started() {
  if [[ "${started_backend}" = "1" ]]; then
    set +e
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
    set -e
    started_backend=0
  fi
}

if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  external_backend=1
else
  external_backend=0
fi

start_embeddings_if_needed
curl -fsS "$qdrant_base/collections" | jq . \
  || fail "Qdrant collections endpoint is not reachable"

python3 scripts/sakina/index-approved-rag-corpus.py

source_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.islamic_chunks WHERE review_status IN ('verified','approved') AND source_status = 'approved';")"
if (( source_count < 10 )); then
  fail "fewer than 10 approved Islamic chunks exist in Postgres"
fi
printf 'Approved Islamic chunks in DB: %s\n' "$source_count"

collection_info="$(curl -fsS "$qdrant_base/collections/$QDRANT_COLLECTION")"
printf '%s\n' "$collection_info" | jq .
printf '%s\n' "$collection_info" | jq -e '.result.points_count > 0' >/dev/null \
  || fail "Qdrant collection has no indexed vectors"

build_backend
if [[ "$external_backend" = "0" ]]; then
  start_backend "positive hybrid search"
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend readiness did not report ready"

keyword_vector_payload="$(jq -n \
  --arg query "Quran 2:184 mentions allowances around fasting for a limited number of days and references concession for illness or travel with later make-up days." \
  --arg language "en" \
  '{query:$query, language:$language}')"
keyword_vector_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d "$keyword_vector_payload")"
printf '%s\n' "$keyword_vector_response" | jq .
printf '%s\n' "$keyword_vector_response" | jq -e '.retrieval_strategy == "keyword+vector+graph"' >/dev/null \
  || fail "hybrid endpoint did not report keyword+vector+graph strategy"
printf '%s\n' "$keyword_vector_response" | jq -e '.retrieved_chunks | length > 0' >/dev/null \
  || fail "hybrid endpoint did not return retrieved chunks"
printf '%s\n' "$keyword_vector_response" | jq -e 'any(.retrieved_chunks[]; .keyword_score > 0)' >/dev/null \
  || fail "hybrid endpoint did not show lexical scoring"
printf '%s\n' "$keyword_vector_response" | jq -e 'any(.retrieved_chunks[]; .vector_score > 0)' >/dev/null \
  || fail "hybrid endpoint did not show vector scoring"
printf '%s\n' "$keyword_vector_response" | jq -e '.source_ranking | length > 0' >/dev/null \
  || fail "hybrid endpoint did not expose source ranking"
printf '%s\n' "$keyword_vector_response" | jq -e 'all(.retrieved_chunks[]; .final_score >= 0)' >/dev/null \
  || fail "hybrid endpoint did not expose final ranking scores"
printf '%s\n' "$keyword_vector_response" | jq -e '([.retrieved_chunks[].chunk_id] | length) == ([.retrieved_chunks[].chunk_id] | unique | length)' >/dev/null \
  || fail "hybrid endpoint returned duplicate chunks after merge"

vector_only_payload="$(jq -n \
  --arg query "illness travel make up days fasting concession" \
  --arg language "en" \
  '{query:$query, language:$language}')"
vector_only_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d "$vector_only_payload")"
printf '%s\n' "$vector_only_response" | jq .
printf '%s\n' "$vector_only_response" | jq -e '.retrieved_chunks | length > 0' >/dev/null \
  || fail "vector fallback did not retrieve DB-backed chunks for lexical miss"
printf '%s\n' "$vector_only_response" | jq -e 'all(.retrieved_chunks[]; .keyword_score == 0)' >/dev/null \
  || fail "vector fallback query unexpectedly matched lexical full-query search"
printf '%s\n' "$vector_only_response" | jq -e 'any(.retrieved_chunks[]; .vector_score > 0)' >/dev/null \
  || fail "vector fallback did not expose vector score"

if [[ "$external_backend" = "1" ]]; then
  fail "external backend was already running, so controlled embedding-failure fallback cannot be proven on port 8080"
fi

stop_backend_if_started
export VLLM_URL="http://127.0.0.1:18081"
start_backend "embedding failure fallback"

keyword_only_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d "$keyword_vector_payload")"
printf '%s\n' "$keyword_only_response" | jq .
printf '%s\n' "$keyword_only_response" | jq -e '.retrieved_chunks | length > 0' >/dev/null \
  || fail "keyword fallback did not retrieve chunks when embedding provider was unavailable"
printf '%s\n' "$keyword_only_response" | jq -e 'any(.retrieved_chunks[]; .keyword_score > 0)' >/dev/null \
  || fail "keyword fallback did not expose lexical score"
printf '%s\n' "$keyword_only_response" | jq -e 'all(.retrieved_chunks[]; .vector_score == 0)' >/dev/null \
  || fail "keyword fallback reported vector scores while embedding provider was unavailable"

rg -n "keyword_search|vector_search|chunks.extend\\(vector_only_chunks\\)|best_by_chunk|final_score|dedup|retrieval_strategy: \\\"keyword\\+vector\\+graph\\\"" \
  sakina-backend/src/services/hybrid_rag.rs >/tmp/sakina-hybrid-search-code-path.txt \
  || fail "hybrid service code path does not show keyword, vector, merge, de-duplication, and ranking wiring"
cat /tmp/sakina-hybrid-search-code-path.txt

printf 'HYBRID_SEARCH_OK mandatory hybrid search proof checks completed.\n'
