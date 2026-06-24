#!/usr/bin/env bash
set -euo pipefail

SCAN_SCOPE="${1:-}"
if [[ "${SCAN_SCOPE}" == "--all-files" ]]; then
  mapfile -t FILES < <(git ls-files --cached --others --exclude-standard .github/workflows docs infra/k8s scripts/sakina sakina-backend sakina-rag admin)
else
  mapfile -t FILES < <(git diff --cached --name-only)
fi

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "No files selected for secret scan"
  exit 0
fi

for file in "${FILES[@]}"; do
  if [[ "${file}" =~ (^|/)(\.env(\..*)?|kubeconfig|.*\.(pem|key|p12|pfx|bak|backup|tmp))$ ]]; then
    echo "Unsafe file staged or selected: ${file}" >&2
    exit 1
  fi
done

SECRET_PATTERN='(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|DSA) PRIVATE KEY-----|xox[baprs]-|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|password\s*[:=]\s*["'"'"'][^"'"'"']+["'"'"']|token\s*[:=]\s*["'"'"'][^"'"'"']+["'"'"']|database_url\s*[:=]\s*["'"'"']postgres[^"'"'"']+["'"'"'])'

for file in "${FILES[@]}"; do
  [[ -f "${file}" ]] || continue
  if grep -Ein "${SECRET_PATTERN}" "${file}" \
    | grep -Ev '\$\{\{[[:space:]]*(secrets|github)\.' \
    | grep -Ev '\[masked\]|=[[:space:]]*["'\'']?\$\(|[[:space:]]*["'\'']?\$[{]' >/dev/null; then
    echo "Potential secret detected in ${file}" >&2
    exit 1
  fi
done

echo "secret leak verification completed."
