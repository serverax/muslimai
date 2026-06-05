#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'SECRETS_MANAGEMENT_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd rg
require_cmd git

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

production_scope_file="${TMPDIR:-/tmp}/sakina-secret-production-scope.txt"
git ls-files \
  .github/workflows \
  infra/k8s \
  sakina-infra/manifests \
  sakina-backend/src \
  sakina-frontend/lib \
  >"$production_scope_file"

[[ -s "$production_scope_file" ]] || fail "production secret scan scope is empty"

secret_pattern='(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|DSA|PRIVATE) PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|sk-[A-Za-z0-9]{32,})'
if rg -n -i -f <(printf '%s\n' "$secret_pattern") $(cat "$production_scope_file") >/tmp/sakina-secret-production-hits.txt; then
  cat /tmp/sakina-secret-production-hits.txt
  fail "production files contain high-confidence secret material"
fi
printf 'Production high-confidence secret scan: no committed secret tokens or private keys found.\n'

if rg -n -i 'password\s*[:=]\s*["'\''][^"'\'']{8,}["'\'']|api[_-]?key\s*[:=]\s*["'\''][^"$\{][^"'\'']{8,}["'\'']|secret\s*[:=]\s*["'\''][^"$\{][^"'\'']{8,}["'\'']' \
  sakina-backend/src sakina-frontend/lib infra/k8s sakina-infra/manifests .github/workflows \
  >/tmp/sakina-secret-literal-hits.txt; then
  cat /tmp/sakina-secret-literal-hits.txt
  fail "production paths contain literal password/api-key/secret assignments"
fi
printf 'Production literal secret scan: no literal password/api-key/secret assignments found.\n'

rg -n 'secretKeyRef|imagePullSecrets|ghcr-pull-secret|sakina-staging-secrets|postgres-secrets|sakina-postgres-secret' \
  infra/k8s sakina-infra/manifests >/tmp/sakina-secret-k8s-refs.txt \
  || fail "Kubernetes manifests do not reference required secret objects"
cat /tmp/sakina-secret-k8s-refs.txt

rg -n '\$\{\{\s*secrets\.|SAKINA_KUBECONFIG_B64|GITHUB_TOKEN|ANDROID_KEYSTORE|APPLE_' \
  .github/workflows >/tmp/sakina-secret-github-refs.txt \
  || fail "GitHub workflows do not reference GitHub secrets for protected values"
cat /tmp/sakina-secret-github-refs.txt

rg -n 'strong_secret|JWT_SECRET|SAKINA_JWT_SECRET|ENCRYPTION_KEY|SAKINA_ENCRYPTION_KEY|fake_mode_disabled|do_not_log_secret_values|secretKeyRef' \
  sakina-backend/src/main.rs sakina-backend/src/services/auth.rs infra/k8s sakina-infra/manifests \
  >/tmp/sakina-secret-runtime-code-path.txt \
  || fail "backend runtime secret validation and Kubernetes secret references were not found"
cat /tmp/sakina-secret-runtime-code-path.txt

if rg -n 'sakina-local-jwt-secret-minimum|sakina-local-encryption-key-minimum|sakina_password|StrongPassword123!' \
  scripts/sakina sakina-backend/src >/tmp/sakina-secret-proof-defaults.txt; then
  python3 - <<'PY'
from pathlib import Path
bad = []
for line in Path('/tmp/sakina-secret-proof-defaults.txt').read_text().splitlines():
    path = line.split(':', 1)[0]
    if not (path.startswith('scripts/sakina/') or 'src/handlers/' in path or 'src/services/' in path):
        bad.append(line)
if bad:
    print('\n'.join(bad))
    raise SystemExit(1)
PY
  printf 'Reviewed local proof/test defaults; no production secret value accepted as runtime credential.\n'
  cat /tmp/sakina-secret-proof-defaults.txt
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/tmp/sakina-gh-auth-status.txt 2>&1; then
    gh secret list --repo serverax/muslimai >/tmp/sakina-github-secret-names.txt
    cat /tmp/sakina-github-secret-names.txt
    rg -n 'SAKINA_KUBECONFIG_B64|SAKINA_STAGING_NAMESPACE|GITHUB_TOKEN|AZURE_|ANDROID_|APPLE_' \
      /tmp/sakina-github-secret-names.txt >/dev/null \
      || fail "GitHub secret names required by workflows are not visible through gh"
  else
    cat /tmp/sakina-gh-auth-status.txt
    fail "gh auth is required to verify GitHub secret names without printing values"
  fi
else
  fail "gh CLI missing; cannot verify GitHub secret names"
fi

if command -v kubectl >/dev/null 2>&1; then
  if kubectl get secret -A >/tmp/sakina-k8s-secret-names-all.txt 2>&1; then
    awk 'NR == 1 || $1 ~ /sakina/' /tmp/sakina-k8s-secret-names-all.txt \
      >/tmp/sakina-k8s-secret-names.txt
    cat /tmp/sakina-k8s-secret-names.txt
    rg -n 'ghcr-pull-secret|sakina-staging-secrets|postgres-secrets|sakina-postgres-secret' \
      /tmp/sakina-k8s-secret-names.txt >/dev/null \
      || fail "Kubernetes required Sakina secret names are missing"
  else
    cat /tmp/sakina-k8s-secret-names.txt
    fail "kubectl could not list Kubernetes secret names"
  fi
else
  fail "kubectl missing; cannot verify Kubernetes secret names"
fi

cargo test --manifest-path sakina-backend/Cargo.toml \
  error::tests::error_response_uses_consistent_contract_shape \
  -- --nocapture

printf 'SECRETS_MANAGEMENT_OK production paths have no high-confidence committed secrets, backend validates strong secrets, Kubernetes and GitHub use secret references/names only, and no secret values were printed.\n'
