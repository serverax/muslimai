#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MULTIMODAL_AI_BLOCKER %s\n' "$1" >&2
  exit 1
}

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

required=(
  "multimodal-frontend-proof.sh"
  "multimodal-security-proof.sh"
  "multimodal-brain-rag-proof.sh"
  "multimodal-live-end-to-end-proof.sh"
  "multimodal-release-permissions-proof.sh"
)

for script in "${required[@]}"; do
  path="scripts/sakina/$script"
  [[ -f "$path" ]] || fail "missing required multimodal proof script: $path"
  bash "$path"
done

printf 'MULTIMODAL_AI_OK LIVE AND END-TO-END PROVEN.\n'
