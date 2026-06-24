#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'EXPORT_GOLD_DATASET_BLOCKER %s\n' "$1" >&2
  exit 1
}

command -v psql >/dev/null 2>&1 || fail "required command missing: psql"

DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
OUTPUT_PATH="${1:-reports/final-hardening-evidence/agent-gold-dataset.jsonl}"
mkdir -p "$(dirname "$OUTPUT_PATH")"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "
SELECT jsonb_build_object(
    'trace_id', f.trace_id,
    'rating', f.rating,
    'label', f.label,
    'feedback_created_at', f.created_at,
    'request_id', b.request_id,
    'intent', b.intent,
    'language', b.language,
    'risk_level', b.risk_level,
    'selected_agent', b.selected_agent,
    'selected_model', b.selected_model,
    'selected_pipeline', b.selected_pipeline,
    'source_strategy', b.source_strategy,
    'evaluation_result', b.evaluation_result,
    'final_action', b.final_action,
    'execution_trace', b.execution_trace
)::text
FROM sakina_ai.agent_feedback f
JOIN sakina_ai.brain_decision_traces b ON b.request_id = f.trace_id
ORDER BY f.created_at DESC;
" > "$OUTPUT_PATH"

line_count="$(wc -l < "$OUTPUT_PATH" | tr -d ' ')"
printf 'GOLD_DATASET_EXPORTED path=%s rows=%s\n' "$OUTPUT_PATH" "$line_count"
