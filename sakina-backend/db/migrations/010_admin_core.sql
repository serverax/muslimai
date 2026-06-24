-- Sakina AI Phase 4.1: Admin Tables for Verification & Moderation
-- Idempotent for repeat local QA migrate runs.

BEGIN;

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    admin_email TEXT UNIQUE,
    account_status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_key TEXT NOT NULL UNIQUE,
    role_name TEXT NOT NULL,
    is_system BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_key TEXT NOT NULL UNIQUE,
    permission_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'admin_users'
          AND policyname = 'admin_users_isolation'
    ) THEN
        CREATE POLICY admin_users_isolation ON public.admin_users
            FOR ALL USING (sakina_ai.rls_service_role());
    END IF;
END $$;

ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'admin_roles'
          AND policyname = 'admin_roles_read'
    ) THEN
        CREATE POLICY admin_roles_read ON public.admin_roles FOR SELECT USING (true);
    END IF;
END $$;

ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'admin_permissions'
          AND policyname = 'admin_perms_read'
    ) THEN
        CREATE POLICY admin_perms_read ON public.admin_permissions FOR SELECT USING (true);
    END IF;
END $$;

COMMIT;
