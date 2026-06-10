BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS sakina_ai;

CREATE OR REPLACE FUNCTION sakina_ai.current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('sakina.current_user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION sakina_ai.rls_service_role()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(current_setting('sakina.service_role', true), '') = 'on'
        OR current_user IN ('sakina_user', 'postgres', 'sakina_staging_user', 'sakina')
$$;
COMMIT;