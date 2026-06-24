#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'SAKINA_RAG_SMOKE_FAIL: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql

if [[ -z "${DATABASE_URL:-}" ]]; then
  fail "DATABASE_URL is required"
fi
if [[ -z "${QDRANT_URL:-}" ]]; then
  fail "QDRANT_URL is required"
fi
if [[ -z "${VLLM_URL:-}" ]]; then
  fail "VLLM_URL is required"
fi
if [[ -z "${SAKINA_API_BASE_URL:-}" ]]; then
  fail "SAKINA_API_BASE_URL is required"
fi

api_base="${SAKINA_API_BASE_URL%/}"
qdrant_base="${QDRANT_URL%/}"
vllm_base="${VLLM_URL%/}"

echo "=== database readiness ==="
for sql in \
  "SELECT count(*) FROM sakina_ai.islamic_sources;" \
  "SELECT count(*) FROM sakina_ai.islamic_documents;" \
  "SELECT count(*) FROM sakina_ai.islamic_chunks;" \
  "SELECT count(*) FROM sakina_ai.islamic_embeddings;"
do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "$sql"
done

echo "=== backend health ==="
curl -fsS "$api_base/health" | jq .
curl -fsS "$api_base/ready" | jq .

echo "=== vector and embedding health ==="
if curl -fsS "$qdrant_base/health" | jq .; then
  :
else
  curl -fsS "$qdrant_base/collections" | jq .
fi
[[ "$vllm_base" != mock://* ]] || fail "VLLM_URL must point to a real embedding/model service"
curl -fsS "$vllm_base/v1/models" | jq .

echo "=== rag status ==="
curl -fsS "$api_base/v1/rag/status" | jq .

echo "=== rag sources ==="
curl -fsS \
  -H 'x-sakina-module: quran' \
  -H 'x-sakina-subscription-tier: premium' \
  "$api_base/v1/rag/sources?module=quran" | jq .

safe_query_ar="هل يمكن قراءة الأذكار من الهاتف؟"
safe_query_en="Can I read dhikr from my phone?"
sensitive_question="Should I issue a fatwa without verified sources?"
smoke_user_id="$(cat /proc/sys/kernel/random/uuid)"

echo "=== arabic query ==="
arabic_resp="$(
  curl -fsS -X POST "$api_base/v1/rag/query" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg query "$safe_query_ar" --arg user_id "$smoke_user_id" --arg madhhab_filter "" '{query:$query,user_id:$user_id,madhhab_filter:$madhhab_filter}')"
)"
printf '%s\n' "$arabic_resp" | jq .
[[ "$(printf '%s\n' "$arabic_resp" | jq '.sources | length')" -gt 0 ]] || fail "Arabic query returned no sources"
[[ "$(printf '%s\n' "$arabic_resp" | jq '.confidence')" != "0" ]] || fail "Arabic query confidence is zero"

echo "=== english query ==="
english_resp="$(
  curl -fsS -X POST "$api_base/v1/rag/query" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg query "$safe_query_en" --arg user_id "$smoke_user_id" --arg madhhab_filter "" '{query:$query,user_id:$user_id,madhhab_filter:$madhhab_filter}')"
)"
printf '%s\n' "$english_resp" | jq .
[[ "$(printf '%s\n' "$english_resp" | jq '.sources | length')" -gt 0 ]] || fail "English query returned no sources"
[[ "$(printf '%s\n' "$english_resp" | jq '.confidence')" != "0" ]] || fail "English query confidence is zero"

echo "=== safety/evidence gate ==="
safety_resp="$(
  curl -fsS -X POST "$api_base/v1/rag/decide" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n \
      --arg question "$sensitive_question" \
      --arg selected_module "knowledge" \
      --arg language "en" \
      --arg user_subscription_tier "premium" \
      '{question:$question,selected_module:$selected_module,language:$language,user_subscription_tier:$user_subscription_tier,safety_context:null}')"
)"
printf '%s\n' "$safety_resp" | jq .
[[ "$(printf '%s\n' "$safety_resp" | jq '.requires_scholar_review')" == "true" ]] || fail "Sensitive question did not trigger scholar review"

echo "SAKINA_RAG_SMOKE_PASS"
