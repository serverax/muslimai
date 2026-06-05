CREATE SCHEMA IF NOT EXISTS outbox;

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    actor_type TEXT NOT NULL DEFAULT 'system',
    actor_id TEXT,
    request_id TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_request_event
    ON public.audit_logs (request_id, event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON public.audit_logs (actor_id, created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_public_audit_logs_service ON public.audit_logs;
CREATE POLICY rls_public_audit_logs_service ON public.audit_logs
FOR ALL
USING (sakina_ai.rls_service_role())
WITH CHECK (sakina_ai.rls_service_role());

CREATE TABLE IF NOT EXISTS outbox.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending',
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outbox_events_type_status
    ON outbox.events (event_type, status, created_at DESC);

ALTER TABLE outbox.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE outbox.events FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_outbox_events_service ON outbox.events;
CREATE POLICY rls_outbox_events_service ON outbox.events
FOR ALL
USING (sakina_ai.rls_service_role())
WITH CHECK (sakina_ai.rls_service_role());

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
