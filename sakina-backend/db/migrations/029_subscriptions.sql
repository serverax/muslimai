-- SAK-012: subscription plans + user subscriptions (+ payment status).
-- services/auth.rs::get_user_tier joins public.user_subscriptions -> public.subscription_plans
-- (subscription_status='active', current_period_end). Those tables were never created
-- (get_user_tier errored). This adds them with RLS forced + seeds free/premium plans.
BEGIN;

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_key TEXT NOT NULL UNIQUE,
    plan_name TEXT NOT NULL,
    price_cents INTEGER NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'GBP',
    billing_interval TEXT NOT NULL DEFAULT 'month',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    subscription_status TEXT NOT NULL DEFAULT 'inactive',
    payment_status TEXT NOT NULL DEFAULT 'none',
    external_ref TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions (user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_plan_id ON public.user_subscriptions (plan_id);

-- Seed the canonical plans (idempotent).
INSERT INTO public.subscription_plans (plan_key, plan_name, price_cents, currency, billing_interval)
VALUES
    ('free',    'Sakina Free',    0,    'GBP', 'month'),
    ('premium', 'Sakina Premium', 999,  'GBP', 'month'),
    ('family',  'Sakina Family',  1499, 'GBP', 'month')
ON CONFLICT (plan_key) DO NOTHING;

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS subscription_plans_read ON public.subscription_plans;
CREATE POLICY subscription_plans_read ON public.subscription_plans FOR SELECT USING (true);
DROP POLICY IF EXISTS subscription_plans_service ON public.subscription_plans;
CREATE POLICY subscription_plans_service ON public.subscription_plans
    FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_subscriptions_self ON public.user_subscriptions;
CREATE POLICY user_subscriptions_self ON public.user_subscriptions
    FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
    WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

COMMIT;
