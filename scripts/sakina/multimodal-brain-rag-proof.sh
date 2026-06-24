#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MULTIMODAL_BRAIN_RAG_BLOCKER %s\n' "$1" >&2
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
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export QDRANT_COLLECTION="${QDRANT_COLLECTION:-sakina_islamic_chunks_en}"
export VLLM_URL="${VLLM_URL:-http://localhost:18080}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
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

api_base="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${api_base%/}"
started_backend=0
started_embeddings=0
backend_log="${TMPDIR:-/tmp}/sakina-mm-brain-rag-api.log"
embedding_log="${TMPDIR:-/tmp}/sakina-mm-brain-rag-embeddings.log"

cleanup() {
  set +e
  if [[ "${started_embeddings}" = "1" ]]; then
    kill "$embedding_pid" 2>/dev/null
    wait "$embedding_pid" 2>/dev/null
  fi
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  set -e
}
trap cleanup EXIT

wait_url() {
  local url="$1"
  for _ in $(seq 1 120); do
    curl -fsS "$url" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

if ! curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
  python3 scripts/sakina/local_feature_hash_embedding_provider.py >"$embedding_log" 2>&1 &
  embedding_pid=$!
  started_embeddings=1
  wait_url "$VLLM_URL/v1/models" || fail "embedding provider did not start; log: $embedding_log"
fi
python3 scripts/sakina/index-approved-rag-corpus.py

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >>"$backend_log" 2>&1
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_url "$api_base/health/ready" || fail "backend did not become ready; log: $backend_log"
fi

rg -n "aia\\.route|answer_islamic|AskIslamicRequest|citations_count|retrieval_strategy|brain_decision_traces" \
  sakina-backend/src/handlers/multimodal.rs sakina-backend/src/services/multimodal.rs sakina-backend/src/services/brain_audit.rs \
  || fail "multimodal code does not show Brain/RAG/trace integration"

suffix="$(date +%s)-$RANDOM"
credential="StrongPassword123!"
register="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "sakina-mm-rag-$suffix@example.com" --arg credential "$credential" '{email:$email,password:$credential,display_name:"MM RAG User"}')")"
access_jwt="$(printf '%s\n' "$register" | jq -r '.access_token')"
user_id="$(printf '%s\n' "$register" | jq -r '.user_id')"
doc_file="$(mktemp)"
printf 'Can I shorten prayers while travelling? Please answer with verified citations.' >"$doc_file"
trace_id="mm-brain-rag-$suffix"
response="$(curl -fsS -X POST "$api_base/v1/api/multimodal/analyze" \
  -H "Authorization: Bearer $access_jwt" \
  -H "x-request-id: $trace_id" \
  -F "asset_type=document" \
  -F "mime_type=text/plain" \
  -F "language=en" \
  -F "file=@$doc_file;filename=travel-prayer.txt;type=text/plain")"
printf '%s\n' "$response" | jq .
printf '%s\n' "$response" | jq -e \
  '.islamic_answer.generated_from_verified_sources == true and (.islamic_answer.citations | length >= 1) and (.islamic_answer.retrieval_strategy | type == "string") and (.islamic_answer.graph_path | type == "array")' >/dev/null \
  || fail "multimodal response skipped RAG/Graph/citation fields"
asset_id="$(printf '%s\n' "$response" | jq -r '.asset_id')"
db_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.multimodal_assets WHERE id = '$asset_id'::uuid AND user_id = '$user_id'::uuid AND (metadata->>'citations_count')::int >= 1 AND metadata->>'retrieval_strategy' IS NOT NULL;")"
[[ "$db_probe" = "1" ]] || fail "DB metadata does not prove multimodal RAG/citation result"
trace_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE request_id = '$trace_id';")"
[[ "$trace_probe" = "1" ]] || fail "Brain decision trace for multimodal request was not persisted"

printf 'MULTIMODAL_BRAIN_RAG_OK multimodal document upload entered Brain, RAG/Graph fields, citations, DB metadata, and trace.\n'
