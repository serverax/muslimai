#!/usr/bin/env bash
set -euo pipefail

PSQL="${PSQL:-psql}"
DB_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"

"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
SELECT set_config('sakina.service_role', 'on', false);
DROP OWNED BY sakina_rls_probe;
DROP ROLE IF EXISTS sakina_rls_probe;
CREATE ROLE sakina_rls_probe LOGIN;
GRANT USAGE ON SCHEMA public, sakina_ai TO sakina_rls_probe;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sakina_rls_probe;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sakina_ai TO sakina_rls_probe;

INSERT INTO public.users (email, auth_provider, is_active)
VALUES
    ('rls-user-a@example.com', 'rls-test', true),
    ('rls-user-b@example.com', 'rls-test', true)
ON CONFLICT (email)
DO UPDATE SET updated_at = now();

INSERT INTO sakina_ai.conversations (user_id, title)
SELECT id, 'RLS user A conversation'
FROM public.users
WHERE email = 'rls-user-a@example.com';

INSERT INTO sakina_ai.user_memory_entries (
    user_id, memory_key, memory_type, encrypted_payload, nonce, consent_granted, allowed
)
SELECT id, 'rls-proof', 'preference', decode('01', 'hex'), decode('02', 'hex'), true, true
FROM public.users
WHERE email = 'rls-user-a@example.com';

SELECT
    (SELECT id FROM public.users WHERE email = 'rls-user-a@example.com') AS user_a,
    (SELECT id FROM public.users WHERE email = 'rls-user-b@example.com') AS user_b;

SELECT set_config('sakina.service_role', 'off', false);
SELECT set_config('sakina.current_user_id', (SELECT id::text FROM public.users WHERE email = 'rls-user-b@example.com'), false);
SET ROLE sakina_rls_probe;

SELECT
    (SELECT count(*) FROM sakina_ai.conversations WHERE title = 'RLS user A conversation') AS user_b_visible_user_a_conversations,
    (SELECT count(*) FROM sakina_ai.user_memory_entries WHERE memory_key = 'rls-proof') AS user_b_visible_user_a_memories;
SQL
