#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

log_file="${TMPDIR:-/tmp}/sakina-api-regressions.log"
rm -f "$log_file"

cargo run --manifest-path sakina-backend/Cargo.toml --bin sakina-api >"$log_file" 2>&1 &
pid=$!
cleanup() {
  set +e
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
}
trap cleanup EXIT

for _ in $(seq 1 240); do
  if curl -fsS http://localhost:8080/health/ready >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
curl -fsS http://localhost:8080/health/ready | jq .

bash scripts/sakina/e2e-real-user-journey.sh
bash scripts/sakina/security-regression.sh
bash scripts/sakina/islamic-safety-regression.sh

echo "=== api log tail ==="
tail -80 "$log_file"
