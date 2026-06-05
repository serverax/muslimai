BEGIN;
CREATE TABLE IF NOT EXISTS rag_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_uri TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rag_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES rag_documents(id) ON DELETE CASCADE,
  chunk_index INT NOT NULL,
  body TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE(document_id, chunk_index)
);

CREATE SCHEMA IF NOT EXISTS sakina_ai;

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
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_islamic_sources_status_type_lang
  ON sakina_ai.islamic_sources (source_status, source_type, language);

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
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_islamic_documents_source_language
  ON sakina_ai.islamic_documents (source_id, language, source_status);

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
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_islamic_chunks_document
  ON sakina_ai.islamic_chunks (document_id, chunk_index);
COMMIT;
