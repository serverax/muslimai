#!/usr/bin/env bash
set -euo pipefail

DB_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"

psql "$DB_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/20260529_phase3_full_product_schema_revision2.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/20260602_phase21_daily_iman_journey.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/migrations/014_brain_knowledge_graph.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/migrations/015_user_memory_multimodal.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/migrations/016_password_auth.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -f sakina-backend/db/migrations/017_rls_user_isolation.sql

echo "test database bootstrap completed with migration assertions."
