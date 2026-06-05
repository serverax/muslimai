#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'QDRANT_VECTOR_DB_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd rg

export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export QDRANT_COLLECTION="${QDRANT_COLLECTION:-sakina_islamic_chunks_en}"

qdrant_base="${QDRANT_URL%/}"
evidence_dir="reports/final-hardening-evidence"
mkdir -p "$evidence_dir"

collections_json="$(curl -fsS "$qdrant_base/collections")" \
  || fail "Qdrant collections endpoint is not reachable"
printf '%s\n' "$collections_json" | jq .
printf '%s\n' "$collections_json" \
  | jq -e --arg collection "$QDRANT_COLLECTION" '.result.collections[]? | select(.name == $collection)' >/dev/null \
  || fail "Qdrant collection is missing: $QDRANT_COLLECTION"

collection_info="$(curl -fsS "$qdrant_base/collections/$QDRANT_COLLECTION")" \
  || fail "Qdrant collection info endpoint is not reachable"
printf '%s\n' "$collection_info" | jq .
vector_size="$(printf '%s\n' "$collection_info" | jq -r '.result.config.params.vectors.size')"
points_count="$(printf '%s\n' "$collection_info" | jq -r '.result.points_count')"
status="$(printf '%s\n' "$collection_info" | jq -r '.result.status')"
if [[ "$status" != "green" ]]; then
  fail "Qdrant collection is not green: $status"
fi
if [[ "$vector_size" == "null" || "$vector_size" -le 0 ]]; then
  fail "Qdrant collection vector size is invalid: $vector_size"
fi
if [[ "$points_count" -le 0 ]]; then
  fail "Qdrant collection has no vectors/points"
fi
printf 'Qdrant collection=%s vector_size=%s points_count=%s status=%s\n' \
  "$QDRANT_COLLECTION" "$vector_size" "$points_count" "$status"

payload_check="$(curl -fsS -X POST "$qdrant_base/collections/$QDRANT_COLLECTION/points/scroll" \
  -H "Content-Type: application/json" \
  -d '{"limit":3,"with_payload":true,"with_vector":false}')"
printf '%s\n' "$payload_check" | jq .
printf '%s\n' "$payload_check" \
  | jq -e '.result.points[]? | select(.payload.source_id and .payload.chunk_id and .payload.title and .payload.review_status)' >/dev/null \
  || fail "Qdrant payload metadata is missing source/chunk/title/review fields"

proof_id="11111111-1111-4111-8111-$(date +%s%N | tail -c 13)"
proof_vector="$(jq -cn --argjson size "$vector_size" '[range(0; $size) | ((. + 1) / $size)]')"
upsert_payload="$(jq -cn \
  --arg id "$proof_id" \
  --argjson vector "$proof_vector" \
  '{points:[{id:$id,vector:$vector,payload:{source_id:"qdrant-proof-source",chunk_id:$id,title:"Qdrant Runtime Proof",review_status:"verified",language:"en",proof:true}}]}')"
curl -fsS -X PUT "$qdrant_base/collections/$QDRANT_COLLECTION/points?wait=true" \
  -H "Content-Type: application/json" \
  -d "$upsert_payload" | jq .

search_payload="$(jq -cn --argjson vector "$proof_vector" '{vector:$vector,limit:5,with_payload:true}')"
search_response="$(curl -fsS -X POST "$qdrant_base/collections/$QDRANT_COLLECTION/points/search" \
  -H "Content-Type: application/json" \
  -d "$search_payload")"
printf '%s\n' "$search_response" | jq .
printf '%s\n' "$search_response" \
  | jq -e --arg id "$proof_id" '.result[]? | select(.id == $id and .payload.proof == true and .score > 0)' >/dev/null \
  || fail "Qdrant search did not return the upserted proof vector"

wrong_vector="$(jq -cn --argjson size "$vector_size" '[range(0; ($size + 1)) | 0.01]')"
wrong_payload="$(jq -cn --arg id "22222222-2222-4222-8222-222222222222" --argjson vector "$wrong_vector" \
  '{points:[{id:$id,vector:$vector,payload:{proof:true}}]}')"
wrong_status="$(curl -sS -o /tmp/sakina-qdrant-wrong-dimension.json -w '%{http_code}' \
  -X PUT "$qdrant_base/collections/$QDRANT_COLLECTION/points?wait=true" \
  -H "Content-Type: application/json" \
  -d "$wrong_payload")"
cat /tmp/sakina-qdrant-wrong-dimension.json
printf '\nWrong-dimension upsert HTTP status: %s\n' "$wrong_status"
if [[ "$wrong_status" -lt 400 ]]; then
  fail "Qdrant accepted a wrong-dimension vector"
fi
if ! grep -Eiq 'dimension|vector|expected|wrong' /tmp/sakina-qdrant-wrong-dimension.json; then
  fail "wrong-dimension rejection did not report a vector dimension error"
fi

delete_payload="$(jq -cn --arg id "$proof_id" '{points:[$id]}')"
curl -fsS -X POST "$qdrant_base/collections/$QDRANT_COLLECTION/points/delete?wait=true" \
  -H "Content-Type: application/json" \
  -d "$delete_payload" | jq .
post_delete_search="$(curl -fsS -X POST "$qdrant_base/collections/$QDRANT_COLLECTION/points/search" \
  -H "Content-Type: application/json" \
  -d "$search_payload")"
printf '%s\n' "$post_delete_search" | jq .
if printf '%s\n' "$post_delete_search" | jq -e --arg id "$proof_id" '.result[]? | select(.id == $id)' >/dev/null; then
  fail "Qdrant proof vector remained searchable after delete"
fi

curl -fsS "$qdrant_base/collections" \
  >"$evidence_dir/430-qdrant-metadata-export.json" \
  || fail "Qdrant metadata export failed"
jq -e '.result.collections | type == "array"' "$evidence_dir/430-qdrant-metadata-export.json" >/dev/null \
  || fail "Qdrant metadata export is invalid JSON"

rg -n "qdrant.*== \"ok\"|snapshot\\[\"qdrant\"\\]|qdrant_reachable|QDRANT_URL|collections/.*/points" \
  sakina-backend/src/main.rs sakina-backend/src/services/qdrant_client.rs scripts/sakina/index-approved-rag-corpus.py \
  >/tmp/sakina-qdrant-code-path.txt \
  || fail "Qdrant runtime/readiness/upsert/search code path was not found"
cat /tmp/sakina-qdrant-code-path.txt

printf 'QDRANT_VECTOR_DB_OK collection, vectors, metadata, upsert, search, wrong-dimension rejection, delete/reindex, readiness wiring, and export proof completed.\n'
