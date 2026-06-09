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
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
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

COMMIT;
