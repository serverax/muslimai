#!/usr/bin/env bash
set -euo pipefail

PSQL="${PSQL:-psql}"
DB_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"

"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DROP OWNED BY sakina_rls_probe;
DROP ROLE IF EXISTS sakina_rls_probe;
CREATE ROLE sakina_rls_probe;
GRANT USAGE ON SCHEMA public, sakina_ai TO sakina_rls_probe;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sakina_rls_probe;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sakina_ai TO sakina_rls_probe;

SELECT set_config('sakina.service_role', 'on', false);
SELECT set_config('sakina.current_user_id', '', false);

CREATE TEMP TABLE sakina_rls_ids AS
WITH
user_a AS (
    INSERT INTO public.users (email, auth_provider, is_active)
    VALUES ('rls-user-a-' || gen_random_uuid() || '@example.com', 'rls-proof', true)
    RETURNING id
),
user_b AS (
    INSERT INTO public.users (email, auth_provider, is_active)
    VALUES ('rls-user-b-' || gen_random_uuid() || '@example.com', 'rls-proof', true)
    RETURNING id
)
SELECT user_a.id AS user_a, user_b.id AS user_b, gen_random_uuid()::text AS marker FROM user_a, user_b;
GRANT SELECT ON sakina_rls_ids TO sakina_rls_probe;

INSERT INTO public.user_profiles (user_id, full_name, display_name, timezone, madhhab_preference, metadata)
SELECT user_a, 'RLS User A', 'rls-a', 'UTC', 'hanafi', jsonb_build_object('proof', marker)
FROM sakina_rls_ids;

INSERT INTO sakina_ai.conversations (user_id, title)
SELECT user_a, 'RLS user A conversation ' || marker
FROM sakina_rls_ids;

INSERT INTO sakina_ai.user_memory_entries (
    user_id, memory_key, memory_type, encrypted_payload, nonce, consent_granted, allowed
)
SELECT user_a, 'rls-proof-' || marker, 'preference', decode('01', 'hex'), decode('02', 'hex'), true, true
FROM sakina_rls_ids;

INSERT INTO sakina_ai.brain_decision_traces (
    request_id,
    user_id,
    input_type,
    intent,
    language,
    risk_level,
    selected_agent,
    selected_model,
    selected_pipeline,
    source_strategy,
    evaluation_result,
    final_action,
    audit_event_id,
    execution_trace
)
SELECT
    gen_random_uuid(),
    user_a,
    'text',
    'fiqh',
    'en',
    'low',
    'quran_agent',
    'disabled_closed',
    'rag_verified_sources',
    'verified_sources_only',
    '{"grounded":true}'::jsonb,
    'respond',
    gen_random_uuid(),
    jsonb_build_object('proof', marker)
FROM sakina_rls_ids;

SET ROLE sakina_rls_probe;
SELECT set_config('sakina.service_role', 'off', false);
SELECT set_config('sakina.current_user_id', (SELECT user_a::text FROM sakina_rls_ids), false);

DO $$
DECLARE
    visible_count integer;
BEGIN
    SELECT
        (SELECT count(*) FROM public.user_profiles WHERE metadata->>'proof' = (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.conversations WHERE title = 'RLS user A conversation ' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.user_memory_entries WHERE memory_key = 'rls-proof-' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.brain_decision_traces WHERE execution_trace->>'proof' = (SELECT marker FROM sakina_rls_ids))
    INTO visible_count;
    IF visible_count <> 4 THEN
        RAISE EXCEPTION 'user A should see four own records, saw %', visible_count;
    END IF;
END $$;

SELECT set_config('sakina.current_user_id', (SELECT user_b::text FROM sakina_rls_ids), false);

DO $$
DECLARE
    visible_count integer;
BEGIN
    SELECT
        (SELECT count(*) FROM public.user_profiles WHERE metadata->>'proof' = (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.conversations WHERE title = 'RLS user A conversation ' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.user_memory_entries WHERE memory_key = 'rls-proof-' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.brain_decision_traces WHERE execution_trace->>'proof' = (SELECT marker FROM sakina_rls_ids))
    INTO visible_count;
    IF visible_count <> 0 THEN
        RAISE EXCEPTION 'user B should see zero user A records, saw %', visible_count;
    END IF;
END $$;

SELECT set_config('sakina.current_user_id', '', false);

DO $$
DECLARE
    visible_count integer;
BEGIN
    SELECT
        (SELECT count(*) FROM public.user_profiles WHERE metadata->>'proof' = (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.conversations WHERE title = 'RLS user A conversation ' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.user_memory_entries WHERE memory_key = 'rls-proof-' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.brain_decision_traces WHERE execution_trace->>'proof' = (SELECT marker FROM sakina_rls_ids))
    INTO visible_count;
    IF visible_count <> 0 THEN
        RAISE EXCEPTION 'unauthenticated context should see zero user records, saw %', visible_count;
    END IF;
END $$;

RESET ROLE;
SELECT set_config('sakina.service_role', 'on', false);
SELECT set_config('sakina.current_user_id', '', false);

DO $$
DECLARE
    visible_count integer;
BEGIN
    SELECT
        (SELECT count(*) FROM public.user_profiles WHERE metadata->>'proof' = (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.conversations WHERE title = 'RLS user A conversation ' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.user_memory_entries WHERE memory_key = 'rls-proof-' || (SELECT marker FROM sakina_rls_ids)) +
        (SELECT count(*) FROM sakina_ai.brain_decision_traces WHERE execution_trace->>'proof' = (SELECT marker FROM sakina_rls_ids))
    INTO visible_count;
    IF visible_count <> 4 THEN
        RAISE EXCEPTION 'service role should see four records for controlled admin access, saw %', visible_count;
    END IF;
END $$;

INSERT INTO public.audit_logs (event_type, actor_type, actor_id, request_id, payload)
SELECT 'rls_service_probe', 'service', user_a::text, gen_random_uuid()::text, '{"controlled_service_access":true}'::jsonb
FROM sakina_rls_ids;

SELECT
    (SELECT user_a FROM sakina_rls_ids) AS user_a,
    (SELECT user_b FROM sakina_rls_ids) AS user_b,
    'DB USER ISOLATION PASS' AS result;
SQL
