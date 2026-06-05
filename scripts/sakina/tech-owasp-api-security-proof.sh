#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'OWASP_API_SECURITY_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${BASE_URL%/}"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-owasp-api-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null
if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  for _ in $(seq 1 180); do
    if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

[[ -f scripts/sakina/security-regression.sh ]] || fail "security regression script is missing"
bash scripts/sakina/security-regression.sh

rg -n "authenticated_user_id|bearer_token|revoked_at|rate_limited|Cors|allowed_origin|unauthorized|forbidden|requested user_id does not match authenticated user" \
  sakina-backend/src sakina-frontend/lib scripts/sakina/security-regression.sh \
  || fail "OWASP API security code path does not show auth, CORS/rate, token revocation, and BOLA controls"

printf 'OWASP_API_SECURITY_OK security regression and API security code-path proof completed.\n'
