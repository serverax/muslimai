-- PHASE 3: Islamic corpus (Quran, Tafsir, Hadith, Sources, Fatwa refs, Authenticity
-- rules) + citation-guard trace tables. Public read corpus. All rows carry a source.
-- Self-contained corpus_* tables purpose-built for the read/search/citation flow.
BEGIN;

-- ---------------- Quran ----------------
CREATE TABLE IF NOT EXISTS sakina_ai.corpus_quran (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    surah_number INTEGER NOT NULL,
    surah_name_en TEXT NOT NULL,
    surah_name_ar TEXT NOT NULL,
    ayah_number INTEGER NOT NULL,
    text_arabic TEXT NOT NULL,
    translation_en TEXT NOT NULL,
    translation_source TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (surah_number, ayah_number)
);
CREATE INDEX IF NOT EXISTS idx_corpus_quran_surah ON sakina_ai.corpus_quran (surah_number);

CREATE TABLE IF NOT EXISTS sakina_ai.corpus_quran_tafsir (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    tafsir_source TEXT NOT NULL,
    tafsir_text TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_corpus_tafsir_ref ON sakina_ai.corpus_quran_tafsir (surah_number, ayah_number);

-- ---------------- Hadith ----------------
CREATE TABLE IF NOT EXISTS sakina_ai.corpus_hadith (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection TEXT NOT NULL,
    book TEXT,
    hadith_number TEXT NOT NULL,
    narrator TEXT,
    text_arabic TEXT,
    text_english TEXT NOT NULL,
    grading TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    tags TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_corpus_hadith_collection ON sakina_ai.corpus_hadith (collection);

-- ---------------- Sources / Fatwa refs / Authenticity rules ----------------
CREATE TABLE IF NOT EXISTS sakina_ai.corpus_islamic_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name TEXT NOT NULL UNIQUE,
    source_url TEXT,
    language TEXT NOT NULL DEFAULT 'ar/en',
    madhhab TEXT,
    category TEXT NOT NULL,
    trust_level TEXT NOT NULL,        -- primary | secondary | reference
    allowed_usage TEXT NOT NULL,
    restricted_usage TEXT,
    citation_format TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.corpus_fatwa_refs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    source_name TEXT NOT NULL,
    reference_url TEXT,
    topic TEXT NOT NULL,
    summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.source_authenticity_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_key TEXT NOT NULL UNIQUE,
    rule_text TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'block',   -- block | escalate | warn
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------- Citation guard / answer source trace ----------------
CREATE TABLE IF NOT EXISTS sakina_ai.answer_source_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    source_type TEXT NOT NULL,       -- quran | hadith | tafsir | fatwa | local_db
    source_ref TEXT NOT NULL,
    citation_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_answer_source_links_trace ON sakina_ai.answer_source_links (trace_id);

CREATE TABLE IF NOT EXISTS sakina_ai.islamic_citation_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    result TEXT NOT NULL,            -- valid | blocked | escalated | not_required
    reason TEXT,
    citation_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_citation_checks_trace ON sakina_ai.islamic_citation_checks (trace_id);

CREATE TABLE IF NOT EXISTS sakina_ai.rag_retrieval_traces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    query TEXT NOT NULL,
    corpus TEXT NOT NULL,            -- quran | hadith | tafsir
    hit_count INTEGER NOT NULL DEFAULT 0,
    top_ref TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rag_traces_trace ON sakina_ai.rag_retrieval_traces (trace_id);

-- ---------------- RLS ----------------
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'corpus_quran','corpus_quran_tafsir','corpus_hadith','corpus_islamic_sources',
    'corpus_fatwa_refs','source_authenticity_rules','answer_source_links',
    'islamic_citation_checks','rag_retrieval_traces'
  ] LOOP
    EXECUTE format('ALTER TABLE sakina_ai.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I_service ON sakina_ai.%I', t, t);
    EXECUTE format('CREATE POLICY %I_service ON sakina_ai.%I FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role())', t, t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['corpus_quran','corpus_quran_tafsir','corpus_hadith','corpus_islamic_sources','corpus_fatwa_refs','source_authenticity_rules'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_public ON sakina_ai.%I', t, t);
    EXECUTE format('CREATE POLICY %I_public ON sakina_ai.%I FOR SELECT USING (true)', t, t);
  END LOOP;
END $$;

COMMIT;
