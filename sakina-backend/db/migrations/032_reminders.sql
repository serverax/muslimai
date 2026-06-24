-- PHASE 2: backend-synced reminder records (login required, user-isolated).
-- NOTE: this stores reminder RULES only. Actual local notification firing is a
-- mobile-device concern and is NOT implemented/claimed here.
BEGIN;

CREATE TABLE IF NOT EXISTS sakina_ai.reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    reminder_type TEXT NOT NULL DEFAULT 'custom',  -- 'prayer' | 'dua' | 'custom'
    schedule_rule TEXT,                            -- free text, e.g. 'daily 07:00'
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reminders_user_id ON sakina_ai.reminders (user_id);

ALTER TABLE sakina_ai.reminders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reminders_self ON sakina_ai.reminders;
CREATE POLICY reminders_self ON sakina_ai.reminders
    FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
    WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

COMMIT;
