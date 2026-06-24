-- PHASE 5: entitlement usage limits, payment abstraction (no fake payment),
-- admin overrides, feature gates. Builds on entitlements(026) + subscription_plans(029).
BEGIN;

-- Daily/period usage counters for limited free features (e.g. ask).
CREATE TABLE IF NOT EXISTS sakina_ai.entitlement_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    usage_key TEXT NOT NULL,             -- 'ask' | 'scholar_submit' | ...
    usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
    used_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, usage_key, usage_date)
);
CREATE INDEX IF NOT EXISTS idx_entitlement_usage_user ON sakina_ai.entitlement_usage (user_id, usage_date);

-- Payment events (provider-agnostic). Webhook writes only verified events.
CREATE TABLE IF NOT EXISTS public.payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    provider TEXT NOT NULL DEFAULT 'stripe',
    event_type TEXT NOT NULL,
    external_id TEXT,
    status TEXT NOT NULL DEFAULT 'received',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payment_events_user ON public.payment_events (user_id);

-- Provider config status (live status is also computed from env at request time).
CREATE TABLE IF NOT EXISTS public.payment_provider_config_status (
    provider TEXT PRIMARY KEY,
    configured BOOLEAN NOT NULL DEFAULT false,
    mode TEXT NOT NULL DEFAULT 'test',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO public.payment_provider_config_status (provider, configured, mode)
VALUES ('stripe', false, 'test') ON CONFLICT (provider) DO NOTHING;

-- Admin entitlement overrides (audit of manual grant/revoke for testing).
CREATE TABLE IF NOT EXISTS public.admin_entitlement_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    entitlement_key TEXT NOT NULL,
    action TEXT NOT NULL,                -- 'grant' | 'revoke'
    granted_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Feature gates: which tier a feature needs + free limits.
CREATE TABLE IF NOT EXISTS public.feature_gates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_key TEXT NOT NULL UNIQUE,
    tier_required TEXT NOT NULL DEFAULT 'free',   -- free | premium
    free_limit INTEGER,                            -- daily limit for free tier (NULL = unlimited)
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- premium entitlement key for unlimited access.
INSERT INTO public.entitlements (entitlement_key, entitlement_name, description)
VALUES ('premium_unlimited','Premium Unlimited','Unlimited Ask, advanced study tools, premium features')
ON CONFLICT (entitlement_key) DO NOTHING;

INSERT INTO public.feature_gates (feature_key, tier_required, free_limit, description) VALUES
('ask_shaikh','free',20,'Ask AI Shaikh — free daily limit; premium unlimited'),
('scholar_submit','free',2,'Scholar review submissions — free monthly limit; premium extended'),
('advanced_quran_tools','premium',NULL,'Advanced Quran/Tafsir study tools'),
('advanced_hadith_tools','premium',NULL,'Advanced Hadith study tools'),
('advanced_zakat','premium',NULL,'Advanced zakat calculations'),
('advanced_mirath','premium',NULL,'Advanced mirath calculations'),
('family_profiles','premium',NULL,'Family profiles'),
('kids_progress_history','premium',NULL,'Kids learning progress history'),
('premium_reminders','premium',NULL,'Premium reminders & adhan customisation'),
('export_notes','premium',NULL,'Exportable Islamic study notes'),
('priority_escalation','premium',NULL,'Priority scholar escalation (placeholder)')
ON CONFLICT (feature_key) DO NOTHING;

-- RLS
ALTER TABLE sakina_ai.entitlement_usage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS entitlement_usage_self ON sakina_ai.entitlement_usage;
CREATE POLICY entitlement_usage_self ON sakina_ai.entitlement_usage
    FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
    WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payment_events_service ON public.payment_events;
CREATE POLICY payment_events_service ON public.payment_events FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

ALTER TABLE public.payment_provider_config_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ppcs_read ON public.payment_provider_config_status;
CREATE POLICY ppcs_read ON public.payment_provider_config_status FOR SELECT USING (true);
DROP POLICY IF EXISTS ppcs_service ON public.payment_provider_config_status;
CREATE POLICY ppcs_service ON public.payment_provider_config_status FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

ALTER TABLE public.admin_entitlement_overrides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS aeo_service ON public.admin_entitlement_overrides;
CREATE POLICY aeo_service ON public.admin_entitlement_overrides FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

ALTER TABLE public.feature_gates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS feature_gates_read ON public.feature_gates;
CREATE POLICY feature_gates_read ON public.feature_gates FOR SELECT USING (true);
DROP POLICY IF EXISTS feature_gates_service ON public.feature_gates;
CREATE POLICY feature_gates_service ON public.feature_gates FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

COMMIT;
