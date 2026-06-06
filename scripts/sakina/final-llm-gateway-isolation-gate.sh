#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cat tasks/sakina-loop-control-rules.md >/dev/null
head -120 tasks/sakina-ultimate-hard-execution-order.md >/dev/null

evidence_dir="${SAKINA_EVIDENCE_DIR:-reports/final-hardening-evidence}"
mkdir -p "$evidence_dir"
out="$evidence_dir/1004-llm-gateway-isolation-gate.txt"
: >"$out"

fail() {
  printf 'LLM_GATEWAY_ISOLATION_BLOCKER %s\n' "$1" | tee -a "$out" >&2
  exit 1
}

printf 'DIRECT OLLAMA ACCESS SCAN\n' | tee -a "$out"
matches="$(rg -n "OLLAMA_BASE_URL|http://ollama:11434|localhost:11434|/api/generate|/api/tags" \
  sakina-backend/src infra/k8s/sakina-mobile-staging sakina-frontend/lib .github || true)"
printf '%s\n' "$matches" | tee -a "$out"

bad_matches="$(printf '%s\n' "$matches" | awk '
  /sakina-backend\/src\/bin\/llm_gateway.rs/ { next }
  /infra\/k8s\/sakina-mobile-staging\/llm-gateway.yaml/ { next }
  /^$/ { next }
  { print }
')"
if [[ -n "$bad_matches" ]]; then
  printf '\nDISALLOWED DIRECT OLLAMA ACCESS\n%s\n' "$bad_matches" | tee -a "$out" >&2
  fail "direct Ollama access exists outside sakina-llm-gateway"
fi

printf '\nKUBERNETES MANIFEST CHECK\n' | tee -a "$out"
rg -n "name: sakina-llm-gateway|command:|sakina-llm-gateway|/ready|/health|OLLAMA_BASE_URL" \
  infra/k8s/sakina-mobile-staging/llm-gateway.yaml | tee -a "$out"

printf '\nBACKEND GATEWAY CONFIG CHECK\n' | tee -a "$out"
rg -n "SAKINA_LLM_GATEWAY_URL|sakina-llm-gateway:8087" \
  sakina-backend/src infra/k8s/sakina-mobile-staging/backend.yaml | tee -a "$out"

printf 'LLM_GATEWAY_ISOLATION_GATE_OK direct Ollama access is isolated to sakina-llm-gateway source and deployment manifest.\n' | tee -a "$out"
