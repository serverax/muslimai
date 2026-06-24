-- SAK-028: sakina_ai.safety_classifications table.
-- log_safety_classification (services/phase2.rs) and dashboard::get_guardrails both
-- target sakina_ai.safety_classifications, but it was only defined in the un-run
-- db/20260529_phase3 file (runtime: to_regclass NULL → dashboard 500, log insert fail).
-- This creates it (shape from the phase3 reference) with RLS forced.
BEGIN;

CREATE TABLE IF NOT EXISTS sakina_ai.safety_classifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    safety_level TEXT NOT NULL,
    islamic_sensitivity TEXT NOT NULL DEFAULT 'unknown',
    classifier_version TEXT NOT NULL DEFAULT 'v1',
    classifier_output JSONB NOT NULL DEFAULT '{}'::jsonb,
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_safety_classifications_created_at
    ON sakina_ai.safety_classifications (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_safety_classifications_user_id
    ON sakina_ai.safety_classifications (user_id);

ALTER TABLE sakina_ai.safety_classifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS safety_classifications_service ON sakina_ai.safety_classifications;
CREATE POLICY safety_classifications_service ON sakina_ai.safety_classifications
    FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

COMMIT;
