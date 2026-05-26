-- Create schemas
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS verified_knowledge;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS outbox;

-- Verified Knowledge Schema
CREATE TABLE verified_knowledge.source_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR NOT NULL,
    author VARCHAR NOT NULL,
    integrity_hash VARCHAR UNIQUE NOT NULL,
    approved_by VARCHAR,
    approved_at TIMESTAMP
);

CREATE TABLE verified_knowledge.chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_document_id UUID REFERENCES verified_knowledge.source_documents(id),
    content_chunk TEXT NOT NULL,
    madhhab VARCHAR(50),
    scholar VARCHAR,
    book_title VARCHAR,
    chapter VARCHAR,
    authenticity_grade VARCHAR(20),
    token_count INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Audit Schema
CREATE TABLE audit.logs (
    id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    event_type VARCHAR NOT NULL,
    payload JSONB,
    user_id UUID
) WITH (fillfactor=100);

CREATE INDEX idx_audit_logs_timestamp ON audit.logs(timestamp);
CREATE INDEX idx_audit_logs_event_type ON audit.logs(event_type);

-- Outbox Pattern
CREATE TABLE outbox.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR DEFAULT 'Pending',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE outbox.dead_letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES outbox.events(id),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Public Schema
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pub_key VARCHAR UNIQUE NOT NULL,
    madhhab_preference VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE public.user_backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id),
    encrypted_blob BYTEA NOT NULL,
    backup_hash VARCHAR NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create role and grant permissions.
-- Password/secret material must be provisioned outside source control.
DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'sakina_user') THEN
        CREATE ROLE sakina_user LOGIN;
    END IF;
END
$$;
GRANT ALL PRIVILEGES ON SCHEMA verified_knowledge, audit, outbox, public TO sakina_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA verified_knowledge, audit, outbox, public TO sakina_user;
