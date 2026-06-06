-- SAKINA full product DB schema package - Revision 2
-- Schema-only package. No deployment commands in this file.
-- Policy: idempotent, non-destructive, no secrets.
-- Rollback companion: 20260529_phase3_full_product_schema_revision2_rollback_procedure.md

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS sakina_ai;

-- ---------------------------------------------------------------------------
-- Domain 1: users/auth
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pub_key TEXT UNIQUE,
    email TEXT UNIQUE,
    auth_provider TEXT NOT NULL DEFAULT 'internal',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS auth_provider TEXT DEFAULT 'internal',
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE TABLE IF NOT EXISTS public.auth_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_user_id TEXT NOT NULL,
    provider_email TEXT,
    email_verified_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_user_id)
);

CREATE TABLE IF NOT EXISTS public.auth_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    session_token_hash TEXT NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.auth_refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.auth_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_identities_user_id
    ON public.auth_identities (user_id, provider);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id
    ON public.auth_sessions (user_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_auth_refresh_tokens_user_id
    ON public.auth_refresh_tokens (user_id, expires_at DESC);

-- ---------------------------------------------------------------------------
-- Domain 2/3: user profiles + family/child profiles
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    full_name TEXT,
    display_name TEXT,
    avatar_url TEXT,
    country_code VARCHAR(8),
    timezone VARCHAR(64),
    date_of_birth DATE,
    madhhab_preference TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS full_name TEXT,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS date_of_birth DATE,
    ADD COLUMN IF NOT EXISTS madhhab_preference TEXT;

CREATE TABLE IF NOT EXISTS public.family_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    family_name TEXT NOT NULL,
    household_size INTEGER,
    location_country_code VARCHAR(8),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.child_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_profile_id UUID NOT NULL REFERENCES public.family_profiles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    preferred_name TEXT NOT NULL,
    birth_year INTEGER,
    learning_level TEXT,
    notes TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.profile_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    preference_key TEXT NOT NULL,
    preference_value JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, preference_key)
);

CREATE TABLE IF NOT EXISTS public.language_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    ui_language VARCHAR(8) NOT NULL DEFAULT 'en',
    content_language VARCHAR(8) NOT NULL DEFAULT 'en',
    transliteration_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    in_app_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT false,
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.privacy_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    profile_visibility TEXT NOT NULL DEFAULT 'private',
    data_export_allowed BOOLEAN NOT NULL DEFAULT true,
    analytics_opt_in BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.accessibility_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    text_scale NUMERIC(4,2) NOT NULL DEFAULT 1.00,
    high_contrast_enabled BOOLEAN NOT NULL DEFAULT false,
    reduced_motion_enabled BOOLEAN NOT NULL DEFAULT false,
    screen_reader_optimized BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_family_profiles_user_id
    ON public.family_profiles (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_child_profiles_family_profile_id
    ON public.child_profiles (family_profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_preferences_user_id
    ON public.profile_preferences (user_id);

-- ---------------------------------------------------------------------------
-- Domain 4: conversations/messages
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sakina_ai.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
    title TEXT NOT NULL DEFAULT 'New conversation',
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES sakina_ai.conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    source_language VARCHAR(8) NOT NULL DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE sakina_ai.conversations
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

ALTER TABLE sakina_ai.messages
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS source_language VARCHAR(8) DEFAULT 'en',
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_sakina_ai_conversations_user_created
    ON sakina_ai.conversations (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sakina_ai_messages_conversation_created
    ON sakina_ai.messages (conversation_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Domains 5/6/7/8/9/19: Islamic DB, RAG, Mastermind, Safety, Scholar, WASM
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_source_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    provider_status TEXT NOT NULL DEFAULT 'pending',
    provider_type TEXT NOT NULL DEFAULT 'api',
    base_url TEXT,
    docs_url TEXT,
    auth_scheme TEXT NOT NULL DEFAULT 'none',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_key TEXT NOT NULL UNIQUE,
    source_type TEXT NOT NULL,
    source_status TEXT NOT NULL DEFAULT 'pending',
    language VARCHAR(8) NOT NULL DEFAULT 'en',
    title TEXT NOT NULL,
    canonical_url TEXT,
    review_status TEXT NOT NULL DEFAULT 'scholar_review_required',
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ,
    rejected_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_source_licences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    provider_id UUID REFERENCES sakina_ai.islamic_source_providers(id) ON DELETE SET NULL,
    licence_name TEXT NOT NULL,
    licence_version TEXT,
    licence_url TEXT,
    attribution_required BOOLEAN NOT NULL DEFAULT true,
    commercial_use_allowed BOOLEAN NOT NULL DEFAULT false,
    derivative_use_allowed BOOLEAN NOT NULL DEFAULT false,
    review_status TEXT NOT NULL DEFAULT 'pending',
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    rejected_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sakina_ai.islamic_sources(id) ON DELETE RESTRICT,
    document_key TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    document_url TEXT,
    language VARCHAR(8) NOT NULL DEFAULT 'en',
    source_status TEXT NOT NULL DEFAULT 'pending',
    source_type TEXT NOT NULL,
    review_status TEXT NOT NULL DEFAULT 'scholar_review_required',
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ,
    rejected_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES sakina_ai.islamic_documents(id) ON DELETE CASCADE,
    chunk_key TEXT NOT NULL UNIQUE,
    chunk_index INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    citation_text TEXT NOT NULL DEFAULT '',
    language VARCHAR(8) NOT NULL DEFAULT 'en',
    source_type TEXT NOT NULL,
    source_status TEXT NOT NULL DEFAULT 'pending',
    review_status TEXT NOT NULL DEFAULT 'scholar_review_required',
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ,
    rejected_reason TEXT,
    token_count INTEGER,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (document_id, chunk_index)
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id UUID NOT NULL REFERENCES sakina_ai.islamic_chunks(id) ON DELETE CASCADE,
    embedding_ref TEXT NOT NULL UNIQUE,
    vector_store TEXT NOT NULL DEFAULT 'sakina-qdrant',
    vector_collection TEXT NOT NULL DEFAULT 'verified_knowledge',
    vector_id TEXT NOT NULL,
    embedding_model TEXT NOT NULL DEFAULT 'text-embedding',
    embedding_status TEXT NOT NULL DEFAULT 'pending',
    source_status TEXT NOT NULL DEFAULT 'pending',
    source_type TEXT NOT NULL DEFAULT 'internal-approved',
    language VARCHAR(8) NOT NULL DEFAULT 'en',
    review_status TEXT NOT NULL DEFAULT 'scholar_review_required',
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ,
    rejected_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_api_sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES sakina_ai.islamic_source_providers(id) ON DELETE SET NULL,
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    job_type TEXT NOT NULL,
    job_status TEXT NOT NULL DEFAULT 'queued',
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    total_items INTEGER NOT NULL DEFAULT 0,
    processed_items INTEGER NOT NULL DEFAULT 0,
    failed_items INTEGER NOT NULL DEFAULT 0,
    requested_by TEXT,
    request_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    result_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_api_sync_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES sakina_ai.islamic_api_sync_jobs(id) ON DELETE CASCADE,
    item_key TEXT NOT NULL,
    item_type TEXT NOT NULL,
    item_status TEXT NOT NULL DEFAULT 'queued',
    source_external_id TEXT,
    error_message TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (job_id, item_key)
);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_source_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    document_id UUID REFERENCES sakina_ai.islamic_documents(id) ON DELETE SET NULL,
    chunk_id UUID REFERENCES sakina_ai.islamic_chunks(id) ON DELETE SET NULL,
    licence_id UUID REFERENCES sakina_ai.islamic_source_licences(id) ON DELETE SET NULL,
    review_type TEXT NOT NULL DEFAULT 'source_governance',
    review_status TEXT NOT NULL DEFAULT 'pending',
    reviewer_id TEXT,
    reviewer_notes TEXT,
    decision_reason TEXT,
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    disabled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.rag_retrieval_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES sakina_ai.conversations(id) ON DELETE SET NULL,
    query_text TEXT NOT NULL,
    selected_module TEXT NOT NULL,
    language VARCHAR(8) NOT NULL DEFAULT 'en',
    retrieval_status TEXT NOT NULL DEFAULT 'blocked',
    source_type TEXT,
    source_status TEXT,
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    document_id UUID REFERENCES sakina_ai.islamic_documents(id) ON DELETE SET NULL,
    chunk_id UUID REFERENCES sakina_ai.islamic_chunks(id) ON DELETE SET NULL,
    embedding_id UUID REFERENCES sakina_ai.islamic_embeddings(id) ON DELETE SET NULL,
    citation TEXT,
    confidence NUMERIC(5,4),
    decision_reason TEXT,
    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.citation_verification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL,
    retrieval_audit_id UUID REFERENCES sakina_ai.rag_retrieval_audit(id) ON DELETE SET NULL,
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    document_id UUID REFERENCES sakina_ai.islamic_documents(id) ON DELETE SET NULL,
    chunk_id UUID REFERENCES sakina_ai.islamic_chunks(id) ON DELETE SET NULL,
    citation_text TEXT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'failed',
    verification_reason TEXT,
    verified_by TEXT NOT NULL DEFAULT 'policy',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS sakina_ai.entitlement_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    subscription_tier TEXT NOT NULL DEFAULT 'free',
    entitlement_allowed BOOLEAN NOT NULL DEFAULT false,
    policy_version TEXT NOT NULL DEFAULT 'v1',
    reason TEXT,
    decision_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.mastermind_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES public.auth_sessions(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES sakina_ai.conversations(id) ON DELETE SET NULL,
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    language VARCHAR(8) NOT NULL DEFAULT 'en',
    intent TEXT NOT NULL DEFAULT 'unknown',
    selected_module TEXT NOT NULL DEFAULT 'unsupported',
    safety_level TEXT NOT NULL DEFAULT 'unknown',
    islamic_sensitivity TEXT NOT NULL DEFAULT 'unknown',
    rag_allowed BOOLEAN NOT NULL DEFAULT false,
    retrieval_required BOOLEAN NOT NULL DEFAULT true,
    citations_required BOOLEAN NOT NULL DEFAULT true,
    citation_sufficiency BOOLEAN NOT NULL DEFAULT false,
    answer_allowed BOOLEAN NOT NULL DEFAULT false,
    scholar_review_required BOOLEAN NOT NULL DEFAULT true,
    final_response_policy TEXT NOT NULL DEFAULT 'defer',
    user_subscription_tier TEXT NOT NULL DEFAULT 'free',
    entitlement_allowed BOOLEAN NOT NULL DEFAULT false,
    reason TEXT NOT NULL DEFAULT 'insufficient_verified_evidence',
    user_message TEXT NOT NULL DEFAULT 'This question needs verified Islamic sources or scholar review before an answer can be provided.',
    decision_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    safety_context JSONB,
    policy_version TEXT NOT NULL DEFAULT 'v1',
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE sakina_ai.mastermind_decisions
    ADD COLUMN IF NOT EXISTS message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS citations_required BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS citation_sufficiency BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS user_subscription_tier TEXT DEFAULT 'free',
    ADD COLUMN IF NOT EXISTS entitlement_allowed BOOLEAN DEFAULT false;

CREATE TABLE IF NOT EXISTS sakina_ai.scholar_review_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL,
    mastermind_decision_id UUID REFERENCES sakina_ai.mastermind_decisions(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES sakina_ai.conversations(id) ON DELETE SET NULL,
    priority TEXT NOT NULL DEFAULT 'normal',
    review_status TEXT NOT NULL DEFAULT 'pending',
    assigned_reviewer TEXT,
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    reviewer_notes TEXT,
    due_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.wasm_verification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL,
    module_name TEXT NOT NULL,
    decision_type TEXT NOT NULL,
    input_hash TEXT NOT NULL,
    output_decision JSONB NOT NULL DEFAULT '{}'::jsonb,
    policy_version TEXT NOT NULL DEFAULT 'v1',
    runtime_mode TEXT NOT NULL DEFAULT 'fallback',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.brain_cache_metadata (
    cache_key TEXT PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    language VARCHAR(16) NOT NULL DEFAULT 'en',
    intent TEXT NOT NULL,
    safety_level TEXT NOT NULL DEFAULT 'safe',
    source_version TEXT NOT NULL,
    hit_count INTEGER NOT NULL DEFAULT 0,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_sources_source_status'
          AND conrelid = 'sakina_ai.islamic_sources'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_sources
            ADD CONSTRAINT chk_islamic_sources_source_status
            CHECK (lower(source_status) IN ('pending', 'approved', 'rejected', 'disabled'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_sources_source_type'
          AND conrelid = 'sakina_ai.islamic_sources'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_sources
            ADD CONSTRAINT chk_islamic_sources_source_type
            CHECK (lower(source_type) IN ('quran', 'hadith', 'tafsir', 'fiqh', 'scholar-reviewed', 'internal-approved'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_sources_language'
          AND conrelid = 'sakina_ai.islamic_sources'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_sources
            ADD CONSTRAINT chk_islamic_sources_language
            CHECK (lower(language) IN ('ar', 'en'));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_documents_source_status'
          AND conrelid = 'sakina_ai.islamic_documents'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_documents
            ADD CONSTRAINT chk_islamic_documents_source_status
            CHECK (lower(source_status) IN ('pending', 'approved', 'rejected', 'disabled'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_documents_source_type'
          AND conrelid = 'sakina_ai.islamic_documents'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_documents
            ADD CONSTRAINT chk_islamic_documents_source_type
            CHECK (lower(source_type) IN ('quran', 'hadith', 'tafsir', 'fiqh', 'scholar-reviewed', 'internal-approved'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_documents_language'
          AND conrelid = 'sakina_ai.islamic_documents'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_documents
            ADD CONSTRAINT chk_islamic_documents_language
            CHECK (lower(language) IN ('ar', 'en'));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_chunks_source_status'
          AND conrelid = 'sakina_ai.islamic_chunks'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_chunks
            ADD CONSTRAINT chk_islamic_chunks_source_status
            CHECK (lower(source_status) IN ('pending', 'approved', 'rejected', 'disabled'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_chunks_source_type'
          AND conrelid = 'sakina_ai.islamic_chunks'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_chunks
            ADD CONSTRAINT chk_islamic_chunks_source_type
            CHECK (lower(source_type) IN ('quran', 'hadith', 'tafsir', 'fiqh', 'scholar-reviewed', 'internal-approved'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_chunks_language'
          AND conrelid = 'sakina_ai.islamic_chunks'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_chunks
            ADD CONSTRAINT chk_islamic_chunks_language
            CHECK (lower(language) IN ('ar', 'en'));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_embeddings_source_status'
          AND conrelid = 'sakina_ai.islamic_embeddings'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_embeddings
            ADD CONSTRAINT chk_islamic_embeddings_source_status
            CHECK (lower(source_status) IN ('pending', 'approved', 'rejected', 'disabled'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_embeddings_source_type'
          AND conrelid = 'sakina_ai.islamic_embeddings'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_embeddings
            ADD CONSTRAINT chk_islamic_embeddings_source_type
            CHECK (lower(source_type) IN ('quran', 'hadith', 'tafsir', 'fiqh', 'scholar-reviewed', 'internal-approved'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_islamic_embeddings_language'
          AND conrelid = 'sakina_ai.islamic_embeddings'::regclass
    ) THEN
        ALTER TABLE sakina_ai.islamic_embeddings
            ADD CONSTRAINT chk_islamic_embeddings_language
            CHECK (lower(language) IN ('ar', 'en'));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_wasm_verification_events_runtime_mode'
          AND conrelid = 'sakina_ai.wasm_verification_events'::regclass
    ) THEN
        ALTER TABLE sakina_ai.wasm_verification_events
            ADD CONSTRAINT chk_wasm_verification_events_runtime_mode
            CHECK (lower(runtime_mode) IN ('wasm', 'fallback'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_islamic_sources_status_type_lang
    ON sakina_ai.islamic_sources (source_status, source_type, language);
CREATE INDEX IF NOT EXISTS idx_islamic_documents_source_language
    ON sakina_ai.islamic_documents (source_id, language, source_status);
CREATE INDEX IF NOT EXISTS idx_islamic_chunks_document
    ON sakina_ai.islamic_chunks (document_id, chunk_index);
CREATE INDEX IF NOT EXISTS idx_islamic_embeddings_chunk
    ON sakina_ai.islamic_embeddings (chunk_id);
CREATE INDEX IF NOT EXISTS idx_rag_retrieval_audit_request
    ON sakina_ai.rag_retrieval_audit (request_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mastermind_decisions_request
    ON sakina_ai.mastermind_decisions (request_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scholar_review_queue_status
    ON sakina_ai.scholar_review_queue (review_status, priority, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wasm_verification_events_request
    ON sakina_ai.wasm_verification_events (request_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_brain_cache_metadata_user_updated
    ON sakina_ai.brain_cache_metadata (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_brain_cache_metadata_workspace_updated
    ON sakina_ai.brain_cache_metadata (workspace_id, updated_at DESC);

-- ---------------------------------------------------------------------------
-- Domain 10/11: payments + subscriptions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.payment_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    provider_status TEXT NOT NULL DEFAULT 'active',
    config_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES public.payment_providers(id) ON DELETE SET NULL,
    plan_key TEXT NOT NULL UNIQUE,
    plan_name TEXT NOT NULL,
    billing_interval TEXT NOT NULL DEFAULT 'monthly',
    currency_code VARCHAR(3) NOT NULL DEFAULT 'USD',
    amount_minor INTEGER NOT NULL DEFAULT 0,
    trial_days INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payment_customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.payment_providers(id) ON DELETE RESTRICT,
    provider_customer_ref TEXT NOT NULL UNIQUE,
    customer_status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, provider_id)
);

CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.payment_customers(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.payment_providers(id) ON DELETE RESTRICT,
    provider_method_ref TEXT NOT NULL UNIQUE,
    method_type TEXT NOT NULL DEFAULT 'unknown',
    method_status TEXT NOT NULL DEFAULT 'active',
    is_default BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    payment_customer_id UUID REFERENCES public.payment_customers(id) ON DELETE SET NULL,
    provider_subscription_ref TEXT UNIQUE,
    subscription_status TEXT NOT NULL DEFAULT 'incomplete',
    started_at TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    cancelled_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.payment_providers(id) ON DELETE SET NULL,
    subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    invoice_id UUID,
    provider_transaction_ref TEXT NOT NULL UNIQUE,
    transaction_type TEXT NOT NULL,
    transaction_status TEXT NOT NULL DEFAULT 'pending',
    currency_code VARCHAR(3) NOT NULL DEFAULT 'USD',
    amount_minor INTEGER NOT NULL DEFAULT 0,
    failure_code TEXT,
    failure_message TEXT,
    processed_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    provider_id UUID REFERENCES public.payment_providers(id) ON DELETE SET NULL,
    provider_invoice_ref TEXT UNIQUE,
    invoice_status TEXT NOT NULL DEFAULT 'draft',
    currency_code VARCHAR(3) NOT NULL DEFAULT 'USD',
    subtotal_minor INTEGER NOT NULL DEFAULT 0,
    tax_minor INTEGER NOT NULL DEFAULT 0,
    total_minor INTEGER NOT NULL DEFAULT 0,
    due_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.payment_transactions
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID NOT NULL REFERENCES public.payment_transactions(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.payment_providers(id) ON DELETE SET NULL,
    provider_refund_ref TEXT UNIQUE,
    refund_status TEXT NOT NULL DEFAULT 'pending',
    currency_code VARCHAR(3) NOT NULL DEFAULT 'USD',
    amount_minor INTEGER NOT NULL DEFAULT 0,
    reason TEXT,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'recorded',
    provider_id UUID REFERENCES public.payment_providers(id) ON DELETE SET NULL,
    provider_event_ref TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entitlement_key TEXT NOT NULL UNIQUE,
    entitlement_name TEXT NOT NULL,
    description TEXT,
    entitlement_scope TEXT NOT NULL DEFAULT 'module',
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    entitlement_id UUID NOT NULL REFERENCES public.entitlements(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    granted_by TEXT NOT NULL DEFAULT 'system',
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entitlement_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_customers_user
    ON public.payment_customers (user_id, provider_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_customer
    ON public.payment_methods (customer_id, is_default);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_status
    ON public.user_subscriptions (user_id, subscription_status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_status
    ON public.payment_transactions (user_id, transaction_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_user_status
    ON public.invoices (user_id, invoice_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_events_subscription_type
    ON public.subscription_events (user_subscription_id, event_type, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_entitlements_user
    ON public.user_entitlements (user_id, entitlement_id);

-- ---------------------------------------------------------------------------
-- Domain 12: admin panel
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    admin_email TEXT UNIQUE,
    account_status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_key TEXT NOT NULL UNIQUE,
    role_name TEXT NOT NULL,
    is_system BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_key TEXT NOT NULL UNIQUE,
    permission_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES public.admin_roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.admin_permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    action_key TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    old_value JSONB,
    new_value JSONB,
    request_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT,
    action_status TEXT NOT NULL DEFAULT 'completed',
    notes TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.content_moderation_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    moderation_status TEXT NOT NULL DEFAULT 'pending',
    reason TEXT,
    assigned_admin_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.source_approval_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    submitted_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    approval_status TEXT NOT NULL DEFAULT 'pending',
    assigned_admin_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.scholar_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    scholar_slug TEXT UNIQUE,
    display_name TEXT NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT false,
    credentials_summary TEXT,
    account_status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.scholar_review_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scholar_account_id UUID NOT NULL REFERENCES public.scholar_accounts(id) ON DELETE CASCADE,
    scholar_review_queue_id UUID NOT NULL REFERENCES sakina_ai.scholar_review_queue(id) ON DELETE CASCADE,
    assignment_status TEXT NOT NULL DEFAULT 'assigned',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    notes TEXT,
    UNIQUE (scholar_account_id, scholar_review_queue_id)
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_user
    ON public.admin_audit_logs (admin_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_content_moderation_queue_status
    ON public.content_moderation_queue (moderation_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_source_approval_queue_status
    ON public.source_approval_queue (approval_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scholar_review_assignments_queue
    ON public.scholar_review_assignments (scholar_review_queue_id, assignment_status);

-- ---------------------------------------------------------------------------
-- Domain 13: user panel/dashboard
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_dashboard_widgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    widget_key TEXT NOT NULL,
    position_index INTEGER NOT NULL DEFAULT 0,
    is_visible BOOLEAN NOT NULL DEFAULT true,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, widget_key)
);

CREATE TABLE IF NOT EXISTS public.user_saved_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    title TEXT,
    answer_excerpt TEXT,
    source_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    bookmark_type TEXT NOT NULL,
    reference_id TEXT NOT NULL,
    title TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, bookmark_type, reference_id)
);

CREATE TABLE IF NOT EXISTS public.user_learning_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    topic_key TEXT NOT NULL,
    progress_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    last_interaction_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, topic_key)
);

CREATE TABLE IF NOT EXISTS public.user_quran_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    completion_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    last_read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, surah_number, ayah_number)
);

CREATE TABLE IF NOT EXISTS public.user_dua_favourites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    dua_key TEXT NOT NULL,
    source_id UUID REFERENCES sakina_ai.islamic_sources(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, dua_key)
);

CREATE TABLE IF NOT EXISTS public.user_chat_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES sakina_ai.conversations(id) ON DELETE SET NULL,
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    feedback_type TEXT NOT NULL,
    feedback_score INTEGER,
    feedback_comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_reported_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    report_reason TEXT NOT NULL,
    report_details TEXT,
    report_status TEXT NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_saved_answers_user_saved_at
    ON public.user_saved_answers (user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_user
    ON public.user_learning_progress (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_chat_feedback_message
    ON public.user_chat_feedback (message_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Domain 14: SEO/landing content
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.seo_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_slug TEXT NOT NULL UNIQUE,
    page_title TEXT NOT NULL,
    canonical_url TEXT,
    page_status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.seo_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seo_page_id UUID NOT NULL REFERENCES public.seo_pages(id) ON DELETE CASCADE,
    meta_title TEXT,
    meta_description TEXT,
    robots_directive TEXT DEFAULT 'index,follow',
    og_title TEXT,
    og_description TEXT,
    og_image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (seo_page_id)
);

CREATE TABLE IF NOT EXISTS public.landing_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_key TEXT NOT NULL UNIQUE,
    heading TEXT NOT NULL,
    body_markdown TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.landing_feature_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    landing_section_id UUID NOT NULL REFERENCES public.landing_sections(id) ON DELETE CASCADE,
    card_key TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    icon_name TEXT,
    cta_label TEXT,
    cta_url TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (landing_section_id, card_key)
);

CREATE TABLE IF NOT EXISTS public.blog_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    excerpt TEXT,
    body_markdown TEXT,
    author_name TEXT,
    publish_status TEXT NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.faq_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    category TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.legal_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_key TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    body_markdown TEXT NOT NULL,
    version_label TEXT NOT NULL DEFAULT 'v1',
    effective_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_store_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    locale VARCHAR(16) NOT NULL DEFAULT 'en-US',
    asset_type TEXT NOT NULL,
    asset_url TEXT NOT NULL,
    version_label TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.waitlist_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    locale VARCHAR(16),
    referral_code TEXT,
    source_channel TEXT,
    consent_marketing BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_seo_pages_status
    ON public.seo_pages (page_status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_blog_posts_status
    ON public.blog_posts (publish_status, published_at DESC);

-- ---------------------------------------------------------------------------
-- Domains 15/16/17/18/20: notifications, support, settings, audit, analytics
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key TEXT NOT NULL UNIQUE,
    channel TEXT NOT NULL,
    subject_template TEXT,
    body_template TEXT NOT NULL,
    locale VARCHAR(16) NOT NULL DEFAULT 'en-US',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    template_id UUID REFERENCES public.notification_templates(id) ON DELETE SET NULL,
    channel TEXT NOT NULL,
    notification_status TEXT NOT NULL DEFAULT 'queued',
    title TEXT,
    body TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    scheduled_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notification_delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_notification_id UUID NOT NULL REFERENCES public.user_notifications(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL DEFAULT 1,
    provider_ref TEXT,
    delivery_status TEXT NOT NULL DEFAULT 'pending',
    failure_reason TEXT,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    app_version TEXT,
    last_seen_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reminder_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reminder_type TEXT NOT NULL,
    schedule_cron TEXT,
    timezone VARCHAR(64),
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, reminder_type)
);

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ticket_number BIGINT GENERATED BY DEFAULT AS IDENTITY UNIQUE,
    ticket_status TEXT NOT NULL DEFAULT 'open',
    priority TEXT NOT NULL DEFAULT 'normal',
    category TEXT,
    subject TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.support_ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    support_ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    sender_type TEXT NOT NULL,
    sender_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    message_body TEXT NOT NULL,
    attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.contact_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    email TEXT NOT NULL,
    subject TEXT,
    message_body TEXT NOT NULL,
    message_status TEXT NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.abuse_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    report_target_type TEXT NOT NULL,
    report_target_id TEXT,
    report_reason TEXT NOT NULL,
    report_status TEXT NOT NULL DEFAULT 'open',
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    report_reason TEXT NOT NULL,
    report_status TEXT NOT NULL DEFAULT 'open',
    moderator_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.feature_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_key TEXT NOT NULL UNIQUE,
    flag_description TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT false,
    rollout_percent INTEGER NOT NULL DEFAULT 0,
    rules JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.module_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_name TEXT NOT NULL UNIQUE,
    enabled BOOLEAN NOT NULL DEFAULT false,
    lifecycle_status TEXT NOT NULL DEFAULT 'coming_soon',
    requires_subscription BOOLEAN NOT NULL DEFAULT true,
    reason TEXT NOT NULL DEFAULT 'under_review',
    updated_by TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key TEXT NOT NULL UNIQUE,
    config_value JSONB NOT NULL DEFAULT '{}'::jsonb,
    config_scope TEXT NOT NULL DEFAULT 'global',
    updated_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.release_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_key TEXT NOT NULL UNIQUE,
    release_status TEXT NOT NULL DEFAULT 'planned',
    rollout_notes TEXT,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.maintenance_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    window_key TEXT NOT NULL UNIQUE,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    maintenance_status TEXT NOT NULL DEFAULT 'scheduled',
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    actor_type TEXT NOT NULL DEFAULT 'system',
    actor_id TEXT,
    request_id TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.security_logs (
    id BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'info',
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ip_address INET,
    request_id TEXT,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES public.auth_sessions(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chat_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    conversation_id UUID REFERENCES sakina_ai.conversations(id) ON DELETE SET NULL,
    message_id UUID REFERENCES sakina_ai.messages(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rag_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    retrieval_audit_id UUID REFERENCES sakina_ai.rag_retrieval_audit(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_status
    ON public.user_notifications (user_id, notification_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_delivery_attempts_notification
    ON public.notification_delivery_attempts (user_notification_id, attempted_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_status
    ON public.support_tickets (user_id, ticket_status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_feature_flags_enabled
    ON public.feature_flags (is_enabled, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
    ON public.audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_logs_created_at
    ON public.security_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_events_occurred_at
    ON public.app_events (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_events_conversation
    ON public.chat_events (conversation_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_rag_events_request
    ON public.rag_events (request_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_events_admin
    ON public.admin_events (admin_user_id, occurred_at DESC);
