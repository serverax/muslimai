#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

fail() {
  printf 'SECURITY_PERFORMANCE_GATE_BLOCKER %s\n' "$1" >&2
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
  "security-regression.sh"
  "db-user-isolation-proof.sh"
  "tech-owasp-api-security-proof.sh"
  "tech-owasp-masvs-mobile-proof.sh"
  "tech-sast-sca-container-proof.sh"
  "tech-kubernetes-restricted-proof.sh"
  "tech-pii-redaction-proof.sh"
  "tech-data-retention-deletion-proof.sh"
  "tech-backup-disaster-recovery-proof.sh"
  "tech-load-performance-proof.sh"
  "tech-canary-rollout-proof.sh"
  "tech-crash-reporting-proof.sh"
  "verify-no-secret-leak.sh"
)

for script in "${required_scripts[@]}"; do
  path="scripts/sakina/$script"
  evidence="reports/final-hardening-evidence/security-performance-${script}.txt"
  if [[ ! -f "$path" ]]; then
    printf 'Missing required security/performance proof script: %s\n' "$path" > "$evidence"
    fail "missing required security/performance proof script: $path"
  fi
  bash "$path" > "$evidence" 2>&1
done

scan_paths=(.github scripts infra)
[[ -d k8s ]] && scan_paths+=(k8s)
[[ -d helm ]] && scan_paths+=(helm)

if rg -n -i "continue-on-error: true|echo.*passed|Smoke validation passed|mock_embeddings|ALLOW_FAKE_CI_PASS[[:space:]]*=[[:space:]]*true|fake[ _-]+pass|fake[ _-]+passed|stub[ _-]+pass|stub[ _-]+passed" \
  "${scan_paths[@]}" \
  --glob '!scripts/sakina/final-security-performance-gate.sh' \
  --glob '!scripts/sakina/tech-sast-sca-container-proof.sh' \
  --glob '!scripts/sakina/new-technologies-master-matrix-proof.sh' \
  > reports/final-hardening-evidence/security-performance-fake-ci-scan.txt; then
  fail "CI/script fake-success scanner has hits: reports/final-hardening-evidence/security-performance-fake-ci-scan.txt"
fi

printf 'SECURITY_PERFORMANCE_GATE_OK security, performance, CI, and deployment policy proof scripts exited successfully.\n'
