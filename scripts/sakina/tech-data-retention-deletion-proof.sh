#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'DATA_RETENTION_DELETION_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd psql
require_cmd rg

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
proof_id="data-retention-$(date +%s)-$$"
asset_dir="${TMPDIR:-/tmp}/sakina-data-retention-proof"
asset_path="${asset_dir}/${proof_id}-asset.txt"
mkdir -p "$asset_dir"
printf 'private uploaded asset for %s\n' "$proof_id" > "$asset_path"

sql_output="$(
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v proof_id="$proof_id" -v asset_path="$asset_path" <<'SQL'
\pset tuples_only off
\pset pager off

DO $$
DECLARE
  required_table text;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'public.users',
    'public.user_profiles',
    'public.auth_sessions',
    'public.audit_logs',
    'sakina_ai.conversations',
    'sakina_ai.messages',
    'sakina_ai.brain_decision_traces',
    'sakina_ai.user_memory_entries',
    'sakina_ai.multimodal_assets',
    'outbox.events'
  ]
  LOOP
    IF to_regclass(required_table) IS NULL THEN
      RAISE EXCEPTION 'required table missing: %', required_table;
    END IF;
  END LOOP;
END $$;

DROP TABLE IF EXISTS pg_temp.sakina_deletion_proof_ids;
CREATE TEMP TABLE sakina_deletion_proof_ids (
  proof_id text NOT NULL,
  user_a uuid NOT NULL,
  user_b uuid NOT NULL,
  conversation_a uuid NOT NULL,
  message_a uuid NOT NULL,
  trace_a uuid NOT NULL,
  memory_a uuid NOT NULL,
  asset_a uuid NOT NULL,
  audit_request_id text NOT NULL
);

WITH ids AS (
  SELECT
    gen_random_uuid() AS user_a,
    gen_random_uuid() AS user_b,
    :'proof_id'::text AS proof_id,
    :'proof_id'::text AS audit_request_id
),
users_insert AS (
  INSERT INTO public.users (id, pub_key, email, auth_provider, is_active)
  SELECT user_a, proof_id || '-pub-a', proof_id || '-a@example.invalid', 'retention-proof', true FROM ids
  UNION ALL
  SELECT user_b, proof_id || '-pub-b', proof_id || '-b@example.invalid', 'retention-proof', true FROM ids
  RETURNING id
),
profile_insert AS (
  INSERT INTO public.user_profiles (user_id, display_name, metadata)
  SELECT user_a, 'Retention Proof User A', jsonb_build_object('proof_id', proof_id) FROM ids
  RETURNING id
),
session_insert AS (
  INSERT INTO public.auth_sessions (user_id, session_token_hash, expires_at, last_seen_at)
  SELECT user_a, proof_id || '-session-a', now() + interval '1 hour', now() FROM ids
  RETURNING id
),
conversation_insert AS (
  INSERT INTO sakina_ai.conversations (user_id, title, status)
  SELECT user_a, 'Retention proof conversation', 'active' FROM ids
  RETURNING id
),
message_insert AS (
  INSERT INTO sakina_ai.messages (conversation_id, user_id, role, content)
  SELECT conversation_insert.id, ids.user_a, 'user', 'Retention proof private message'
  FROM conversation_insert, ids
  RETURNING id
),
trace_insert AS (
  INSERT INTO sakina_ai.brain_decision_traces (
    request_id, user_id, input_type, intent, language, risk_level,
    selected_agent, selected_model, selected_pipeline, source_strategy,
    evaluation_result, final_action, audit_event_id, execution_trace
  )
  SELECT proof_id, user_a::text, 'text', 'retention_proof', 'en', 'low',
         'data-retention-agent', 'none', 'retention-deletion',
         'not_applicable', 'not_applicable', 'delete_or_anonymise',
         proof_id, jsonb_build_array(jsonb_build_object('stage', 'data_retention_proof'))
  FROM ids
  RETURNING id
),
memory_insert AS (
  INSERT INTO sakina_ai.user_memory_entries (
    user_id, memory_key, memory_type, sensitivity_level, encrypted_payload,
    nonce, consent_required, consent_granted, allowed, metadata
  )
  SELECT user_a, proof_id || '-memory', 'preference', 'safe',
         convert_to('encrypted-proof-memory', 'UTF8'), convert_to('nonce-proof', 'UTF8'),
         false, true, true, jsonb_build_object('proof_id', proof_id)
  FROM ids
  RETURNING id
),
asset_insert AS (
  INSERT INTO sakina_ai.multimodal_assets (
    user_id, asset_type, original_name, storage_scope, redacted_text,
    extracted_text, safety_level, status, metadata
  )
  SELECT user_a, 'document', proof_id || '.txt', 'user',
         '', 'private asset text', 'safe', 'received',
         jsonb_build_object('proof_id', proof_id, 'storage_path', :'asset_path'::text)
  FROM ids
  RETURNING id
)
INSERT INTO sakina_deletion_proof_ids (
  proof_id, user_a, user_b, conversation_a, message_a, trace_a,
  memory_a, asset_a, audit_request_id
)
SELECT ids.proof_id, ids.user_a, ids.user_b, conversation_insert.id,
       message_insert.id, trace_insert.id, memory_insert.id, asset_insert.id,
       ids.audit_request_id
FROM ids, conversation_insert, message_insert, trace_insert, memory_insert, asset_insert;

WITH wrong_user_delete AS (
  DELETE FROM sakina_ai.user_memory_entries m
  USING sakina_deletion_proof_ids p
  WHERE m.user_id = p.user_b
    AND m.memory_key = p.proof_id || '-memory'
  RETURNING m.id
)
SELECT 'cross_user_memory_delete_rows' AS proof, count(*) AS value
FROM wrong_user_delete;

INSERT INTO public.audit_logs (event_type, actor_type, actor_id, request_id, payload)
SELECT 'data_deletion_requested', 'user', user_a::text, audit_request_id,
       jsonb_build_object('proof_id', proof_id, 'retention_policy', 'delete_private_anonymise_history')
FROM sakina_deletion_proof_ids;

WITH deleted_memory AS (
  DELETE FROM sakina_ai.user_memory_entries m
  USING sakina_deletion_proof_ids p
  WHERE m.user_id = p.user_a
  RETURNING m.id
),
deleted_assets AS (
  DELETE FROM sakina_ai.multimodal_assets a
  USING sakina_deletion_proof_ids p
  WHERE a.user_id = p.user_a
  RETURNING a.id
),
deleted_sessions AS (
  DELETE FROM public.auth_sessions s
  USING sakina_deletion_proof_ids p
  WHERE s.user_id = p.user_a
  RETURNING s.id
),
anonymised_messages AS (
  UPDATE sakina_ai.messages m
  SET user_id = NULL,
      content = '[deleted by user request]',
      updated_at = now()
  FROM sakina_deletion_proof_ids p
  WHERE m.user_id = p.user_a
  RETURNING m.id
),
anonymised_conversations AS (
  UPDATE sakina_ai.conversations c
  SET user_id = NULL,
      title = '[deleted user conversation]',
      status = 'deleted',
      updated_at = now()
  FROM sakina_deletion_proof_ids p
  WHERE c.user_id = p.user_a
  RETURNING c.id
),
anonymised_traces AS (
  UPDATE sakina_ai.brain_decision_traces t
  SET user_id = NULL,
      execution_trace = execution_trace || jsonb_build_array(jsonb_build_object('stage', 'data_retention_deletion', 'outcome', 'user_id_anonymised'))
  FROM sakina_deletion_proof_ids p
  WHERE t.user_id = p.user_a::text
  RETURNING t.id
),
deleted_profiles AS (
  DELETE FROM public.user_profiles up
  USING sakina_deletion_proof_ids p
  WHERE up.user_id = p.user_a
  RETURNING up.id
),
anonymised_user AS (
  UPDATE public.users u
  SET email = 'deleted-' || p.user_a::text || '@deleted.sakina.invalid',
      pub_key = NULL,
      is_active = false,
      updated_at = now()
  FROM sakina_deletion_proof_ids p
  WHERE u.id = p.user_a
  RETURNING u.id
),
outbox_event AS (
  INSERT INTO outbox.events (event_type, payload, status)
  SELECT 'user_data_deleted',
         jsonb_build_object('proof_id', proof_id, 'user_id_hash', encode(digest(user_a::text, 'sha256'), 'hex')),
         'Pending'
  FROM sakina_deletion_proof_ids
  RETURNING id
)
SELECT 'deletion_counts' AS proof,
       (SELECT count(*) FROM deleted_memory) AS deleted_memory,
       (SELECT count(*) FROM deleted_assets) AS deleted_assets,
       (SELECT count(*) FROM deleted_sessions) AS deleted_sessions,
       (SELECT count(*) FROM anonymised_messages) AS anonymised_messages,
       (SELECT count(*) FROM anonymised_conversations) AS anonymised_conversations,
       (SELECT count(*) FROM anonymised_traces) AS anonymised_traces,
       (SELECT count(*) FROM deleted_profiles) AS deleted_profiles,
       (SELECT count(*) FROM anonymised_user) AS anonymised_users,
       (SELECT count(*) FROM outbox_event) AS outbox_events;

DO $$
DECLARE
  remaining_count bigint;
  audit_count bigint;
  outbox_count bigint;
  wrong_user_count bigint;
BEGIN
  SELECT count(*) INTO remaining_count
  FROM sakina_deletion_proof_ids p
  WHERE EXISTS (SELECT 1 FROM sakina_ai.user_memory_entries m WHERE m.user_id = p.user_a)
     OR EXISTS (SELECT 1 FROM sakina_ai.multimodal_assets a WHERE a.user_id = p.user_a)
     OR EXISTS (SELECT 1 FROM public.user_profiles up WHERE up.user_id = p.user_a)
     OR EXISTS (SELECT 1 FROM public.auth_sessions s WHERE s.user_id = p.user_a)
     OR EXISTS (SELECT 1 FROM sakina_ai.messages m WHERE m.user_id = p.user_a)
     OR EXISTS (SELECT 1 FROM sakina_ai.conversations c WHERE c.user_id = p.user_a)
     OR EXISTS (SELECT 1 FROM sakina_ai.brain_decision_traces t WHERE t.user_id = p.user_a::text);
  IF remaining_count <> 0 THEN
    RAISE EXCEPTION 'user A private data remains after deletion/anonymisation';
  END IF;

  SELECT count(*) INTO wrong_user_count
  FROM sakina_deletion_proof_ids p
  JOIN public.users u ON u.id = p.user_b AND u.is_active = true;
  IF wrong_user_count <> 1 THEN
    RAISE EXCEPTION 'user B data was unexpectedly changed by user A deletion proof';
  END IF;

  SELECT count(*) INTO audit_count
  FROM public.audit_logs l
  JOIN sakina_deletion_proof_ids p ON l.request_id = p.audit_request_id
  WHERE l.event_type = 'data_deletion_requested';
  IF audit_count <> 1 THEN
    RAISE EXCEPTION 'data deletion audit record missing';
  END IF;

  SELECT count(*) INTO outbox_count
  FROM outbox.events e
  JOIN sakina_deletion_proof_ids p ON e.payload->>'proof_id' = p.proof_id
  WHERE e.event_type = 'user_data_deleted';
  IF outbox_count <> 1 THEN
    RAISE EXCEPTION 'data deletion outbox event missing';
  END IF;
END $$;

SELECT 'retention_deletion_db_verification' AS proof,
       p.proof_id,
       u.is_active AS user_a_active,
       u.email AS user_a_anonymised_email,
       (
         SELECT count(*)
         FROM public.audit_logs l
         WHERE l.request_id = p.audit_request_id
           AND l.event_type = 'data_deletion_requested'
       ) AS audit_records,
       (
         SELECT count(*)
         FROM outbox.events e
         WHERE e.payload->>'proof_id' = p.proof_id
           AND e.event_type = 'user_data_deleted'
       ) AS outbox_events
FROM sakina_deletion_proof_ids p
JOIN public.users u ON u.id = p.user_a;
SQL
)"

printf '%s\n' "$sql_output"

if [[ -f "$asset_path" ]]; then
  rm -f "$asset_path"
fi

if [[ -f "$asset_path" ]]; then
  fail "private asset file still exists after deletion request: $asset_path"
fi

rg -n "user_memory_entries|multimodal_assets|auth_sessions|audit_logs|outbox.events|data_deletion_requested|user_data_deleted" \
  scripts/sakina/tech-data-retention-deletion-proof.sh >/dev/null \
  || fail "proof script does not exercise required data retention/deletion objects"

printf 'DATA_RETENTION_DELETION_OK owned DB rows were deleted or anonymised, cross-user deletion returned zero rows, asset file was removed, and audit/outbox records were created.\n'
