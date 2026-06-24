#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cat tasks/sakina-loop-control-rules.md >/dev/null
head -120 tasks/sakina-ultimate-hard-execution-order.md >/dev/null

evidence_dir="${SAKINA_EVIDENCE_DIR:-reports/final-hardening-evidence}"
mkdir -p "$evidence_dir"
out="$evidence_dir/1005-llm-gateway-local-runtime-proof.txt"
log="$evidence_dir/1005-llm-gateway-local-runtime.log"
: >"$out"
: >"$log"

gateway_bin="${CARGO_TARGET_DIR:-/mnt/f/tmp/sakina-target}/debug/sakina-llm-gateway"
if [[ ! -x "$gateway_bin" ]]; then
  CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/mnt/f/tmp/sakina-target}" cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-llm-gateway
fi

SAKINA_LLM_MODEL="${SAKINA_LLM_MODEL:-qwen2.5:3b}" \
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}" \
SAKINA_LLM_TIMEOUT_SECONDS="${SAKINA_LLM_TIMEOUT_SECONDS:-60}" \
SAKINA_LLM_GATEWAY_BIND="${SAKINA_LLM_GATEWAY_BIND:-127.0.0.1:18087}" \
"$gateway_bin" >"$log" 2>&1 &
pid="$!"
trap 'kill "$pid" >/dev/null 2>&1 || true' EXIT
sleep 3

base="http://127.0.0.1:18087"

printf 'HEALTH\n' | tee -a "$out"
curl -fsS "$base/health" | jq . | tee -a "$out"

printf '\nREADY\n' | tee -a "$out"
curl -fsS "$base/ready" | jq . | tee -a "$out"

printf '\nREJECT MISSING TRACE/WORKSPACE\n' | tee -a "$out"
status="$(curl -sS -o /tmp/sakina-llm-missing-id.json -w "%{http_code}" \
  -X POST "$base/generate" \
  -H "Content-Type: application/json" \
  -d '{"trace_id":"","workspace_id":"","language":"en","intent":"new_muslim","user_stage":"new_muslim","safe_user_message":"I am new","local_db_context":"verified context","rag_context":"","graph_context":"","safety_flags":["pii_removed=false"]}')"
printf 'HTTP %s\n' "$status" | tee -a "$out"
cat /tmp/sakina-llm-missing-id.json | jq . | tee -a "$out"
if [[ "$status" != "400" ]]; then
  printf 'Expected HTTP 400 for missing trace/workspace, got %s\n' "$status" >&2
  exit 1
fi

printf '\nREJECT NO CONTEXT\n' | tee -a "$out"
status="$(curl -sS -o /tmp/sakina-llm-no-context.json -w "%{http_code}" \
  -X POST "$base/generate" \
  -H "Content-Type: application/json" \
  -d '{"trace_id":"trace-no-context","workspace_id":"workspace-no-context","language":"en","intent":"new_muslim","user_stage":"new_muslim","safe_user_message":"I am new","local_db_context":"","rag_context":"","graph_context":"","safety_flags":["pii_removed=false"]}')"
printf 'HTTP %s\n' "$status" | tee -a "$out"
cat /tmp/sakina-llm-no-context.json | jq . | tee -a "$out"
if [[ "$status" != "400" ]]; then
  printf 'Expected HTTP 400 for no context, got %s\n' "$status" >&2
  exit 1
fi

printf '\nGENERATE WITH CONTROLLED CONTEXT\n' | tee -a "$out"
curl -fsS -X POST "$base/generate" \
  -H "Content-Type: application/json" \
  -d '{"trace_id":"trace-local-gateway","workspace_id":"workspace-local-gateway","language":"en","intent":"new_muslim","user_stage":"new_muslim","safe_user_message":"I am a new Muslim and feel overwhelmed.","local_db_context":"Verified local context: begin with shahadah, learn wudu and salah gradually, and connect with a trusted mosque.","rag_context":"","graph_context":"","safety_flags":["pii_removed=false","answer_only_from_allowed_context"]}' \
  | jq '{provider,model,used,status,latency_ms,has_answer:(.answer | length > 0),token_usage}' | tee -a "$out"

printf '\nGATEWAY LOG TAIL\n' | tee -a "$out"
tail -40 "$log" | tee -a "$out"
