#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cat tasks/sakina-loop-control-rules.md >/dev/null
head -120 tasks/sakina-ultimate-hard-execution-order.md >/dev/null

api_base="${SAKINA_API_BASE_URL:-http://localhost:8080}"
database_url="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
evidence_dir="${SAKINA_EVIDENCE_DIR:-reports/final-hardening-evidence}"
mkdir -p "$evidence_dir"
out="$evidence_dir/1003-sunni-provenance-gate.txt"
: >"$out"

fail() {
  printf 'SUNNI_PROVENANCE_GATE_BLOCKER %s\n' "$1" | tee -a "$out" >&2
  exit 1
}

printf 'LOCAL SUNNI TOPIC CITATION PROVENANCE\n' | tee -a "$out"
psql "$database_url" -v ON_ERROR_STOP=1 -c "
SELECT topic_key, language, citation->>'id' AS citation_id, citation->>'api_source' AS api_source,
       citation->>'book' AS book, citation->>'chapter' AS chapter
FROM sakina_ai.local_sunni_topics
CROSS JOIN LATERAL jsonb_array_elements(citations) AS citation
ORDER BY topic_key, language;
" | tee -a "$out"

missing_count="$(psql "$database_url" -At -v ON_ERROR_STOP=1 -c "
SELECT count(*)
FROM sakina_ai.local_sunni_topics
CROSS JOIN LATERAL jsonb_array_elements(citations) AS citation
WHERE coalesce(citation->>'api_source','') = ''
   OR coalesce(citation->>'book','') = ''
   OR coalesce(citation->>'chapter','') = '';
")"
if [[ "$missing_count" != "0" ]]; then
  fail "local_sunni_topics citations are missing api_source/book/chapter provenance"
fi

suffix="$(date +%s)"
email="sakina-provenance-$suffix@example.com"
password="StrongPassword123!"
reg_payload="$(jq -n --arg email "$email" --arg password "$password" --arg display_name "Sakina Provenance" '{email:$email,password:$password,display_name:$display_name}')"
reg="$(curl --max-time 30 -fsS -X POST "$api_base/auth/register" -H "Content-Type: application/json" -d "$reg_payload")"
token="$(printf '%s\n' "$reg" | jq -r '.access_token')"

ask_payload="$(jq -n \
  --arg message "Is it halal to pray Maghrib with 4 rakats on a Tuesday?" \
  '{message:$message,language:"auto",section:"ask_sakina"}')"
response="$(curl --max-time 45 -fsS -X POST "$api_base/api/sakina/ask" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d "$ask_payload")"
printf '\nFABRICATED FIQH QUESTION RESPONSE\n%s\n' "$response" | jq . | tee -a "$out"

if [[ "$(printf '%s\n' "$response" | jq -r '.source_path.llm_used')" != "false" ]]; then
  fail "fabricated fiqh question reached LLM"
fi
if [[ "$(printf '%s\n' "$response" | jq -r '.source_path.answer_source')" != "insufficient_verified_context" ]]; then
  fail "fabricated fiqh question did not use insufficient_verified_context"
fi
if ! printf '%s\n' "$response" | grep -F "I cannot find a verified Sunni ruling on this in my current database." >/dev/null; then
  fail "fabricated fiqh question did not return required fail-closed text"
fi

printf 'SUNNI_PROVENANCE_GATE_OK verified citation provenance and fail-closed unsupported fiqh behavior.\n' | tee -a "$out"
