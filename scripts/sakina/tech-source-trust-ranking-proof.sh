#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'SOURCE_TRUST_RANKING_BLOCKER %s\n' "$1" >&2
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
embedding_log_file="${TMPDIR:-/tmp}/sakina-source-trust-embedding-provider.log"
backend_log_file="${TMPDIR:-/tmp}/sakina-source-trust-backend.log"
untrusted_key="source-trust-proof-untrusted-$(date +%s)-$RANDOM"

cleanup() {
  set +e
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DELETE FROM sakina_ai.islamic_chunks WHERE chunk_key = '${untrusted_key}-chunk'; DELETE FROM sakina_ai.islamic_documents WHERE document_key = '${untrusted_key}-doc'; DELETE FROM sakina_ai.islamic_sources WHERE source_key = '${untrusted_key}-source';" >/dev/null 2>&1
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

curl -fsS "${QDRANT_URL%/}/collections" | jq . >/dev/null \
  || fail "Qdrant collections endpoint is not reachable"

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

trusted_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d '{"query":"Quran 2:184 mentions allowances around fasting for illness or travel and later make-up days.","language":"en","top_k":5}')"
printf '%s\n' "$trusted_response" | jq .

printf '%s\n' "$trusted_response" | jq -e '.retrieval_strategy == "keyword+vector+graph"' >/dev/null \
  || fail "source trust proof did not run through hybrid RAG"
printf '%s\n' "$trusted_response" | jq -e '.retrieved_chunks | length > 0' >/dev/null \
  || fail "trusted source query returned no chunks"
printf '%s\n' "$trusted_response" | jq -e 'all(.retrieved_chunks[]; (.review_status == "verified" or .review_status == "approved") and .source_trust_score > 0)' >/dev/null \
  || fail "retrieved chunks are not all approved/verified with source_trust_score"
printf '%s\n' "$trusted_response" | jq -e 'any(.retrieved_chunks[]; .source_type == "quran" and .source_trust_score == 1)' >/dev/null \
  || fail "Quran source did not receive highest source trust score"
printf '%s\n' "$trusted_response" | jq -e 'any(.source_ranking[]; test("trust="))' >/dev/null \
  || fail "source ranking did not expose trust decision"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
WITH source_row AS (
  INSERT INTO sakina_ai.islamic_sources (
    source_key, source_type, source_status, language, title, review_status
  )
  VALUES (
    '${untrusted_key}-source', 'internal-approved', 'pending', 'en',
    'Untrusted Source Trust Proof Source', 'pending'
  )
  RETURNING id
),
document_row AS (
  INSERT INTO sakina_ai.islamic_documents (
    source_id, document_key, title, source_type, language, source_status, review_status
  )
  SELECT id, '${untrusted_key}-doc', 'Untrusted Source Trust Proof Document',
         'internal-approved', 'en', 'pending', 'pending'
  FROM source_row
  RETURNING id
)
INSERT INTO sakina_ai.islamic_chunks (
  document_id, chunk_key, chunk_index, chunk_text, citation_text,
  source_type, language, source_status, review_status
)
SELECT id, '${untrusted_key}-chunk', 0,
       'SOURCE_TRUST_NEGATIVE_UNVERIFIED_${untrusted_key} unsafe unsupported citation claim',
       'Untrusted proof citation', 'internal-approved', 'en', 'pending', 'pending'
FROM document_row;
SQL

untrusted_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"SOURCE_TRUST_NEGATIVE_UNVERIFIED_${untrusted_key}\",\"language\":\"en\",\"top_k\":5}")"
printf '%s\n' "$untrusted_response" | jq .

printf '%s\n' "$untrusted_response" | jq -e --arg key "SOURCE_TRUST_NEGATIVE_UNVERIFIED_${untrusted_key}" 'all(.retrieved_chunks[]?; (.chunk_text | contains($key) | not))' >/dev/null \
  || fail "unverified source chunk was returned by RAG search"

rg -n "source_trust_score|fn source_trust_score|fn recompute_final_score|trust=" sakina-backend/src/services/hybrid_rag.rs \
  || fail "hybrid RAG code does not show source trust scoring and ranking"

printf 'SOURCE_TRUST_RANKING_OK source trust scoring affects hybrid RAG output and unverified content is filtered.\n'
