#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'SAKINA_DB_PROOF_FAIL: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd psql
require_cmd jq

if [[ -z "${DATABASE_URL:-}" ]]; then
  fail "DATABASE_URL is required"
fi

echo "=== schemas ==="
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c '\dn'

echo "=== tables: sakina_ai ==="
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c '\dt sakina_ai.*'

echo "=== tables: public ==="
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c '\dt public.*'

echo "=== migration proof ==="
if psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 -c "SELECT to_regclass('_sqlx_migrations');" | grep -q '_sqlx_migrations'; then
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c 'SELECT version, description, installed_on FROM _sqlx_migrations ORDER BY version;'
else
  echo "migration_table=_sqlx_migrations_missing"
  echo "applied_migration_files:"
  find sakina-backend/db/migrations -type f -name '*.sql' | sort
  echo "source_schema_files:"
  printf '%s\n' \
    'sakina-backend/db/20260529_phase3_full_product_schema_revision2.sql' \
    'sakina-backend/db/20260602_phase21_daily_iman_journey.sql'
fi

echo "=== extension proof ==="
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "SELECT extname, extversion FROM pg_extension ORDER BY extname;"

echo "=== core row counts ==="
sources_count="$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM sakina_ai.islamic_sources;')"
documents_count="$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM sakina_ai.islamic_documents;')"
chunks_count="$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM sakina_ai.islamic_chunks;')"
embeddings_count="$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM sakina_ai.islamic_embeddings;')"

printf 'islamic_sources=%s\n' "$sources_count"
printf 'islamic_documents=%s\n' "$documents_count"
printf 'islamic_chunks=%s\n' "$chunks_count"
printf 'islamic_embeddings=%s\n' "$embeddings_count"

for pair in \
  "sakina_ai.islamic_sources:$sources_count" \
  "sakina_ai.islamic_documents:$documents_count" \
  "sakina_ai.islamic_chunks:$chunks_count" \
  "sakina_ai.islamic_embeddings:$embeddings_count"
do
  table="${pair%%:*}"
  count="${pair##*:}"
  if [[ "$count" -le 0 ]]; then
    fail "$table has no rows"
  fi
done

echo "=== audit tables (if present) ==="
for table in \
  sakina_ai.rag_retrieval_audit \
  sakina_ai.citation_verification_events \
  sakina_ai.mastermind_decisions \
  sakina_ai.wasm_verification_events
do
  if psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 -c "SELECT to_regclass('$table');" | grep -q "$table"; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT count(*) AS count FROM $table;"
  else
    printf 'missing_optional_audit_table=%s\n' "$table"
  fi
done

echo "SAKINA_DB_PROOF_PASS"
