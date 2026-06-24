#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'CONTEXT_COMPRESSION_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
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
started_embeddings=0
log_file="${TMPDIR:-/tmp}/sakina-context-compression-proof.log"
embedding_log_file="${TMPDIR:-/tmp}/sakina-context-compression-embedding-provider.log"

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

cargo test --manifest-path sakina-backend/Cargo.toml \
  services::context_compression::tests::compression_deduplicates_and_preserves_citations \
  -- --nocapture

if ! curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
  rm -f "$embedding_log_file"
  python3 scripts/sakina/local_feature_hash_embedding_provider.py >"$embedding_log_file" 2>&1 &
  embedding_pid=$!
  started_embeddings=1
  wait_ready "$VLLM_URL/v1/models" 60 \
    || fail "local embedding provider did not become reachable; log: $embedding_log_file"
fi

python3 scripts/sakina/index-approved-rag-corpus.py

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$log_file"
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_ready "$api_base/health/ready" 180 \
    || fail "backend did not become ready; log: $log_file"
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend readiness did not report ready"

payload="$(jq -n \
  --arg query "Quran 2:184 mentions allowances around fasting for a limited number of days and references concession for illness or travel with later make-up days." \
  '{query:$query, language:"en"}')"
response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d "$payload")"
printf '%s\n' "$response" | jq .

printf '%s\n' "$response" | jq -e '.compressed_tokens_before > .compressed_tokens_after' >/dev/null \
  || fail "live RAG response did not show reduced context size"
printf '%s\n' "$response" | jq -e '.compression_ratio > 0 and .compression_ratio < 1' >/dev/null \
  || fail "live RAG response did not expose a valid compression ratio below 1"
printf '%s\n' "$response" | jq -e '.citations | length > 0' >/dev/null \
  || fail "compression path did not preserve citations"
printf '%s\n' "$response" | jq -e '.retrieved_chunks | length > 0' >/dev/null \
  || fail "compression path did not preserve retrieved source IDs"
printf '%s\n' "$response" | jq -e '.weak_evidence_blocked == false' >/dev/null \
  || fail "compression path removed or altered safety evidence state"
printf '%s\n' "$response" | jq -e '.citations[] | select(.chapter == "Quran 2:184")' >/dev/null \
  || fail "answer context after compression did not cite the expected source"

rg -n "compress_text|preserved_citations|compressed_tokens_before|compressed_tokens_after|compression_ratio|weak_evidence_blocked" \
  sakina-backend/src/services/context_compression.rs sakina-backend/src/services/hybrid_rag.rs sakina-backend/src/handlers/rag.rs >/tmp/sakina-context-compression-code-path.txt \
  || fail "context compression code path does not show compression metrics, citation preservation, and safety fields"
cat /tmp/sakina-context-compression-code-path.txt

printf 'CONTEXT_COMPRESSION_OK mandatory context compression proof checks completed.\n'
