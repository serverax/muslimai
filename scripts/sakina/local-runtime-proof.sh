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

log_file="${TMPDIR:-/tmp}/sakina-api.log"
health_file="${TMPDIR:-/tmp}/sakina-health.txt"
curl_err="${TMPDIR:-/tmp}/sakina-curl.err"
rm -f "$log_file" "$health_file" "$curl_err"

cargo run --manifest-path sakina-backend/Cargo.toml --bin sakina-api >"$log_file" 2>&1 &
pid=$!
cleanup() {
  set +e
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
}
trap cleanup EXIT

for _ in $(seq 1 240); do
  if curl -fsS http://localhost:8080/health >"$health_file" 2>"$curl_err"; then
    break
  fi
  sleep 2
done

if [[ ! -s "$health_file" ]]; then
  echo "=== health ==="
  if [[ -s "$curl_err" ]]; then
    cat "$curl_err"
  fi
  echo "=== api log tail ==="
  if [[ -s "$log_file" ]]; then
    tail -120 "$log_file"
  fi
  exit 1
fi

echo "=== health ==="
cat "$health_file" 2>/dev/null || cat "$curl_err"
echo
echo "=== ready ==="
curl -i http://localhost:8080/health/ready || {
  echo "=== api log tail ==="
  if [[ -s "$log_file" ]]; then
    tail -120 "$log_file"
  fi
  exit 1
}
echo
echo "=== ready json ==="
curl -s http://localhost:8080/health/ready | jq .
echo "=== observability ==="
curl -s http://localhost:8080/health/observability | jq .
echo "=== api log tail ==="
tail -80 "$log_file"
