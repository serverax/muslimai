//! Ingestion producer (Phase 2, Step 7): read a verified text, chunk it, and
//! persist the source document + chunks + outbox events to Postgres.
//!
//! The producer writes Postgres source/chunk metadata and, when embedding +
//! Qdrant services are supplied, indexes every chunk into the vector store.

use super::{EmbeddingsService, QdrantVectorDB};
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Postgres, Transaction};
use std::path::Path;
use uuid::Uuid;

pub struct IngestionProducer {
    pool: PgPool,
    embeddings: Option<EmbeddingsService>,
    qdrant: Option<QdrantVectorDB>,
}

impl IngestionProducer {
    pub fn new(pool: PgPool) -> Self {
        IngestionProducer {
            pool,
            embeddings: None,
            qdrant: None,
        }
    }

    pub fn with_indexer(
        pool: PgPool,
        embeddings: EmbeddingsService,
        qdrant: QdrantVectorDB,
    ) -> Self {
        IngestionProducer {
            pool,
            embeddings: Some(embeddings),
            qdrant: Some(qdrant),
        }
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
        let normalized = normalize_text(&content);
        let integrity_hash = content_hash(&normalized);
        let chunks = arabic_semantic_chunk(&normalized, 512, 64);

        let mut tx = self.pool.begin().await?;
        let source_id = upsert_source(&mut tx, &title, scholar, &integrity_hash).await?;

        sqlx::query("DELETE FROM verified_knowledge.chunks WHERE source_document_id = $1")
            .bind(source_id)
            .execute(&mut *tx)
            .await?;

        let mut written = Vec::with_capacity(chunks.len());
        for chunk in &chunks {
            let chunk_id =
                insert_chunk(&mut tx, source_id, chunk, madhhab, scholar, &title).await?;

            sqlx::query(
                "INSERT INTO outbox.events (event_type, payload, status) \
                 VALUES ($1, $2, 'Pending')",
            )
            .bind("chunk_ingested")
            .bind(serde_json::json!({ "chunk_id": chunk_id, "source_id": source_id }))
            .execute(&mut *tx)
            .await?;
            written.push((chunk_id, chunk.clone()));
        }

        tx.commit().await?;

        if let (Some(embeddings), Some(qdrant)) = (&self.embeddings, &self.qdrant) {
            for (chunk_id, chunk) in &written {
                let vector = embeddings.embed(chunk).await?;
                qdrant
                    .upsert_chunk(
                        *chunk_id,
                        source_id,
                        vector,
                        serde_json::json!({
                            "title": title,
                            "madhhab": madhhab,
                            "scholar": scholar,
                            "text": chunk
                        }),
                    )
                    .await?;
            }
        }

        Ok(written.len())
    }
}

async fn upsert_source(
    tx: &mut Transaction<'_, Postgres>,
    title: &str,
    scholar: &str,
    integrity_hash: &str,
) -> Result<Uuid, sqlx::Error> {
    sqlx::query_scalar(
        "INSERT INTO verified_knowledge.source_documents \
             (title, author, integrity_hash, approved_by, approved_at) \
         VALUES ($1, $2, $3, $4, NOW()) \
         ON CONFLICT (integrity_hash) DO UPDATE \
         SET title = EXCLUDED.title, author = EXCLUDED.author, approved_at = NOW() \
         RETURNING id",
    )
    .bind(title)
    .bind(scholar)
    .bind(integrity_hash)
    .bind(scholar)
    .fetch_one(&mut **tx)
    .await
}

async fn insert_chunk(
    tx: &mut Transaction<'_, Postgres>,
    source_id: Uuid,
    chunk: &str,
    madhhab: &str,
    scholar: &str,
    book_title: &str,
) -> Result<Uuid, sqlx::Error> {
    let (chapter, authenticity_grade) = infer_chunk_metadata(chunk);
    sqlx::query_scalar(
        "INSERT INTO verified_knowledge.chunks \
         (source_document_id, content_chunk, madhhab, scholar, book_title, chapter, \
          authenticity_grade, token_count) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id",
    )
    .bind(source_id)
    .bind(chunk)
    .bind(madhhab)
    .bind(scholar)
    .bind(book_title)
    .bind(chapter)
    .bind(authenticity_grade)
    .bind(chunk.split_whitespace().count() as i32)
    .fetch_one(&mut **tx)
    .await
}

fn content_hash(s: &str) -> String {
    let digest = Sha256::digest(s.as_bytes());
    digest.iter().map(|b| format!("{b:02x}")).collect()
}

fn normalize_text(text: &str) -> String {
    text.replace('\u{0640}', "")
        .replace("\r\n", "\n")
        .lines()
        .map(str::trim)
        .collect::<Vec<_>>()
        .join("\n")
}

fn arabic_semantic_chunk(text: &str, max_words: usize, overlap_words: usize) -> Vec<String> {
    let mut out = Vec::new();
    for section in split_by_markers(text) {
        let words: Vec<&str> = section.split_whitespace().collect();
        if words.is_empty() {
            continue;
        }

        if words.len() <= max_words {
            out.push(words.join(" "));
            continue;
        }

        let step = max_words.saturating_sub(overlap_words).max(1);
        let mut start = 0usize;
        while start < words.len() {
            let end = (start + max_words).min(words.len());
            out.push(words[start..end].join(" "));
            if end == words.len() {
                break;
            }
            start += step;
        }
    }
    out
}

fn split_by_markers(text: &str) -> Vec<String> {
    let markers = ["باب", "فصل", "مسألة", "كتاب", "Chapter", "Book", "Section"];
    let mut sections = Vec::new();
    let mut current = String::new();

    for line in text.lines() {
        let trimmed = line.trim();
        let starts_new = markers.iter().any(|marker| trimmed.starts_with(marker));
        if starts_new && !current.trim().is_empty() {
            sections.push(current.trim().to_string());
            current.clear();
        }
        if !trimmed.is_empty() {
            current.push_str(trimmed);
            current.push('\n');
        }
    }

    if !current.trim().is_empty() {
        sections.push(current.trim().to_string());
    }

    if sections.is_empty() && !text.trim().is_empty() {
        sections.push(text.trim().to_string());
    }

    sections
}

fn infer_chunk_metadata(chunk: &str) -> (Option<String>, Option<String>) {
    let chapter = chunk
        .lines()
        .find(|line| {
            let trimmed = line.trim();
            ["باب", "فصل", "مسألة", "كتاب", "Chapter", "Book", "Section"]
                .iter()
                .any(|marker| trimmed.starts_with(marker))
        })
        .map(|line| line.trim().chars().take(160).collect());

    let authenticity_grade = ["Sahih", "Hasan", "Da'if", "صحيح", "حسن", "ضعيف"]
        .iter()
        .find(|grade| chunk.contains(**grade))
        .map(|grade| grade.to_string());

    (chapter, authenticity_grade)
}

#[cfg(test)]
mod tests {
    use super::{arabic_semantic_chunk, content_hash, infer_chunk_metadata, normalize_text};

    #[test]
    fn hashes_with_sha256_hex() {
        let h = content_hash("abc");
        assert_eq!(
            h,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn normalizes_tatweel_and_crlf() {
        assert_eq!(normalize_text("باــب\r\n  فصل  "), "باب\nفصل");
    }

    #[test]
    fn splits_on_arabic_markers() {
        let chunks = arabic_semantic_chunk("باب الطهارة\none\nفصل المياه\ntwo", 50, 5);
        assert_eq!(chunks.len(), 2);
        assert!(chunks[0].starts_with("باب الطهارة"));
        assert!(chunks[1].starts_with("فصل المياه"));
    }

    #[test]
    fn overlapping_windows_keep_context() {
        let chunks = arabic_semantic_chunk("a b c d e", 3, 1);
        assert_eq!(chunks, vec!["a b c".to_string(), "c d e".to_string()]);
    }

    #[test]
    fn infers_chapter_and_grade() {
        let (chapter, grade) = infer_chunk_metadata("باب الإيمان\nNarration grade: Sahih");
        assert_eq!(chapter.as_deref(), Some("باب الإيمان"));
        assert_eq!(grade.as_deref(), Some("Sahih"));
    }
}
