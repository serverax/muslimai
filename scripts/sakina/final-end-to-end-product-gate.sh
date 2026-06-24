#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

fail() {
  printf 'END_TO_END_PRODUCT_GATE_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"

run_gate() {
  local name="$1"
  shift
  local evidence="reports/final-hardening-evidence/product-${name}.txt"
  "$@" > "$evidence" 2>&1
}

run_gate "final-wiring-gate" bash scripts/sakina/final-wiring-gate.sh
run_gate "final-new-technologies-gate" bash scripts/sakina/final-new-technologies-gate.sh
run_gate "final-advanced-technologies-gate" bash scripts/sakina/final-advanced-technologies-gate.sh
run_gate "final-brain-workflow-gate" bash scripts/sakina/final-brain-workflow-gate.sh
run_gate "final-security-performance-gate" bash scripts/sakina/final-security-performance-gate.sh
run_gate "final-closed-beta-gate" bash scripts/sakina/final-closed-beta-gate.sh

if [[ ! -d sakina-frontend/ios ]]; then
  fail "missing sakina-frontend/ios; release iOS proof cannot be produced"
fi

if [[ ! -f sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk && ! -f sakina-frontend/build/app/outputs/bundle/release/app-release.aab ]]; then
  fail "missing release/debug mobile artifact evidence under sakina-frontend/build"
fi

printf 'END_TO_END_PRODUCT_GATE_OK all product-level gates exited successfully.\n'
