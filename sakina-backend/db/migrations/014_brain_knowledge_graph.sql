CREATE TABLE IF NOT EXISTS sakina_ai.knowledge_graph_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    source_type TEXT NOT NULL,
    citation TEXT NOT NULL,
    reliability_level TEXT NOT NULL,
    language TEXT NOT NULL,
    domain TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.knowledge_graph_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_entity_id UUID NOT NULL REFERENCES sakina_ai.knowledge_graph_entities(id) ON DELETE CASCADE,
    to_entity_id UUID NOT NULL REFERENCES sakina_ai.knowledge_graph_entities(id) ON DELETE CASCADE,
    relation_type TEXT NOT NULL,
    confidence NUMERIC(5,4) NOT NULL DEFAULT 0.0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.brain_decision_traces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    user_id TEXT NULL,
    input_type TEXT NOT NULL,
    intent TEXT NOT NULL,
    language TEXT NOT NULL,
    risk_level TEXT NOT NULL,
    selected_agent TEXT NOT NULL,
    selected_model TEXT NOT NULL,
    selected_pipeline TEXT NOT NULL,
    source_strategy TEXT NOT NULL,
    evaluation_result TEXT NOT NULL,
    final_action TEXT NOT NULL,
    audit_event_id TEXT NOT NULL,
    execution_trace JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.brain_evaluation_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    evaluation_score NUMERIC(5,4) NOT NULL,
    review_result TEXT NOT NULL,
    reason TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.brain_memory_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NULL,
    action TEXT NOT NULL,
    sensitivity_level TEXT NOT NULL,
    allowed BOOLEAN NOT NULL DEFAULT FALSE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.brain_cache_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key TEXT NOT NULL UNIQUE,
    user_id UUID NULL,
    language TEXT NOT NULL,
    intent TEXT NOT NULL,
    safety_level TEXT NOT NULL,
    source_version TEXT NOT NULL,
    hit_count INTEGER NOT NULL DEFAULT 0,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_knowledge_graph_entities_type_name
    ON sakina_ai.knowledge_graph_entities (entity_type, entity_name);
CREATE INDEX IF NOT EXISTS idx_knowledge_graph_edges_from_to
    ON sakina_ai.knowledge_graph_edges (from_entity_id, to_entity_id);
CREATE INDEX IF NOT EXISTS idx_brain_decision_traces_request
    ON sakina_ai.brain_decision_traces (request_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_brain_evaluation_results_request
    ON sakina_ai.brain_evaluation_results (request_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_brain_memory_events_user
    ON sakina_ai.brain_memory_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_brain_cache_metadata_user
    ON sakina_ai.brain_cache_metadata (user_id, created_at DESC);

INSERT INTO sakina_ai.knowledge_graph_entities (
    entity_type, entity_name, source_type, citation, reliability_level, language, domain, metadata
)
SELECT 'ayah', 'Ayat al-Kursi', 'quran', 'Quran 2:255', 'verified', 'ar', 'quran',
       '{"surah":"Al-Baqarah","ayah_number":255,"topics":["tawhid","protection"]}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM sakina_ai.knowledge_graph_entities WHERE entity_name = 'Ayat al-Kursi'
);

INSERT INTO sakina_ai.knowledge_graph_entities (
    entity_type, entity_name, source_type, citation, reliability_level, language, domain, metadata
)
SELECT 'surah', 'Al-Baqarah', 'quran', 'Quran 2', 'verified', 'ar', 'quran',
       '{"topics":["guidance","law"]}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM sakina_ai.knowledge_graph_entities WHERE entity_name = 'Al-Baqarah'
);

INSERT INTO sakina_ai.knowledge_graph_entities (
    entity_type, entity_name, source_type, citation, reliability_level, language, domain, metadata
)
SELECT 'topic', 'patience', 'tafsir', 'Quran 2:153', 'verified', 'en', 'support',
       '{"aliases":["sabr","steadfastness"]}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM sakina_ai.knowledge_graph_entities WHERE entity_name = 'patience'
);

INSERT INTO sakina_ai.knowledge_graph_edges (
    from_entity_id, to_entity_id, relation_type, confidence, metadata
)
SELECT source.id, target.id, 'belongs_to', 0.99, '{"seed":"true"}'::jsonb
FROM sakina_ai.knowledge_graph_entities source
JOIN sakina_ai.knowledge_graph_entities target ON target.entity_name = 'Al-Baqarah'
WHERE source.entity_name = 'Ayat al-Kursi'
  AND NOT EXISTS (
      SELECT 1 FROM sakina_ai.knowledge_graph_edges edge
      WHERE edge.from_entity_id = source.id AND edge.to_entity_id = target.id
  );

INSERT INTO sakina_ai.knowledge_graph_edges (
    from_entity_id, to_entity_id, relation_type, confidence, metadata
)
SELECT source.id, target.id, 'related_to', 0.88, '{"seed":"true"}'::jsonb
FROM sakina_ai.knowledge_graph_entities source
JOIN sakina_ai.knowledge_graph_entities target ON target.entity_name = 'patience'
WHERE source.entity_name = 'Ayat al-Kursi'
  AND NOT EXISTS (
      SELECT 1 FROM sakina_ai.knowledge_graph_edges edge
      WHERE edge.from_entity_id = source.id AND edge.to_entity_id = target.id
  );
