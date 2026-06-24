-- SAK-008: scholar_accounts table.
-- create_scholar_account (services/phase2.rs) inserts into public.scholar_accounts,
-- but no prior migration created it (runtime: relation does not exist). This adds it,
-- with RLS forced (the migrate runner asserts rowsecurity=true on all public tables).
BEGIN;

CREATE TABLE IF NOT EXISTS public.scholar_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    scholar_slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT false,
    credentials_summary TEXT,
    account_status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scholar_accounts_user_id ON public.scholar_accounts (user_id);

ALTER TABLE public.scholar_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS scholar_accounts_service ON public.scholar_accounts;
CREATE POLICY scholar_accounts_service ON public.scholar_accounts
    FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

COMMIT;
