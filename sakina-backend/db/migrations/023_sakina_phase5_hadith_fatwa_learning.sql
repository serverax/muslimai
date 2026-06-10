-- Sakina AI Phase 5 Schema Migration: Hadith, Fatwa, and Learning Tables
-- This migration fulfills the database schema requirements for the remaining core Sakina modules.

BEGIN;

-- ============================================================================
-- 1. HADITH TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_key TEXT NOT NULL UNIQUE,
    name_arabic TEXT NOT NULL,
    name_english TEXT NOT NULL,
    author TEXT NOT NULL,
    total_hadith INTEGER,
    licence_status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL REFERENCES sakina_ai.hadith_collections(id) ON DELETE CASCADE,
    book_number INTEGER NOT NULL,
    name_arabic TEXT NOT NULL,
    name_english TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (collection_id, book_number)
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_narrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES sakina_ai.hadith_books(id) ON DELETE CASCADE,
    hadith_number TEXT NOT NULL, -- TEXT to accommodate formats like "1a", "2b"
    text_arabic TEXT NOT NULL,
    text_english TEXT,
    chapter_title_arabic TEXT,
    chapter_title_english TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (book_id, hadith_number)
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_chains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hadith_id UUID NOT NULL REFERENCES sakina_ai.hadith_narrations(id) ON DELETE CASCADE,
    narrator_name TEXT NOT NULL,
    position_in_chain INTEGER NOT NULL,
    reliability_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hadith_id UUID NOT NULL REFERENCES sakina_ai.hadith_narrations(id) ON DELETE CASCADE,
    scholar_name TEXT NOT NULL,
    grade_arabic TEXT NOT NULL,
    grade_english TEXT NOT NULL, -- e.g., 'Sahih', 'Hasan', 'Daif'
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_name TEXT NOT NULL UNIQUE,
    parent_topic_id UUID REFERENCES sakina_ai.hadith_topics(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_topic_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hadith_id UUID NOT NULL REFERENCES sakina_ai.hadith_narrations(id) ON DELETE CASCADE,
    topic_id UUID NOT NULL REFERENCES sakina_ai.hadith_topics(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (hadith_id, topic_id)
);

CREATE TABLE IF NOT EXISTS sakina_ai.hadith_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hadith_id UUID NOT NULL REFERENCES sakina_ai.hadith_narrations(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL,
    translator_name TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (hadith_id, language_code, translator_name)
);

-- ============================================================================
-- 2. FATWA TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_key TEXT NOT NULL UNIQUE,
    issuing_authority TEXT NOT NULL,
    scholar_name TEXT,
    base_url TEXT NOT NULL,
    language_code TEXT NOT NULL,
    madhhab_tag TEXT,
    country_tag TEXT,
    scraping_allowed BOOLEAN NOT NULL DEFAULT false,
    licence_status TEXT NOT NULL,
    reliability_rating TEXT NOT NULL DEFAULT 'needs_review',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sakina_ai.fatwa_sources(id) ON DELETE CASCADE,
    original_url TEXT NOT NULL UNIQUE,
    fatwa_date DATE,
    language TEXT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'needs_review', -- verified, needs_review, rejected, archived
    copyright_note TEXT,
    scraping_method TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fatwa_id UUID NOT NULL REFERENCES sakina_ai.fatwa_documents(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fatwa_id UUID NOT NULL REFERENCES sakina_ai.fatwa_documents(id) ON DELETE CASCADE,
    answer_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fatwa_id UUID NOT NULL REFERENCES sakina_ai.fatwa_documents(id) ON DELETE CASCADE,
    topic_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_citations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fatwa_id UUID NOT NULL REFERENCES sakina_ai.fatwa_documents(id) ON DELETE CASCADE,
    cited_evidence TEXT NOT NULL,
    citation_type TEXT, -- quran, hadith, scholar
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_scrape_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sakina_ai.fatwa_sources(id),
    status TEXT NOT NULL DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    records_processed INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.fatwa_scrape_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES sakina_ai.fatwa_scrape_jobs(id) ON DELETE CASCADE,
    url_attempted TEXT,
    error_message TEXT NOT NULL,
    raw_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 3. LEARNING & PERSONALISATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sakina_ai.learning_paths (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path_key TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    difficulty_level TEXT NOT NULL, -- beginner, intermediate, advanced
    target_audience TEXT, -- e.g., 'new_muslim', 'kids', 'general'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.learning_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path_id UUID NOT NULL REFERENCES sakina_ai.learning_paths(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (path_id, order_index)
);

CREATE TABLE IF NOT EXISTS sakina_ai.learning_lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID NOT NULL REFERENCES sakina_ai.learning_modules(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    title TEXT NOT NULL,
    content_type TEXT NOT NULL, -- text, video, interactive
    content_body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (module_id, order_index)
);

CREATE TABLE IF NOT EXISTS sakina_ai.quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id UUID REFERENCES sakina_ai.learning_lessons(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    passing_score INTEGER NOT NULL DEFAULT 80,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quiz_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID NOT NULL REFERENCES sakina_ai.quizzes(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_type TEXT NOT NULL, -- multiple_choice, true_false
    order_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.quiz_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES sakina_ai.quiz_questions(id) ON DELETE CASCADE,
    answer_text TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL DEFAULT false,
    explanation TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User Isolation Enforced Tables

CREATE TABLE IF NOT EXISTS sakina_ai.user_learning_path_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    path_id UUID NOT NULL REFERENCES sakina_ai.learning_paths(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'in_progress', -- in_progress, completed
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    UNIQUE (user_id, path_id)
);

CREATE TABLE IF NOT EXISTS sakina_ai.user_lesson_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES sakina_ai.learning_lessons(id) ON DELETE CASCADE,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS sakina_ai.user_quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    quiz_id UUID NOT NULL REFERENCES sakina_ai.quizzes(id) ON DELETE CASCADE,
    score INTEGER NOT NULL,
    passed BOOLEAN NOT NULL,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.user_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL REFERENCES sakina_ai.workspaces(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL, -- salah, quran, dhikr
    target_value INTEGER NOT NULL,
    current_value INTEGER NOT NULL DEFAULT 0,
    period TEXT NOT NULL, -- daily, weekly, monthly
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 4. RLS POLICIES
-- ============================================================================

-- Hadith (Public Read)
ALTER TABLE sakina_ai.hadith_collections ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_collections ON sakina_ai.hadith_collections FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_books ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_books ON sakina_ai.hadith_books FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_narrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_narrations ON sakina_ai.hadith_narrations FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_chains ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_chains ON sakina_ai.hadith_chains FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_grades ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_grades ON sakina_ai.hadith_grades FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_topics ON sakina_ai.hadith_topics FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_topic_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_topic_links ON sakina_ai.hadith_topic_links FOR SELECT USING (true);
ALTER TABLE sakina_ai.hadith_translations ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_hadith_translations ON sakina_ai.hadith_translations FOR SELECT USING (true);

-- Fatwa (Public Read)
ALTER TABLE sakina_ai.fatwa_sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_fatwa_sources ON sakina_ai.fatwa_sources FOR SELECT USING (true);
ALTER TABLE sakina_ai.fatwa_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_fatwa_documents ON sakina_ai.fatwa_documents FOR SELECT USING (true);
ALTER TABLE sakina_ai.fatwa_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_fatwa_questions ON sakina_ai.fatwa_questions FOR SELECT USING (true);
ALTER TABLE sakina_ai.fatwa_answers ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_fatwa_answers ON sakina_ai.fatwa_answers FOR SELECT USING (true);
ALTER TABLE sakina_ai.fatwa_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_fatwa_topics ON sakina_ai.fatwa_topics FOR SELECT USING (true);
ALTER TABLE sakina_ai.fatwa_citations ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_fatwa_citations ON sakina_ai.fatwa_citations FOR SELECT USING (true);

-- Admin/Ingestion (Internal Restricted)
ALTER TABLE sakina_ai.fatwa_scrape_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_fatwa_jobs ON sakina_ai.fatwa_scrape_jobs FOR ALL USING (sakina_ai.rls_service_role());
ALTER TABLE sakina_ai.fatwa_scrape_errors ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_fatwa_errors ON sakina_ai.fatwa_scrape_errors FOR ALL USING (sakina_ai.rls_service_role());

-- Learning (Public Read for paths/lessons, Private for progress)
ALTER TABLE sakina_ai.learning_paths ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_learning_paths ON sakina_ai.learning_paths FOR SELECT USING (true);
ALTER TABLE sakina_ai.learning_modules ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_learning_modules ON sakina_ai.learning_modules FOR SELECT USING (true);
ALTER TABLE sakina_ai.learning_lessons ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_learning_lessons ON sakina_ai.learning_lessons FOR SELECT USING (true);
ALTER TABLE sakina_ai.quizzes ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_quizzes ON sakina_ai.quizzes FOR SELECT USING (true);
ALTER TABLE sakina_ai.quiz_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_quiz_questions ON sakina_ai.quiz_questions FOR SELECT USING (true);
ALTER TABLE sakina_ai.quiz_answers ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_quiz_answers ON sakina_ai.quiz_answers FOR SELECT USING (true);

ALTER TABLE sakina_ai.user_learning_path_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_path_progress ON sakina_ai.user_learning_path_progress FOR ALL USING (user_id = sakina_ai.current_user_id());
ALTER TABLE sakina_ai.user_lesson_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_lesson_progress ON sakina_ai.user_lesson_completions FOR ALL USING (user_id = sakina_ai.current_user_id());
ALTER TABLE sakina_ai.user_quiz_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_quiz_attempts ON sakina_ai.user_quiz_attempts FOR ALL USING (user_id = sakina_ai.current_user_id());
ALTER TABLE sakina_ai.user_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_goals ON sakina_ai.user_goals FOR ALL USING (user_id = sakina_ai.current_user_id());

COMMIT;
