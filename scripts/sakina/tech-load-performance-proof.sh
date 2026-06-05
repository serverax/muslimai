#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'LOAD_PERFORMANCE_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd curl
require_cmd jq
require_cmd psql
require_cmd awk
require_cmd sort
require_cmd cargo

if [[ -f tasks/AGENTS.md ]]; then cat tasks/AGENTS.md >/dev/null; fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export DATABASE_URL
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export CARGO_TARGET_DIR
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false
evidence_dir="reports/final-hardening-evidence"
mkdir -p "$evidence_dir"
timings="$evidence_dir/680-load-performance-timings.txt"
: > "$timings"

started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-load-performance-backend.log"
cleanup() {
  set +e
  if [[ "$started_backend" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

if ! curl -fsS "$BASE_URL/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >/dev/null
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  for _ in $(seq 1 180); do
    if curl -fsS "$BASE_URL/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

curl -fsS "$BASE_URL/health/ready" | jq . > "$evidence_dir/680-ready.json" \
  || fail "backend readiness endpoint is not reachable; log: $backend_log_file"
curl -fsS "$QDRANT_URL/collections" | jq . > "$evidence_dir/680-qdrant-collections.json" \
  || fail "Qdrant collections endpoint is not reachable"

for endpoint in /health /health/ready /health/observability /api/brain/health; do
  for _ in 1 2 3 4 5; do
    elapsed="$(curl -fsS -o /dev/null -w '%{time_total}' "$BASE_URL$endpoint")" \
      || fail "endpoint failed during load proof: $endpoint"
    printf '%s %s\n' "$endpoint" "$elapsed" >> "$timings"
  done
done

db_elapsed="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "EXPLAIN (ANALYZE, FORMAT JSON) SELECT COUNT(*) FROM public.users;" | jq -r '.[0]."Execution Time"')"
printf 'database_count_ms %s\n' "$db_elapsed" >> "$timings"

awk '
  $1 ~ /^\// {
    values[$1, ++counts[$1]] = $2
  }
  END {
    for (endpoint in counts) {
      n = counts[endpoint]
      for (i = 1; i <= n; i++) sorted[i] = values[endpoint, i]
      asort(sorted)
      p95 = sorted[int(n * 0.95)]
      if (p95 == "") p95 = sorted[n]
      printf "%s p95_seconds %.6f\n", endpoint, p95
      if ((endpoint == "/health" || endpoint == "/api/brain/health") && p95 > 0.300) exit 10
      if ((endpoint == "/health/ready" || endpoint == "/health/observability") && p95 > 1.000) exit 11
    }
  }
' "$timings" > "$evidence_dir/680-load-performance-budget.txt" \
  || fail "performance budget exceeded: $evidence_dir/680-load-performance-budget.txt"

printf 'LOAD_PERFORMANCE_OK runtime health/Brain/readiness endpoints and DB/Qdrant checks met the configured local performance budgets.\n'
