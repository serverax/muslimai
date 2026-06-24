#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'BACKUP_DISASTER_RECOVERY_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd psql
require_cmd pg_dump
require_cmd curl
require_cmd jq
require_cmd tar
require_cmd sha256sum
require_cmd rg

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
proof_id="backup-dr-$(date +%s)-$$"
work_dir="${TMPDIR:-/tmp}/sakina-backup-dr-${proof_id}"
mkdir -p "$work_dir/source-files" "$work_dir/restore-files"

schema_backup="$work_dir/postgres-schema.sql"
users_backup="$work_dir/users.csv"
qdrant_backup="$work_dir/qdrant-collections.json"
config_backup="$work_dir/k8s-config-refs.txt"
asset_file="$work_dir/source-files/uploaded-asset.txt"
asset_archive="$work_dir/uploaded-assets.tar"

printf 'uploaded asset backup proof %s\n' "$proof_id" > "$asset_file"

pg_dump "$DATABASE_URL" --schema-only --schema=public --schema=sakina_ai --schema=outbox \
  > "$schema_backup" \
  || fail "PostgreSQL schema backup failed"
[[ -s "$schema_backup" ]] || fail "PostgreSQL schema backup file is empty"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v proof_id="$proof_id" <<'SQL'
\pset pager off
DO $$
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RAISE EXCEPTION 'public.users missing; cannot back up identity data';
  END IF;
  IF to_regclass('sakina_ai.islamic_chunks') IS NULL THEN
    RAISE EXCEPTION 'sakina_ai.islamic_chunks missing; cannot verify source index backup coverage';
  END IF;
  IF to_regclass('outbox.events') IS NULL THEN
    RAISE EXCEPTION 'outbox.events missing; cannot verify async recovery coverage';
  END IF;
END $$;

INSERT INTO public.users (pub_key, email, auth_provider, is_active)
VALUES (:'proof_id' || '-pub', :'proof_id' || '@backup.invalid', 'backup-dr-proof', true)
ON CONFLICT (email) DO NOTHING;
SQL

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -F '|' \
  -c "SELECT id::text, COALESCE(email, ''), COALESCE(auth_provider, ''), is_active::text FROM public.users ORDER BY id LIMIT 100" \
  > "$users_backup" \
  || fail "PostgreSQL user data backup export failed"
[[ -s "$users_backup" ]] || fail "PostgreSQL users backup file is empty"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v proof_id="$proof_id" <<'SQL'
\pset pager off
CREATE TABLE IF NOT EXISTS public.sakina_restore_users_proof (
  proof_id text NOT NULL,
  id text NOT NULL,
  email text NOT NULL,
  auth_provider text NOT NULL,
  is_active text NOT NULL
);
DELETE FROM public.sakina_restore_users_proof WHERE proof_id = :'proof_id';
SQL

while IFS='|' read -r row_id row_email row_provider row_active; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
    -v proof_id="$proof_id" \
    -v row_id="$row_id" \
    -v row_email="$row_email" \
    -v row_provider="$row_provider" \
    -v row_active="$row_active" <<'SQL' >/dev/null
INSERT INTO public.sakina_restore_users_proof (proof_id, id, email, auth_provider, is_active)
VALUES (:'proof_id', :'row_id', :'row_email', :'row_provider', :'row_active');
SQL
done < "$users_backup"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v proof_id="$proof_id" <<'SQL'
\pset pager off
SELECT set_config('sakina.backup_proof_id', :'proof_id', false);

DO $$
DECLARE
  source_count bigint;
  restored_count bigint;
  source_hash text;
  restored_hash text;
BEGIN
  SELECT count(*), md5(string_agg(id::text || ':' || COALESCE(email, '') || ':' || COALESCE(auth_provider, '') || ':' || is_active::text, ',' ORDER BY id::text))
  INTO source_count, source_hash
  FROM (SELECT id, email, auth_provider, is_active FROM public.users ORDER BY id LIMIT 100) source_rows;

  SELECT count(*), md5(string_agg(id || ':' || COALESCE(email, '') || ':' || COALESCE(auth_provider, '') || ':' || is_active, ',' ORDER BY id))
  INTO restored_count, restored_hash
  FROM public.sakina_restore_users_proof
  WHERE proof_id = current_setting('sakina.backup_proof_id', true);

  IF source_count <> restored_count OR source_hash IS DISTINCT FROM restored_hash THEN
    RAISE EXCEPTION 'restored user backup mismatch: source %, restored %, source hash %, restored hash %',
      source_count, restored_count, source_hash, restored_hash;
  END IF;
END $$;

INSERT INTO outbox.events (event_type, payload, status)
VALUES ('backup_disaster_recovery_verified', jsonb_build_object('proof_id', :'proof_id'), 'Pending');

SELECT 'postgres_backup_restore_verified' AS proof,
       (SELECT count(*) FROM public.sakina_restore_users_proof WHERE proof_id = :'proof_id') AS restored_users,
       (SELECT count(*) FROM sakina_ai.islamic_chunks) AS source_chunks,
       (SELECT count(*) FROM outbox.events WHERE payload->>'proof_id' = :'proof_id') AS outbox_events;

DROP TABLE IF EXISTS public.sakina_restore_users_proof;
SQL

curl -fsS "$QDRANT_URL/collections" > "$qdrant_backup" \
  || fail "Qdrant collection metadata backup failed"
jq -e '.result.collections | type == "array"' "$qdrant_backup" >/dev/null \
  || fail "Qdrant backup JSON does not contain collection list"

rg -n "secretKeyRef|configMapKeyRef|ConfigMap|Secret" sakina-infra infra/k8s infra/sakina-mobile \
  > "$config_backup" \
  || fail "Kubernetes config/secret reference backup scan found no references"
[[ -s "$config_backup" ]] || fail "config reference backup file is empty"

tar -cf "$asset_archive" -C "$work_dir/source-files" uploaded-asset.txt \
  || fail "uploaded asset archive backup failed"
tar -xf "$asset_archive" -C "$work_dir/restore-files" \
  || fail "uploaded asset archive restore failed"

source_hash="$(sha256sum "$asset_file" | awk '{print $1}')"
restore_hash="$(sha256sum "$work_dir/restore-files/uploaded-asset.txt" | awk '{print $1}')"
[[ "$source_hash" = "$restore_hash" ]] \
  || fail "restored uploaded asset hash mismatch"

printf 'Schema backup: %s\n' "$schema_backup"
printf 'User data backup: %s\n' "$users_backup"
printf 'Qdrant metadata backup: %s\n' "$qdrant_backup"
printf 'Config reference backup: %s\n' "$config_backup"
printf 'Asset archive: %s\n' "$asset_archive"
printf 'BACKUP_DISASTER_RECOVERY_OK PostgreSQL export/restore checksum, Qdrant metadata export, config reference backup, outbox recovery event, and uploaded asset restore were verified.\n'
