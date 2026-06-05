#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'WIRING_GATE_BLOCKER missing required evidence file: %s\n' "$path" >&2
    exit 1
  fi
}

require_script() {
  local path="$1"
  if [[ ! -x "$path" && ! -f "$path" ]]; then
    printf 'WIRING_GATE_BLOCKER missing required proof script: %s\n' "$path" >&2
    exit 1
  fi
}

require_file reports/final-hardening-evidence/230-frontend-backend-wiring-matrix.md
require_file reports/final-hardening-evidence/232-frontend-fake-wiring-scan-review.md
require_file reports/final-hardening-evidence/240-backend-route-handler-db-matrix.md
require_file reports/final-hardening-evidence/243-backend-unused-route-handler-review.md
require_file reports/final-hardening-evidence/250-db-function-wiring-matrix.md

for required_dir in sakina-frontend/lib sakina-frontend/android sakina-frontend/ios; do
  if [[ ! -d "$required_dir" ]]; then
    printf 'WIRING_GATE_BLOCKER missing required frontend path from task order: %s\n' "$required_dir" >&2
    exit 1
  fi
done

if grep -RInE "mock|fake|stub|demo|dummy|placeholder|TODO|FIXME|coming soon|hardcoded|sample|test-token|demo-token|localhost|127.0.0.1|10.0.2.2|Future.delayed|return .*\\[|return .*\\{|static const|Fake|Mock|Stub|Demo" \
  sakina-frontend/lib sakina-frontend/android sakina-frontend/ios \
  > reports/final-hardening-evidence/231-frontend-fake-wiring-scan.txt; then
  if grep -iE "production blocker|must be removed|unreviewed|pending" \
    reports/final-hardening-evidence/232-frontend-fake-wiring-scan-review.md >/dev/null; then
    printf 'WIRING_GATE_BLOCKER frontend static/fake scan has unresolved production blockers in review: reports/final-hardening-evidence/232-frontend-fake-wiring-scan-review.md\n' >&2
    exit 1
  fi
  printf 'Frontend static/fake scan had reviewed non-production hits; continuing with contract and runtime proofs.\n'
else
  printf 'No frontend fake wiring scanner hits.\n' > reports/final-hardening-evidence/231-frontend-fake-wiring-scan.txt
fi

require_script scripts/sakina/frontend-api-contract-proof.sh
bash scripts/sakina/frontend-api-contract-proof.sh > reports/final-hardening-evidence/233-frontend-api-contract-proof.txt 2>&1

require_script scripts/sakina/mobile-to-backend-to-db-e2e-proof.sh
bash scripts/sakina/mobile-to-backend-to-db-e2e-proof.sh > reports/final-hardening-evidence/234-mobile-to-backend-to-db-e2e-proof.txt 2>&1

grep -RInE "route\\(|\\.route|Router|scope|service\\(|web::|axum|actix|warp|rocket" sakina-backend/src \
  > reports/final-hardening-evidence/241-backend-routes-scan.txt
grep -RInE "pub async fn|async fn|pub fn|fn " sakina-backend/src/handlers sakina-backend/src/services \
  > reports/final-hardening-evidence/242-backend-functions-scan.txt

docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY schemaname, tablename;" \
  > reports/final-hardening-evidence/251-db-tables-rls.txt
docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "SELECT n.nspname AS schema, p.proname AS function_name FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname NOT IN ('pg_catalog','information_schema') ORDER BY schema, function_name;" \
  > reports/final-hardening-evidence/252-db-functions.txt
docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "SELECT event_object_schema, event_object_table, trigger_name, action_timing, event_manipulation FROM information_schema.triggers ORDER BY event_object_schema, event_object_table, trigger_name;" \
  > reports/final-hardening-evidence/253-db-triggers.txt
docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev psql -U sakina_user -d sakina -v ON_ERROR_STOP=1 \
  -c "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies ORDER BY schemaname, tablename, policyname;" \
  > reports/final-hardening-evidence/254-db-policies.txt

require_script scripts/sakina/db-functions-triggers-proof.sh
bash scripts/sakina/db-functions-triggers-proof.sh > reports/final-hardening-evidence/255-db-functions-triggers-proof.txt 2>&1

require_script scripts/sakina/migration-empty-db-proof.sh
bash scripts/sakina/migration-empty-db-proof.sh > reports/final-hardening-evidence/256-migration-empty-db-proof.txt 2>&1

require_script scripts/sakina/end-to-end-trace-id-proof.sh
bash scripts/sakina/end-to-end-trace-id-proof.sh > reports/final-hardening-evidence/260-end-to-end-trace-id-proof.txt 2>&1

require_script scripts/sakina/api-schema-contract-proof.sh
bash scripts/sakina/api-schema-contract-proof.sh > reports/final-hardening-evidence/270-api-schema-contract-proof.txt 2>&1

printf 'WIRING_GATE_OK all wiring subchecks exited successfully.\n'
