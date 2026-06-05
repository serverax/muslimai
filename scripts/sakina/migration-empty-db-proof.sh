#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MIGRATION_EMPTY_DB_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd psql
require_cmd rg

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

BASE_DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
POSTGRES_URL="${SAKINA_POSTGRES_ADMIN_URL:-postgres://sakina_user:sakina_password@localhost:5434/postgres}"
db_name="sakina_empty_migration_$(date +%s)_$RANDOM"
temp_url="postgres://sakina_user:sakina_password@localhost:5434/$db_name"
log_file="reports/final-hardening-evidence/256-migration-empty-db-apply.log"

cleanup() {
  set +e
  psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name';" >/dev/null 2>&1
  psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS $db_name;" >/dev/null 2>&1
}
trap cleanup EXIT

psql "$BASE_DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT 1;" >/dev/null \
  || fail "base PostgreSQL connection is unavailable"

psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS $db_name;" >/dev/null
psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -c "CREATE DATABASE $db_name;" >/dev/null
printf 'Temporary migration database=%s\n' "$db_name"

: > "$log_file"
while IFS= read -r migration; do
  printf 'Applying %s\n' "$migration" | tee -a "$log_file"
  psql "$temp_url" -v ON_ERROR_STOP=1 -f "$migration" >>"$log_file" 2>&1 \
    || fail "migration failed on empty DB: $migration; log: $log_file"
done < <(find sakina-backend/db/migrations -maxdepth 1 -type f -name '*.sql' | sort)

required_tables=(
  public.users
  public.user_profiles
  public.auth_sessions
  public.auth_refresh_tokens
  public.password_credentials
  sakina_ai.conversations
  sakina_ai.messages
  sakina_ai.brain_decision_traces
  sakina_ai.user_memory_entries
  sakina_ai.multimodal_assets
  sakina_ai.knowledge_graph_entities
  sakina_ai.knowledge_graph_edges
)

for table in "${required_tables[@]}"; do
  schema="${table%%.*}"
  name="${table#*.}"
  exists="$(psql "$temp_url" -v ON_ERROR_STOP=1 -At -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$schema' AND table_name = '$name';")"
  printf 'Required table %s exists=%s\n' "$table" "$exists"
  (( exists == 1 )) || fail "required table missing after empty DB migration: $table"
done

function_count="$(psql "$temp_url" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'sakina_ai' AND p.proname IN ('current_user_id','rls_service_role');")"
printf 'RLS helper functions after migration=%s\n' "$function_count"
(( function_count == 2 )) || fail "RLS helper functions missing after empty DB migration"

rls_disabled="$(psql "$temp_url" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM pg_tables WHERE schemaname IN ('public','sakina_ai') AND tablename IN ('users','user_profiles','auth_sessions','auth_refresh_tokens','password_credentials','conversations','messages','brain_decision_traces','user_memory_entries','multimodal_assets') AND rowsecurity IS NOT TRUE;")"
printf 'Required user-owned tables with RLS disabled=%s\n' "$rls_disabled"
(( rls_disabled == 0 )) || fail "one or more user-owned tables have RLS disabled after empty DB migration"

policy_count="$(psql "$temp_url" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM pg_policies WHERE schemaname IN ('public','sakina_ai') AND (qual ILIKE '%current_user_id%' OR with_check ILIKE '%current_user_id%' OR qual ILIKE '%rls_service_role%' OR with_check ILIKE '%rls_service_role%');")"
printf 'Function-wired RLS policies after migration=%s\n' "$policy_count"
(( policy_count >= 10 )) || fail "RLS policies were not created after empty DB migration"

seeded_sources="$(psql "$temp_url" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.islamic_sources;")"
seeded_chunks="$(psql "$temp_url" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM sakina_ai.islamic_chunks;")"
printf 'Seeded Islamic sources=%s chunks=%s\n' "$seeded_sources" "$seeded_chunks"
(( seeded_sources >= 1 && seeded_chunks >= 1 )) \
  || fail "empty DB migrations did not seed Islamic source/chunk baseline"

printf 'MIGRATION_EMPTY_DB_OK all backend DB migrations applied cleanly to an empty database with required tables, RLS functions, policies, and Islamic seed data verified.\n'
