#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

fail() {
  printf 'ADVANCED_TECH_GATE_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"

matrix="reports/final-hardening-evidence/sakina-all-advanced-technologies-implementation-matrix.md"
[[ -s "$matrix" ]] || fail "missing master advanced technology implementation matrix: $matrix"

required=(
  "300:tech-brain-orchestrator-proof.sh"
  "310:tech-agentic-workflow-proof.sh"
  "320:tech-rag-proof.sh"
  "330:tech-graph-rag-proof.sh"
  "340:tech-hybrid-search-proof.sh"
  "580:tech-source-trust-ranking-proof.sh"
  "480:tech-citation-hallucination-validator-proof.sh"
  "470:tech-policy-as-code-proof.sh"
  "370:tech-context-compression-proof.sh"
  "380:tech-ai-router-proof.sh"
  "390:tech-evaluation-ai-proof.sh"
  "350:tech-semantic-cache-proof.sh"
  "590:tech-redis-valkey-cache-proof.sh"
  "420:tech-wasm-proof.sh"
  "400:tech-mcp-connectors-proof.sh"
  "440:tech-event-outbox-proof.sh"
  "490:tech-observability-stack-proof.sh"
  "600:tech-owasp-api-security-proof.sh"
  "610:tech-owasp-masvs-mobile-proof.sh"
  "620:tech-sast-sca-container-proof.sh"
  "630:tech-kubernetes-restricted-proof.sh"
  "640:tech-prompt-injection-proof.sh"
  "650:tech-pii-redaction-proof.sh"
  "660:tech-data-retention-deletion-proof.sh"
  "670:tech-backup-disaster-recovery-proof.sh"
  "680:tech-load-performance-proof.sh"
  "690:tech-canary-rollout-proof.sh"
  "700:tech-crash-reporting-proof.sh"
  "710:tech-cost-governor-proof.sh"
  "720:tech-human-review-queue-proof.sh"
  "410:tech-multimodal-ai-proof.sh"
)

for item in "${required[@]}"; do
  id="${item%%:*}"
  script="scripts/sakina/${item#*:}"
  evidence="reports/final-hardening-evidence/${id}-${item#*:}.txt"
  if [[ ! -f "$script" ]]; then
    printf 'Missing required advanced technology proof script: %s\n' "$script" > "$evidence"
    fail "missing required advanced technology proof script: $script"
  fi
  bash "$script" > "$evidence" 2>&1
done

if grep -E "NOT ACCEPTED|BLOCKER|MISSING|PARTIAL|LOCAL ONLY|MOCKED|PLACEHOLDER|SAFE DISABLED" "$matrix" > reports/final-hardening-evidence/730-advanced-matrix-blockers.txt; then
  fail "advanced technology matrix still contains non-accepted statuses: reports/final-hardening-evidence/730-advanced-matrix-blockers.txt"
fi

printf 'ADVANCED_TECH_GATE_OK all advanced technology proof scripts and matrix acceptance checks exited successfully.\n'
