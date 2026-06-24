CREATE TABLE IF NOT EXISTS sakina_ai.workspaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT 'Personal workspace',
    is_default BOOLEAN NOT NULL DEFAULT TRUE,
    encryption_status TEXT NOT NULL DEFAULT 'server_managed',
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, is_default)
);

ALTER TABLE sakina_ai.conversations
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE sakina_ai.messages
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE sakina_ai.user_memory_entries
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;

ALTER TABLE sakina_ai.brain_decision_traces
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE;

ALTER TABLE sakina_ai.brain_evaluation_results
    ADD COLUMN IF NOT EXISTS user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE;

ALTER TABLE sakina_ai.brain_memory_events
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE;

ALTER TABLE sakina_ai.brain_cache_metadata
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE;

ALTER TABLE sakina_ai.multimodal_assets
    ADD COLUMN IF NOT EXISTS workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS encryption_status TEXT NOT NULL DEFAULT 'private_storage';

CREATE TABLE IF NOT EXISTS sakina_ai.user_learning_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    preference_key TEXT NOT NULL,
    preference_value TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'brain',
    confidence NUMERIC(5,4) NOT NULL DEFAULT 0.8000,
    encryption_status TEXT NOT NULL DEFAULT 'server_managed',
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, workspace_id, preference_key)
);

CREATE TABLE IF NOT EXISTS sakina_ai.user_habit_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL,
    signal_value TEXT NOT NULL,
    confidence NUMERIC(5,4) NOT NULL DEFAULT 0.5000,
    encryption_status TEXT NOT NULL DEFAULT 'server_managed',
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.user_interest_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'brain',
    confidence NUMERIC(5,4) NOT NULL DEFAULT 0.5000,
    encryption_status TEXT NOT NULL DEFAULT 'server_managed',
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.user_memory_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    learning_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    local_memory_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    server_memory_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, workspace_id)
);

CREATE TABLE IF NOT EXISTS sakina_ai.mobile_memory_sync (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    device_id TEXT NULL,
    local_context_hash TEXT NOT NULL,
    allowed_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    encryption_status TEXT NOT NULL DEFAULT 'client_encrypted_or_redacted',
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workspaces_user_default
    ON sakina_ai.workspaces (user_id, is_default);
CREATE INDEX IF NOT EXISTS idx_conversations_user_workspace
    ON sakina_ai.conversations (user_id, workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_user_workspace
    ON sakina_ai.messages (user_id, workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_memory_entries_workspace
    ON sakina_ai.user_memory_entries (user_id, workspace_id, memory_key, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_brain_decision_traces_user_workspace
    ON sakina_ai.brain_decision_traces (user_id, workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_learning_preferences_user_workspace
    ON sakina_ai.user_learning_preferences (user_id, workspace_id, preference_key);
CREATE INDEX IF NOT EXISTS idx_habit_signals_user_workspace
    ON sakina_ai.user_habit_signals (user_id, workspace_id, signal_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interest_signals_user_workspace
    ON sakina_ai.user_interest_signals (user_id, workspace_id, topic, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mobile_memory_sync_user_workspace
    ON sakina_ai.mobile_memory_sync (user_id, workspace_id, created_at DESC);

CREATE OR REPLACE FUNCTION sakina_ai.ensure_default_workspace(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_workspace_id UUID;
BEGIN
    SELECT id INTO v_workspace_id
    FROM sakina_ai.workspaces
    WHERE user_id = p_user_id
      AND is_default = TRUE
      AND deleted_at IS NULL
    LIMIT 1;

    IF v_workspace_id IS NULL THEN
        INSERT INTO sakina_ai.workspaces (user_id, name, is_default)
        VALUES (p_user_id, 'Personal workspace', TRUE)
        ON CONFLICT (user_id, is_default)
        DO UPDATE SET updated_at = NOW()
        RETURNING id INTO v_workspace_id;
    END IF;

    INSERT INTO sakina_ai.user_memory_permissions (
        user_id, workspace_id, learning_enabled, local_memory_enabled, server_memory_enabled
    )
    VALUES (p_user_id, v_workspace_id, TRUE, TRUE, TRUE)
    ON CONFLICT (user_id, workspace_id)
    DO NOTHING;

    RETURN v_workspace_id;
END $$;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'workspaces',
        'user_learning_preferences',
        'user_habit_signals',
        'user_interest_signals',
        'user_memory_permissions',
        'mobile_memory_sync'
    ]
    LOOP
        EXECUTE format('ALTER TABLE sakina_ai.%I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('ALTER TABLE sakina_ai.%I FORCE ROW LEVEL SECURITY', tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I ON sakina_ai.%I', 'rls_sakina_ai_' || tbl || '_service', tbl);
        EXECUTE format(
            'CREATE POLICY %I ON sakina_ai.%I FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role())',
            'rls_sakina_ai_' || tbl || '_service',
            tbl
        );
        EXECUTE format('DROP POLICY IF EXISTS %I ON sakina_ai.%I', 'rls_sakina_ai_' || tbl || '_user', tbl);
        EXECUTE format(
            'CREATE POLICY %I ON sakina_ai.%I FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role()) WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())',
            'rls_sakina_ai_' || tbl || '_user',
            tbl
        );
    END LOOP;
END $$;
