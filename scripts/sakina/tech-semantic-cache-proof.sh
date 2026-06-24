#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'SEMANTIC_CACHE_BLOCKER %s\n' "$1" >&2
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
started_backend=0
started_embeddings=0
log_file="${TMPDIR:-/tmp}/sakina-semantic-cache-proof.log"
embedding_log_file="${TMPDIR:-/tmp}/sakina-semantic-cache-embedding-provider.log"
marker=""
chunk_id=""
original_chunk_text_file="${TMPDIR:-/tmp}/sakina-semantic-cache-original-chunk.txt"

cleanup() {
  set +e
  if [[ -n "$marker" && -n "$chunk_id" && -s "$original_chunk_text_file" ]]; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q <<SQL
UPDATE sakina_ai.islamic_chunks
SET chunk_text = :'original_text'
WHERE id = '$chunk_id'::uuid;
SQL
  fi
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

user_a="11111111-1111-4111-8111-111111111111"
user_b="22222222-2222-4222-8222-222222222222"
question="Quran 2:184 mentions allowances around fasting for a limited number of days and references concession for illness or travel with later make-up days."

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DELETE FROM sakina_ai.brain_cache_metadata WHERE user_id IN ('$user_a'::uuid, '$user_b'::uuid);"

payload_a="$(jq -n --arg question "$question" --arg user_id "$user_a" '{question:$question, language:"en", user_id:$user_id, top_k:5, min_score:0.1}')"
first_response="$(curl -fsS -X POST "$api_base/v1/islamic/ask" -H "Content-Type: application/json" -d "$payload_a")"
printf '%s\n' "$first_response" | jq .
printf '%s\n' "$first_response" | jq -e '.cache_status == "miss" and .cache_hit == false' >/dev/null \
  || fail "first Islamic answer request was not a semantic cache miss"
printf '%s\n' "$first_response" | jq -e '.cache_ttl_seconds == 86400' >/dev/null \
  || fail "semantic cache response did not expose TTL"
printf '%s\n' "$first_response" | jq -e '.generated_from_verified_sources == true and (.citations | length > 0)' >/dev/null \
  || fail "cacheable answer did not include verified source-backed citations"

second_response="$(curl -fsS -X POST "$api_base/v1/islamic/ask" -H "Content-Type: application/json" -d "$payload_a")"
printf '%s\n' "$second_response" | jq .
printf '%s\n' "$second_response" | jq -e '.cache_status == "hit" and .cache_hit == true and .cache_hit_count >= 1' >/dev/null \
  || fail "second Islamic answer request was not a semantic cache hit"
printf '%s\n' "$second_response" | jq -e '.generated_from_verified_sources == true and (.citations | length > 0)' >/dev/null \
  || fail "cached answer did not preserve source-backed safety evidence"

payload_b="$(jq -n --arg question "$question" --arg user_id "$user_b" '{question:$question, language:"en", user_id:$user_id, top_k:5, min_score:0.1}')"
user_b_response="$(curl -fsS -X POST "$api_base/v1/islamic/ask" -H "Content-Type: application/json" -d "$payload_b")"
printf '%s\n' "$user_b_response" | jq .
printf '%s\n' "$user_b_response" | jq -e '.cache_status == "miss" and .cache_hit == false' >/dev/null \
  || fail "user B read user A semantic cache entry instead of getting an isolated miss"

cache_rows="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*), COUNT(DISTINCT cache_key), COUNT(DISTINCT user_id) FROM sakina_ai.brain_cache_metadata WHERE user_id IN ('$user_a'::uuid, '$user_b'::uuid);")"
printf 'Semantic cache row proof: %s\n' "$cache_rows"
IFS='|' read -r row_count key_count user_count <<<"$cache_rows"
if (( row_count < 2 || key_count < 2 || user_count < 2 )); then
  fail "semantic cache did not persist separate user-scoped rows"
fi

before_sensitive_rows="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_cache_metadata WHERE user_id = '$user_a'::uuid;")"
sensitive_payload="$(jq -n --arg user_id "$user_a" '{question:"medical diagnosis and legal fatwa for illness while fasting", language:"en", user_id:$user_id, top_k:5, min_score:0.1}')"
sensitive_status="$(curl -sS -o /tmp/sakina-semantic-sensitive.json -w '%{http_code}' -X POST "$api_base/v1/islamic/ask" -H "Content-Type: application/json" -d "$sensitive_payload")"
cat /tmp/sakina-semantic-sensitive.json | jq .
after_sensitive_rows="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_cache_metadata WHERE user_id = '$user_a'::uuid;")"
printf 'Sensitive request HTTP status: %s rows before=%s after=%s\n' "$sensitive_status" "$before_sensitive_rows" "$after_sensitive_rows"
if [[ "$before_sensitive_rows" != "$after_sensitive_rows" ]]; then
  fail "sensitive/high-risk answer was written to semantic cache"
fi

chunk_id="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT id FROM sakina_ai.islamic_chunks WHERE citation_text = 'Quran 2:184' ORDER BY created_at DESC LIMIT 1;")"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT chunk_text FROM sakina_ai.islamic_chunks WHERE id = '$chunk_id'::uuid;" >"$original_chunk_text_file"
marker="semantic-cache-source-version-$(date +%s)-$RANDOM"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "UPDATE sakina_ai.islamic_chunks SET chunk_text = chunk_text || ' $marker' WHERE id = '$chunk_id'::uuid;"

source_change_response="$(curl -fsS -X POST "$api_base/v1/islamic/ask" -H "Content-Type: application/json" -d "$payload_a")"
printf '%s\n' "$source_change_response" | jq .
printf '%s\n' "$source_change_response" | jq -e '.cache_status == "miss" and .cache_hit == false' >/dev/null \
  || fail "source content change did not invalidate semantic cache key"

original_text="$(cat "$original_chunk_text_file")"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v original_text="$original_text" -q <<SQL
UPDATE sakina_ai.islamic_chunks
SET chunk_text = :'original_text'
WHERE id = '$chunk_id'::uuid;
SQL
marker=""

stats_response="$(curl -fsS "$api_base/api/cache/stats")"
printf '%s\n' "$stats_response" | jq .
printf '%s\n' "$stats_response" | jq -e '.status == "ok" and .entries >= 2 and .hits >= 1' >/dev/null \
  || fail "semantic cache metrics did not report real entries and hits"

rg -n "source_version|TTL_SECONDS|updated_at > now\\(\\)|cache_status|cache_hit|user_id: request.user_id|is_cacheable" \
  sakina-backend/src/services/semantic_cache.rs sakina-backend/src/services/islamic_knowledge.rs >/tmp/sakina-semantic-cache-code-path.txt \
  || fail "semantic cache code path does not show TTL, user scope, invalidation, hit/miss, and safety checks"
cat /tmp/sakina-semantic-cache-code-path.txt

printf 'SEMANTIC_CACHE_OK mandatory semantic cache proof checks completed.\n'
