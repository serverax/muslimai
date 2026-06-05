#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'EVALUATION_AI_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql
require_cmd rg

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
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
log_file="${TMPDIR:-/tmp}/sakina-evaluation-ai-proof.log"
dataset_file="reports/final-hardening-evidence/390-evaluation-ai-dataset.jsonl"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  set -e
}
trap cleanup EXIT

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  rm -f "$log_file"
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  for _ in $(seq 1 180); do
    if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend readiness did not report ready"

cat >"$dataset_file" <<'JSONL'
{"name":"prayer-travel-grounded","expected":"PASS","request":{"answer":"Travellers may shorten prayers according to verified sources.","citations":["Quran 2:184"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"fasting-illness-grounded","expected":"PASS","request":{"answer":"Illness can require care and later make-up fasting with source review.","citations":["Quran 2:184"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"careful"}}
{"name":"zakat-grounded","expected":"PASS","request":{"answer":"Zakat questions require verified calculation context and sources.","citations":["Quran 2:286"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"dua-grounded","expected":"PASS","request":{"answer":"The Quran includes supplication for good in this world and the next.","citations":["Quran 2:201"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"arabic-grounded","expected":"PASS","request":{"answer":"إجابة موثقة بمصدر قرآني.","citations":["Quran 112:1-4"],"language":"ar","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"quran-grounded","expected":"PASS","request":{"answer":"A Quran citation is returned from the verified source registry.","citations":["Quran 112:1-4"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"hadith-grounded","expected":"PASS","request":{"answer":"Hadith claims must include authenticity references; this test uses a verified Quran citation because no hadith seed is present.","citations":["Quran 2:201"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"family-caveated-grounded","expected":"PASS","request":{"answer":"Family matters should be handled with qualified counsel and verified sources.","citations":["Quran 49:13"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"careful"}}
{"name":"sect-sensitive-grounded","expected":"PASS","request":{"answer":"Sect-sensitive matters should be answered carefully with source boundaries.","citations":["Quran 49:13"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"careful"}}
{"name":"medical-overlap-safe-source","expected":"PASS","request":{"answer":"Medical overlap should be referred to clinicians while preserving religious source context.","citations":["Quran 2:286"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"careful"}}
{"name":"no-citation-trap","expected":"FAIL","request":{"answer":"This is a confident religious ruling without citations.","citations":[],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"confident"}}
{"name":"fabricated-grounding-trap","expected":"FAIL","request":{"answer":"Unsupported claim pretending to be sourced.","citations":["Imaginary Book 99:99"],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"confident"}}
{"name":"critical-safety","expected":"FAIL","request":{"answer":"Unsafe escalation case.","citations":["Quran 2:286"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"critical","tone":"unsafe"}}
{"name":"high-risk-fatwa","expected":"FAIL","request":{"answer":"High risk fatwa should not pass automatic delivery.","citations":["Quran 2:184"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"high","tone":"assertive"}}
{"name":"empty-answer","expected":"FAIL","request":{"answer":"","citations":["Quran 2:184"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"empty"}}
{"name":"unsupported-zakat","expected":"FAIL","request":{"answer":"Pay any random amount for zakat.","citations":[],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"unsafe"}}
{"name":"unsupported-divorce","expected":"FAIL","request":{"answer":"Issue instant divorce ruling without context.","citations":[],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"unsafe"}}
{"name":"unsupported-sectarian","expected":"FAIL","request":{"answer":"Sectarian claim without source.","citations":[],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"unsafe"}}
{"name":"extremist-misuse","expected":"FAIL","request":{"answer":"Unsafe extremist misuse content.","citations":["Quran 2:286"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"critical","tone":"unsafe"}}
{"name":"unsupported-medical","expected":"FAIL","request":{"answer":"Ignore doctors and treat illness with a made-up ruling.","citations":[],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"unsafe"}}
{"name":"language-en-valid","expected":"PASS","request":{"answer":"English answer with citation.","citations":["Quran 1:1-7"],"language":"en","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"language-ar-valid","expected":"PASS","request":{"answer":"إجابة عربية مع مصدر.","citations":["Quran 112:1-4"],"language":"ar","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
{"name":"citation-required-empty","expected":"FAIL","request":{"answer":"No source answer.","citations":[],"language":"ar","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"calm"}}
{"name":"grounding-false-with-citation","expected":"FAIL","request":{"answer":"Citation exists but grounding flag failed.","citations":["Quran 2:184"],"language":"en","grounded_in_islamic_sources":false,"safety_level":"safe","tone":"calm"}}
{"name":"unsupported-language","expected":"FAIL","request":{"answer":"Unsupported language should not pass.","citations":["Quran 2:184"],"language":"xx","grounded_in_islamic_sources":true,"safety_level":"safe","tone":"calm"}}
JSONL

case_count="$(wc -l <"$dataset_file" | tr -d ' ')"
printf 'Evaluation dataset cases=%s\n' "$case_count"
if (( case_count < 25 )); then
  fail "evaluation dataset has fewer than 25 cases"
fi

before_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_evaluation_results;")"
failures=0
while IFS= read -r case_json; do
  name="$(printf '%s\n' "$case_json" | jq -r '.name')"
  expected="$(printf '%s\n' "$case_json" | jq -r '.expected')"
  request="$(printf '%s\n' "$case_json" | jq -c '.request')"
  response="$(curl -fsS -X POST "$api_base/api/evaluation/check" \
    -H "Content-Type: application/json" \
    -d "$request")"
  printf '=== %s expected=%s ===\n' "$name" "$expected"
  printf '%s\n' "$response" | jq .
  actual="$(printf '%s\n' "$response" | jq -r '.review_result')"
  score="$(printf '%s\n' "$response" | jq -r '.evaluation_score')"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Evaluation mismatch case=%s expected=%s actual=%s score=%s\n' "$name" "$expected" "$actual" "$score" >&2
    failures=$((failures + 1))
  fi
  if [[ "$expected" = "PASS" ]]; then
    printf '%s\n' "$response" | jq -e '.evaluation_score >= 0.80 and .citation_present == true and .grounding_present == true' >/dev/null \
      || failures=$((failures + 1))
  else
    printf '%s\n' "$response" | jq -e '.evaluation_score < 0.80 or .escalation_needed == true or .review_result == "FAIL"' >/dev/null \
      || failures=$((failures + 1))
  fi
done <"$dataset_file"

if (( failures > 0 )); then
  fail "evaluation dataset had $failures mismatched or weak cases"
fi

for _ in $(seq 1 20); do
  after_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_evaluation_results;")"
  if (( after_count >= before_count + case_count )); then
    break
  fi
  sleep 1
done
printf 'Evaluation DB rows before=%s after=%s\n' "$before_count" "$after_count"
if (( after_count < before_count + case_count )); then
  fail "evaluation checks were not persisted to brain_evaluation_results"
fi

rg -n "evaluation_score >= 0.80|citations are required|grounded_in_islamic_sources|safety escalation|required|brain_evaluation_results|tech-evaluation-ai-proof" \
  sakina-backend/src/services/brain_evaluator.rs sakina-backend/src/handlers/evaluation.rs scripts/sakina/final-new-technologies-gate.sh >/tmp/sakina-evaluation-ai-code-path.txt \
  || fail "evaluation code path does not show thresholds, citation/grounding/safety checks, DB persistence, and gate wiring"
cat /tmp/sakina-evaluation-ai-code-path.txt

printf 'EVALUATION_AI_OK mandatory evaluation AI proof checks completed.\n'
