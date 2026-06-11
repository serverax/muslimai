BEGIN;

CREATE TABLE IF NOT EXISTS sakina_ai.scholar_resolved_answers (
    review_id UUID PRIMARY KEY REFERENCES sakina_ai.scholar_review_queue(id) ON DELETE CASCADE,
    final_answer TEXT NOT NULL,
    resolved_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE sakina_ai.scholar_resolved_answers ENABLE ROW LEVEL SECURITY;

-- Service role can do everything
CREATE POLICY rls_sakina_ai_scholar_resolved_answers_service ON sakina_ai.scholar_resolved_answers
    FOR ALL USING (sakina_ai.rls_service_role())
    WITH CHECK (sakina_ai.rls_service_role());

COMMIT;
