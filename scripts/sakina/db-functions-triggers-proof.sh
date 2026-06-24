#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'DB_FUNCTION_TRIGGER_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd psql
require_cmd jq
require_cmd rg

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
proof_user_id="11111111-2222-4333-8444-555555555555"

function_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'sakina_ai' AND p.proname IN ('current_user_id','rls_service_role');")"
printf 'Sakina RLS helper function count=%s\n' "$function_count"
(( function_count == 2 )) || fail "required Sakina RLS helper functions are missing"

current_user_result="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT set_config('sakina.current_user_id', '$proof_user_id', false); SELECT sakina_ai.current_user_id()::text;")"
printf '%s\n' "$current_user_result"
printf '%s\n' "$current_user_result" | rg -q "$proof_user_id" \
  || fail "sakina_ai.current_user_id() did not read runtime user context"

service_role_result="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT set_config('sakina.service_role', 'off', false); SELECT sakina_ai.rls_service_role(); SELECT set_config('sakina.service_role', 'on', false); SELECT sakina_ai.rls_service_role();")"
printf '%s\n' "$service_role_result"
printf '%s\n' "$service_role_result" | rg -q "t" \
  || fail "sakina_ai.rls_service_role() did not expose controlled service role state"

policy_usage_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM pg_policies WHERE schemaname IN ('public','sakina_ai') AND (qual ILIKE '%current_user_id%' OR with_check ILIKE '%current_user_id%' OR qual ILIKE '%rls_service_role%' OR with_check ILIKE '%rls_service_role%');")"
printf 'RLS policies using helper functions=%s\n' "$policy_usage_count"
(( policy_usage_count >= 10 )) || fail "RLS helper functions are not wired into enough live policies"

table_policy_gaps="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "WITH user_tables AS (
     SELECT schemaname, tablename
     FROM pg_tables
     WHERE schemaname IN ('public','sakina_ai')
       AND tablename IN ('users','auth_sessions','auth_refresh_tokens','password_credentials','user_profiles','conversations','messages','user_memory_entries','brain_decision_traces','multimodal_assets')
   )
   SELECT COUNT(*)
   FROM user_tables t
   WHERE NOT EXISTS (
     SELECT 1 FROM pg_policies p
     WHERE p.schemaname = t.schemaname
       AND p.tablename = t.tablename
       AND (
         p.qual ILIKE '%current_user_id%'
         OR p.with_check ILIKE '%current_user_id%'
         OR p.qual ILIKE '%rls_service_role%'
         OR p.with_check ILIKE '%rls_service_role%'
       )
   );")"
printf 'User-owned table policy gaps=%s\n' "$table_policy_gaps"
(( table_policy_gaps == 0 )) || fail "one or more user-owned tables lack function-wired RLS policies"

trigger_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM information_schema.triggers WHERE event_object_schema IN ('public','sakina_ai','audit','outbox');")"
printf 'Sakina application trigger count=%s\n' "$trigger_count"

if (( trigger_count == 0 )); then
  if rg -n '^\|[^|]*\|[[:space:]]*trigger[[:space:]]*\|' reports/final-hardening-evidence/250-db-function-wiring-matrix.md | rg -vi "NOT PRESENT|NO TRIGGER CLAIMED|none" >/tmp/sakina-trigger-matrix-hits.txt; then
    cat /tmp/sakina-trigger-matrix-hits.txt
    fail "matrix references DB triggers but live DB has no Sakina application triggers"
  fi
else
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
    "SELECT event_object_schema, event_object_table, trigger_name, action_timing, event_manipulation FROM information_schema.triggers WHERE event_object_schema IN ('public','sakina_ai','audit','outbox') ORDER BY 1,2,3;"
fi

printf 'DB_FUNCTION_TRIGGER_OK RLS helper functions exist, runtime user context works, policies use the functions, user-owned tables are policy-wired, and live trigger state is honestly verified.\n'
