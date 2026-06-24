#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"

required=(
  "300:tech-brain-orchestrator-proof.sh"
  "310:tech-agentic-workflow-proof.sh"
  "320:tech-rag-proof.sh"
  "330:tech-graph-rag-proof.sh"
  "340:tech-hybrid-search-proof.sh"
  "350:tech-semantic-cache-proof.sh"
  "360:tech-memory-engine-proof.sh"
  "370:tech-context-compression-proof.sh"
  "380:tech-ai-router-proof.sh"
  "390:tech-evaluation-ai-proof.sh"
  "400:tech-mcp-connectors-proof.sh"
  "410:tech-multimodal-ai-proof.sh"
  "420:tech-wasm-proof.sh"
  "430:tech-qdrant-vector-db-proof.sh"
  "440:tech-event-outbox-proof.sh"
  "450:tech-realtime-notifications-proof.sh"
  "460:tech-feature-flags-entitlements-proof.sh"
  "470:tech-policy-as-code-proof.sh"
  "480:tech-citation-hallucination-validator-proof.sh"
  "490:tech-observability-stack-proof.sh"
  "500:tech-secrets-management-proof.sh"
  "510:tech-zero-trust-api-proof.sh"
  "520:tech-payments-entitlements-proof.sh"
  "530:tech-offline-resilience-proof.sh"
  "540:tech-i18n-arabic-english-proof.sh"
  "550:tech-store-compliance-proof.sh"
  "560:new-technologies-master-matrix-proof.sh"
)

for item in "${required[@]}"; do
  id="${item%%:*}"
  script="scripts/sakina/${item#*:}"
  evidence="reports/final-hardening-evidence/${id}-${item#*:}.txt"
  if [[ ! -f "$script" ]]; then
    printf 'NEW_TECH_GATE_BLOCKER missing required proof script: %s\n' "$script" >&2
    printf 'Missing required proof script: %s\n' "$script" > "$evidence"
    exit 1
  fi
  bash "$script" > "$evidence" 2>&1
done

printf 'NEW_TECH_GATE_OK all new technology subchecks exited successfully.\n'
