BEGIN;
CREATE TABLE IF NOT EXISTS rag_embeddings (
  chunk_id UUID PRIMARY KEY REFERENCES rag_chunks(id) ON DELETE CASCADE,
  embedding_model TEXT NOT NULL,
  embedding_dimension INT NOT NULL,
  embedding_ref TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMIT;
