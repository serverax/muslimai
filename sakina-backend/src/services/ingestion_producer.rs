//! Ingestion producer (Phase 2, Step 7): read a verified text, chunk it, and
//! persist the source document + chunks + outbox events to Postgres.
//!
//! Adapted from the roadmap to compile/run in this environment:
//!   - Qdrant upsert + vLLM embedding are DEFERRED (no qdrant-client → avoids the
//!     OOM dependency tree). The outbox carries a `chunk_indexed` event so the
//!     relay / a real indexer can sync vectors later.
//!   - Chunking uses a simple paragraph splitter here; the Arabic semantic chunker
//!     (Python, chunking.py) is bridged via a subprocess/Job in the data pipeline.
//!   - SQL matches db/init.sql: source_documents(title, author, integrity_hash,
//!     approved_by, approved_at); chunks(content_chunk, madhhab, scholar, token_count).

use sqlx::PgPool;
use std::path::Path;
use uuid::Uuid;

pub struct IngestionProducer {
    pool: PgPool,
}

impl IngestionProducer {
    pub fn new(pool: PgPool) -> Self {
        IngestionProducer { pool }
    }

    /// Ingest one document. Returns the number of chunks written.
    pub async fn ingest_document(
        &self,
        path: &Path,
        madhhab: &str,
        scholar: &str,
    ) -> Result<usize, Box<dyn std::error::Error>> {
        let content = std::fs::read_to_string(path)?;
        let title = path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("untitled")
            .to_string();
        let integrity_hash = content_hash(&content);

        let source_id: Uuid = sqlx::query_scalar(
            "INSERT INTO verified_knowledge.source_documents \
             (title, author, integrity_hash, approved_by, approved_at) \
             VALUES ($1, $2, $3, $4, NOW()) RETURNING id",
        )
        .bind(&title)
        .bind(scholar)
        .bind(&integrity_hash)
        .bind(scholar)
        .fetch_one(&self.pool)
        .await?;

        let chunks = simple_chunk(&content, 512);
        for chunk in &chunks {
            let chunk_id: Uuid = sqlx::query_scalar(
                "INSERT INTO verified_knowledge.chunks \
                 (source_document_id, content_chunk, madhhab, scholar, token_count) \
                 VALUES ($1, $2, $3, $4, $5) RETURNING id",
            )
            .bind(source_id)
            .bind(chunk)
            .bind(madhhab)
            .bind(scholar)
            .bind(chunk.split_whitespace().count() as i32)
            .fetch_one(&self.pool)
            .await?;

            sqlx::query(
                "INSERT INTO outbox.events (event_type, payload, status) \
                 VALUES ($1, $2, 'Pending')",
            )
            .bind("chunk_indexed")
            .bind(serde_json::json!({ "chunk_id": chunk_id, "source_id": source_id }))
            .execute(&self.pool)
            .await?;
        }

        Ok(chunks.len())
    }
}

fn content_hash(s: &str) -> String {
    use sha2::{Digest, Sha256};

    let digest = Sha256::digest(s.as_bytes());
    format!("{:x}", digest)
}

/// Splits blank-line-separated paragraphs into bounded chunks.
fn simple_chunk(text: &str, max_words: usize) -> Vec<String> {
    let mut out = Vec::new();
    for para in text.split("\n\n") {
        let words: Vec<&str> = para.split_whitespace().collect();
        if words.is_empty() {
            continue;
        }
        for window in words.chunks(max_words) {
            out.push(window.join(" "));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::simple_chunk;

    #[test]
    fn splits_paragraphs_and_skips_empty() {
        let chunks = simple_chunk("alpha beta\n\n\n\ngamma", 10);
        assert_eq!(chunks, vec!["alpha beta".to_string(), "gamma".to_string()]);
    }

    #[test]
    fn caps_window_to_max_words() {
        let chunks = simple_chunk("a b c d e", 2);
        assert_eq!(chunks, vec!["a b", "c d", "e"]);
    }
}
