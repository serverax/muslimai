BEGIN;

-- 1. Entitlements
CREATE TABLE IF NOT EXISTS public.entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entitlement_key TEXT NOT NULL UNIQUE,
    entitlement_name TEXT NOT NULL,
    description TEXT,
    entitlement_scope TEXT NOT NULL DEFAULT 'module',
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. User Entitlements
CREATE TABLE IF NOT EXISTS public.user_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    entitlement_id UUID NOT NULL REFERENCES public.entitlements(id) ON DELETE CASCADE,
    subscription_id UUID NULL, -- Optional link to user_subscriptions if implemented
    granted_by TEXT NOT NULL DEFAULT 'system',
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entitlement_id)
);

-- 3. Seed basic entitlements
INSERT INTO public.entitlements (entitlement_key, entitlement_name, description)
VALUES 
('quran_access', 'Quran Reader Access', 'Full access to Quran module'),
('prayer_access', 'Prayer Tools Access', 'Full access to prayer times and tools'),
('knowledge_access', 'Islamic Knowledge Access', 'Access to Tafsir and Hadith modules'),
('community_access', 'Community Access', 'Access to community features'),
('chat_access', 'AI Chat Access', 'Access to basic AI chat')
ON CONFLICT (entitlement_key) DO NOTHING;

-- 4. Enable RLS
ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

-- Service role policies
CREATE POLICY rls_public_entitlements_service ON public.entitlements
    FOR ALL USING (sakina_ai.rls_service_role())
    WITH CHECK (sakina_ai.rls_service_role());

CREATE POLICY rls_public_user_entitlements_service ON public.user_entitlements
    FOR ALL USING (sakina_ai.rls_service_role())
    WITH CHECK (sakina_ai.rls_service_role());

-- User policy
CREATE POLICY user_entitlement_read ON public.user_entitlements
    FOR SELECT USING (user_id = sakina_ai.current_user_id());

COMMIT;
