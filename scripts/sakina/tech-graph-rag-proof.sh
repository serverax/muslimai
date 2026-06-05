#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'GRAPH_RAG_BLOCKER %s\n' "$1" >&2
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
log_file="${TMPDIR:-/tmp}/sakina-graph-rag-proof.log"

cleanup() {
  if [[ "${started_backend}" = "1" ]]; then
    set +e
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
    set -e
  fi
}

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

entities="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.knowledge_graph_entities;")"
edges="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.knowledge_graph_edges;")"
printf 'Graph entities=%s edges=%s\n' "$entities" "$edges"
if (( entities < 3 )); then
  fail "knowledge_graph_entities has fewer than 3 rows"
fi
if (( edges < 2 )); then
  fail "knowledge_graph_edges has fewer than 2 rows"
fi

kg_health="$(curl -fsS "$api_base/api/kg/health")"
printf '%s\n' "$kg_health" | jq .
printf '%s\n' "$kg_health" | jq -e '.ready == true and .entities_table == true and .edges_table == true' >/dev/null \
  || fail "knowledge graph health is not ready"

kg_response="$(curl -fsS -X POST "$api_base/api/kg/entity" \
  -H "Content-Type: application/json" \
  -d '{"query":"Ayat al-Kursi"}')"
printf '%s\n' "$kg_response" | jq .
printf '%s\n' "$kg_response" | jq -e '.focus_entity.entity_name == "Ayat al-Kursi"' >/dev/null \
  || fail "knowledge graph lookup did not resolve Ayat al-Kursi"
printf '%s\n' "$kg_response" | jq -e '.connected_nodes | length >= 2' >/dev/null \
  || fail "knowledge graph lookup did not traverse connected nodes"
printf '%s\n' "$kg_response" | jq -e '.graph_path | length >= 3' >/dev/null \
  || fail "knowledge graph lookup did not expose graph path"
printf '%s\n' "$kg_response" | jq -e '.citations | index("Quran 2:255") != null' >/dev/null \
  || fail "knowledge graph lookup did not return source citation"

hybrid_response="$(curl -fsS -X POST "$api_base/api/rag/search" \
  -H "Content-Type: application/json" \
  -d '{"query":"Ayat al-Kursi","language":"en"}')"
printf '%s\n' "$hybrid_response" | jq .
printf '%s\n' "$hybrid_response" | jq -e '.retrieval_strategy == "keyword+vector+graph"' >/dev/null \
  || fail "hybrid RAG did not report graph retrieval strategy"
printf '%s\n' "$hybrid_response" | jq -e '.graph_path | type == "array" and length >= 3' >/dev/null \
  || fail "hybrid RAG did not include graph traversal path"
printf '%s\n' "$hybrid_response" | jq -e '.citations | type == "array" and length > 0' >/dev/null \
  || fail "hybrid RAG did not include graph citations"

rg -n "graph\\.lookup|graph_path|keyword\\+vector\\+graph|KnowledgeGraphService" \
  sakina-backend/src/services/hybrid_rag.rs sakina-backend/src/handlers/rag.rs >/tmp/sakina-graph-rag-code-path.txt \
  || fail "Graph RAG code path does not show runtime traversal wiring"
cat /tmp/sakina-graph-rag-code-path.txt

printf 'GRAPH_RAG_OK mandatory Graph RAG proof checks completed.\n'
