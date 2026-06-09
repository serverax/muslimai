-- Sakina AI Phase 4 Schema Migration: Core Quran and Tafsir Tables
-- This migration fulfills the database schema requirements for the Sakina Free AI Quran module.

BEGIN;

-- ============================================================================
-- 1. QURAN CORE TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.quran_surahs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    surah_number INTEGER NOT NULL UNIQUE CHECK (surah_number BETWEEN 1 AND 114),
    name_arabic TEXT NOT NULL,
    name_english TEXT NOT NULL,
    name_transliterated TEXT NOT NULL,
    revelation_type TEXT NOT NULL CHECK (revelation_type IN ('Meccan', 'Medinan')),
    total_ayahs INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_ayahs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    surah_id UUID NOT NULL REFERENCES sakina_ai.quran_surahs(id) ON DELETE CASCADE,
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    juz_number INTEGER NOT NULL,
    hizb_number INTEGER,
    page_number INTEGER NOT NULL,
    text_uthmani TEXT NOT NULL,
    text_imlaei_simple TEXT NOT NULL,
    sajdah_type TEXT, -- e.g., 'recommended', 'obligatory', or NULL
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (surah_number, ayah_number)
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ayah_id UUID NOT NULL REFERENCES sakina_ai.quran_ayahs(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL, -- ISO 639-1
    translator_name TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_url TEXT,
    licence_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (ayah_id, language_code, translator_name)
);

-- ============================================================================
-- 2. TAFSIR TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_key TEXT NOT NULL UNIQUE,
    name_arabic TEXT,
    name_english TEXT NOT NULL,
    author TEXT NOT NULL,
    language_code TEXT NOT NULL,
    madhhab_aqidah_notes TEXT,
    licence_status TEXT NOT NULL,
    source_url TEXT,
    reliability_rating TEXT NOT NULL DEFAULT 'verified',
    api_endpoint TEXT,
    scraping_allowed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_sources(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    volume INTEGER,
    publication_year TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_sources(id) ON DELETE CASCADE,
    book_id UUID REFERENCES sakina_ai.quran_tafsir_books(id) ON DELETE SET NULL,
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    ayah_range_start INTEGER NOT NULL,
    ayah_range_end INTEGER NOT NULL,
    tafsir_text TEXT NOT NULL,
    tafsir_summary TEXT, -- Optional AI generated or editor provided summary
    language TEXT NOT NULL,
    translator TEXT,
    source_url TEXT,
    checksum TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tafsir_entries_surah_ayah ON sakina_ai.quran_tafsir_entries(surah_number, ayah_number);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_languages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_entries(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_sources(id),
    status TEXT NOT NULL DEFAULT 'pending', -- pending, running, completed, failed
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    records_processed INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_ingestion_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_ingestion_jobs(id) ON DELETE CASCADE,
    error_message TEXT NOT NULL,
    raw_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_citations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_entries(id) ON DELETE CASCADE,
    cited_text TEXT NOT NULL,
    citation_type TEXT NOT NULL, -- 'quran', 'hadith', 'scholar'
    reference_id TEXT, -- Foreign key equivalent to hadith/quran table if applicable
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_cross_references (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_entries(id) ON DELETE CASCADE,
    related_surah INTEGER NOT NULL,
    related_ayah INTEGER NOT NULL,
    relevance_score FLOAT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_topic_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_entries(id) ON DELETE CASCADE,
    topic TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_tafsir_quality_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES sakina_ai.quran_tafsir_entries(id) ON DELETE CASCADE,
    reviewer_id UUID REFERENCES public.admin_users(id),
    review_status TEXT NOT NULL DEFAULT 'pending', -- approved, rejected, needs_edit
    reviewer_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 3. USER QURAN FEATURES (Isolation Enforced)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.quran_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    tag TEXT, -- 'memorise', 'reflection', 'dua', 'review'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, surah_number, ayah_number)
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    last_surah INTEGER NOT NULL,
    last_ayah INTEGER NOT NULL,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id) -- One active reading session per user
);

CREATE TABLE IF NOT EXISTS sakina_ai.quran_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    note_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
