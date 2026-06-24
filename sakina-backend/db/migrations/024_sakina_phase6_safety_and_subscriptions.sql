-- Sakina AI Phase 6 Schema Migration: Safety, Usage, and User Context
-- This migration fulfills the database schema requirements for strict safety guardrails and paid feature enforcement.

BEGIN;

-- ============================================================================
-- 1. SAFETY AND GUARDRAIL TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.safety_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_key TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL, -- e.g., 'fatwa', 'medical', 'legal', 'general'
    description TEXT NOT NULL,
    action_required TEXT NOT NULL, -- 'block', 'escalate', 'warn'
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Note: sakina_ai.safety_classifications already exists and acts as safety_events
-- We add specific event tables for explicit tracking and auditing.

CREATE TABLE IF NOT EXISTS sakina_ai.out_of_scope_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    detected_intent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.medical_emergency_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.self_harm_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.high_risk_fatwa_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    escalation_status TEXT NOT NULL DEFAULT 'blocked', -- blocked, escalated_to_scholar
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.prompt_injection_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    pattern_detected TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.pii_redaction_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    original_text_hash TEXT NOT NULL, -- Hash only for auditing, never store raw PII
    entities_redacted TEXT[] NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.blocked_answer_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    policy_triggered TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 2. PAID FEATURES AND USAGE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.feature_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    feature_key TEXT NOT NULL, -- e.g., 'ask_shaikh', 'tafsir_compare'
    usage_count INTEGER NOT NULL DEFAULT 1,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, feature_key, period_start)
);

CREATE TABLE IF NOT EXISTS public.usage_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL, -- references public.subscription_plans
    feature_key TEXT NOT NULL,
    max_usage INTEGER NOT NULL, -- -1 for unlimited
    period TEXT NOT NULL, -- 'daily', 'monthly'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.premium_unlocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    feature_key TEXT NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ, -- NULL if lifetime unlock
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.billing_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL, -- e.g., 'subscription_started', 'payment_failed'
    provider_reference TEXT,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 3. USER CONTEXT AND ISOLATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_madhhab_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    madhhab TEXT NOT NULL, -- e.g., 'Hanafi', 'Shafi''i', 'Maliki', 'Hanbali'
    aqidah TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS public.user_country_context (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    country_code TEXT NOT NULL, -- ISO 3166-1 alpha-2
    timezone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS public.user_safety_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    flag_type TEXT NOT NULL, -- e.g., 'requires_strict_filtering', 'frequent_escalations'
    reason TEXT,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.workspace_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member', -- owner, member, guest (for family accounts)
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (workspace_id, user_id)
);

-- ============================================================================
-- 4. RLS POLICIES
-- ============================================================================

-- Safety Rules (Public Read for verification)
ALTER TABLE sakina_ai.safety_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_safety_rules ON sakina_ai.safety_rules FOR SELECT USING (true);

-- Safety Events (Restricted to User and Admin)
ALTER TABLE sakina_ai.out_of_scope_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_out_of_scope ON sakina_ai.out_of_scope_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE sakina_ai.medical_emergency_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_medical ON sakina_ai.medical_emergency_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE sakina_ai.self_harm_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_self_harm ON sakina_ai.self_harm_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE sakina_ai.high_risk_fatwa_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_high_risk_fatwa ON sakina_ai.high_risk_fatwa_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE sakina_ai.prompt_injection_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_prompt_injection ON sakina_ai.prompt_injection_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE sakina_ai.pii_redaction_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_pii_redaction ON sakina_ai.pii_redaction_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

ALTER TABLE sakina_ai.blocked_answer_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_admin_blocked_answers ON sakina_ai.blocked_answer_events FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

-- Feature Usage & Billing (User Isolated)
ALTER TABLE public.feature_usage ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_feature_usage ON public.feature_usage FOR ALL USING (user_id = sakina_ai.current_user_id());

ALTER TABLE public.usage_limits ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_usage_limits ON public.usage_limits FOR SELECT USING (true);

ALTER TABLE public.premium_unlocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_premium_unlocks ON public.premium_unlocks FOR ALL USING (user_id = sakina_ai.current_user_id());

ALTER TABLE public.billing_audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_billing_logs ON public.billing_audit_logs FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

-- User Preferences & Members (User Isolated)
ALTER TABLE public.user_madhhab_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_madhhab_pref ON public.user_madhhab_preferences FOR ALL USING (user_id = sakina_ai.current_user_id());

ALTER TABLE public.user_country_context ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_country_ctx ON public.user_country_context FOR ALL USING (user_id = sakina_ai.current_user_id());

ALTER TABLE public.user_safety_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_safety_flg ON public.user_safety_flags FOR ALL USING (user_id = sakina_ai.current_user_id());

ALTER TABLE sakina_ai.workspace_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_workspace_membership ON sakina_ai.workspace_members FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

COMMIT;
