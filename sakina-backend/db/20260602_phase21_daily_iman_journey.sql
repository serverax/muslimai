CREATE TABLE IF NOT EXISTS public.iman_journey_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    journey_date DATE NOT NULL,
    today_focus TEXT NOT NULL,
    continue_yesterday_topic TEXT,
    prayer_progress SMALLINT NOT NULL DEFAULT 0,
    quran_progress SMALLINT NOT NULL DEFAULT 0,
    dhikr_progress SMALLINT NOT NULL DEFAULT 0,
    ask_sakina_today_context TEXT,
    tomorrow_follow_up TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, journey_date)
);

CREATE TABLE IF NOT EXISTS public.iman_journey_evidence_bundles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    journey_date DATE NOT NULL,
    reminder_text TEXT,
    confidence_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    evidence_bundle JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, journey_date)
);

CREATE TABLE IF NOT EXISTS public.iman_journey_privacy_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    personalization_enabled BOOLEAN NOT NULL DEFAULT false,
    reminders_enabled BOOLEAN NOT NULL DEFAULT false,
    store_journey_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.iman_family_reminder_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    consent_granted BOOLEAN NOT NULL DEFAULT false,
    reminder_text TEXT,
    notify_family BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.iman_personal_dua_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    dua_text TEXT NOT NULL,
    is_answered BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iman_journey_daily_user_date
    ON public.iman_journey_daily (user_id, journey_date DESC);

CREATE INDEX IF NOT EXISTS idx_iman_journey_evidence_user_date
    ON public.iman_journey_evidence_bundles (user_id, journey_date DESC);

CREATE INDEX IF NOT EXISTS idx_iman_family_consent_lookup
    ON public.iman_family_reminder_settings (consent_granted, user_id);

CREATE INDEX IF NOT EXISTS idx_iman_privacy_lookup
    ON public.iman_journey_privacy_settings (user_id, personalization_enabled, reminders_enabled);

CREATE INDEX IF NOT EXISTS idx_iman_dua_user_created
    ON public.iman_personal_dua_list (user_id, created_at DESC);
