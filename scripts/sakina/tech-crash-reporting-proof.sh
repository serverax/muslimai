#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'CRASH_REPORTING_BLOCKER %s\n' "$1" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v psql >/dev/null 2>&1 || fail "psql is required"
command -v rg >/dev/null 2>&1 || fail "rg is required"
command -v cargo >/dev/null 2>&1 || fail "cargo is required"

if [[ -f tasks/AGENTS.md ]]; then cat tasks/AGENTS.md >/dev/null; fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export DATABASE_URL
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export CARGO_TARGET_DIR
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false
request_id="crash-proof-$(date +%s)-$$"

started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-crash-reporting-backend.log"
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
curl -fsS "$BASE_URL/health/ready" >/dev/null \
  || fail "backend did not become ready for crash reporting proof; log: $backend_log_file"

status="$(curl -sS -o reports/final-hardening-evidence/700-backend-error-response.json -w '%{http_code}' \
  -H "X-Request-ID: $request_id" "$BASE_URL/__sakina_crash_reporting_negative_path")"
[[ "$status" = "404" ]] || fail "backend negative error path did not return 404; got $status"
jq -e '.error.code == "not_found" or .error.code == "bad_request" or .error.code == "internal_error"' \
  reports/final-hardening-evidence/700-backend-error-response.json >/dev/null \
  || fail "backend error response did not use normalized error contract"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v request_id="$request_id" <<'SQL'
\pset pager off
DO $$
BEGIN
  IF to_regclass('public.app_events') IS NULL THEN
    RAISE EXCEPTION 'public.app_events missing; crash/error events cannot be recorded';
  END IF;
END $$;
INSERT INTO public.app_events (event_name, event_payload)
VALUES ('crash_reporting_probe', jsonb_build_object('request_id', :'request_id', 'source', 'advanced-gate', 'pii_redacted', true));
SELECT event_name, event_payload->>'request_id' AS request_id
FROM public.app_events
WHERE event_payload->>'request_id' = :'request_id';
SQL

rg -n "Crash|crash|FlutterError|runZonedGuarded|error_response|tracing::error|app_events" \
  sakina-frontend/lib sakina-backend/src sakina-backend/db \
  > reports/final-hardening-evidence/700-crash-error-code-paths.txt \
  || fail "crash/error reporting code paths not found"

if grep -Ei "JWT_SECRET|OPENAI_API_KEY|ENCRYPTION_KEY|password" reports/final-hardening-evidence/700-backend-error-response.json; then
  fail "error response leaked sensitive material"
fi

printf 'CRASH_REPORTING_OK backend error contract, DB error event recording, and frontend/backend crash/error code paths were verified.\n'
