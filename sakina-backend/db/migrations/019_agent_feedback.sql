CREATE TABLE IF NOT EXISTS sakina_ai.agent_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating BOOLEAN NOT NULL,
    label TEXT NOT NULL,
    reasoning_trace JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_feedback_trace
    ON sakina_ai.agent_feedback (trace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_feedback_user
    ON sakina_ai.agent_feedback (user_id, created_at DESC);

ALTER TABLE sakina_ai.agent_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE sakina_ai.agent_feedback FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_sakina_agent_feedback_service ON sakina_ai.agent_feedback;
CREATE POLICY rls_sakina_agent_feedback_service ON sakina_ai.agent_feedback
FOR ALL
USING (sakina_ai.rls_service_role())
WITH CHECK (sakina_ai.rls_service_role());

DROP POLICY IF EXISTS rls_sakina_agent_feedback_user ON sakina_ai.agent_feedback;
CREATE POLICY rls_sakina_agent_feedback_user ON sakina_ai.agent_feedback
FOR ALL
USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());
