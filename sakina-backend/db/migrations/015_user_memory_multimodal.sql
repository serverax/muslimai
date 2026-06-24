CREATE TABLE IF NOT EXISTS sakina_ai.user_memory_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    memory_key TEXT NOT NULL,
    memory_type TEXT NOT NULL,
    sensitivity_level TEXT NOT NULL DEFAULT 'safe',
    encrypted_payload BYTEA NOT NULL,
    nonce BYTEA NOT NULL,
    encryption_version TEXT NOT NULL DEFAULT 'xor-sha256-v1',
    consent_required BOOLEAN NOT NULL DEFAULT FALSE,
    consent_granted BOOLEAN NOT NULL DEFAULT FALSE,
    allowed BOOLEAN NOT NULL DEFAULT FALSE,
    source_language TEXT NOT NULL DEFAULT 'en',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.multimodal_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    asset_type TEXT NOT NULL,
    original_name TEXT NOT NULL,
    storage_scope TEXT NOT NULL DEFAULT 'user',
    redacted_text TEXT NOT NULL DEFAULT '',
    extracted_text TEXT NOT NULL DEFAULT '',
    safety_level TEXT NOT NULL DEFAULT 'safe',
    status TEXT NOT NULL DEFAULT 'received',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_memory_entries_user_key
    ON sakina_ai.user_memory_entries (user_id, memory_key, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_memory_entries_user_type
    ON sakina_ai.user_memory_entries (user_id, memory_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_multimodal_assets_user_type
    ON sakina_ai.multimodal_assets (user_id, asset_type, created_at DESC);
