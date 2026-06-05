#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

fail() {
  printf 'BRAIN_WORKFLOW_GATE_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"

required_scripts=(
  "tech-brain-orchestrator-proof.sh"
  "tech-agentic-workflow-proof.sh"
  "tech-rag-proof.sh"
  "tech-graph-rag-proof.sh"
  "tech-hybrid-search-proof.sh"
  "tech-source-trust-ranking-proof.sh"
  "tech-context-compression-proof.sh"
  "tech-ai-router-proof.sh"
  "tech-evaluation-ai-proof.sh"
  "tech-citation-hallucination-validator-proof.sh"
  "tech-policy-as-code-proof.sh"
  "tech-prompt-injection-proof.sh"
  "tech-cost-governor-proof.sh"
  "tech-human-review-queue-proof.sh"
  "end-to-end-trace-id-proof.sh"
  "e2e-real-user-journey.sh"
)

for script in "${required_scripts[@]}"; do
  path="scripts/sakina/$script"
  evidence="reports/final-hardening-evidence/brain-workflow-${script}.txt"
  if [[ ! -f "$path" ]]; then
    printf 'Missing required Brain workflow proof script: %s\n' "$path" > "$evidence"
    fail "missing required Brain workflow proof script: $path"
  fi
  bash "$path" > "$evidence" 2>&1
done

if [[ ! -f reports/final-hardening-evidence/234-mobile-to-backend-to-db-e2e-proof.txt ]]; then
  fail "missing frontend-to-backend-to-DB runtime evidence from wiring gate"
fi

printf 'BRAIN_WORKFLOW_GATE_OK Brain/AIA/RAG/safety workflow proof scripts exited successfully.\n'
