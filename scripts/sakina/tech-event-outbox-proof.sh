#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'EVENT_OUTBOX_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql
require_cmd rg

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
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
backend_log_file="${TMPDIR:-/tmp}/sakina-outbox-proof-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

event_id="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "INSERT INTO outbox.events (event_type, payload, status) VALUES ('chunk_indexed', '{\"proof\":\"event-outbox\"}'::jsonb, 'Pending') RETURNING id;" | head -n1)"
[[ -n "$event_id" ]] || fail "failed to insert outbox event"
printf 'Inserted outbox event: %s\n' "$event_id"

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

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend did not become ready for outbox relay; log: $backend_log_file"

status="Pending"
for _ in $(seq 1 20); do
  status="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT status FROM outbox.events WHERE id = '$event_id';")"
  if [[ "$status" = "Sent" ]]; then
    break
  fi
  sleep 1
done
printf 'Outbox event final status: %s\n' "$status"
[[ "$status" = "Sent" ]] || fail "outbox relay did not mark chunk_indexed event Sent"

rg -n "OutboxRelay|relay_events|FOR UPDATE SKIP LOCKED|status = 'Sent'|outbox.events" \
  sakina-backend/src/services/outbox_relay.rs sakina-backend/src/main.rs sakina-backend/src/services/ingestion_producer.rs sakina-backend/db/init.sql \
  || fail "outbox code path does not show relay, locking, sent update, ingestion event creation, and schema"

printf 'EVENT_OUTBOX_OK pending event was relayed to Sent by the running backend.\n'
