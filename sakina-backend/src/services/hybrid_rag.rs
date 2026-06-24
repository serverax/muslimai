use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
use crate::models::SourceReference;
use crate::services::{
    CompressedEvidenceChunk, ContextCompressionService, EmbeddingsService, KnowledgeGraphService,
    QdrantVectorDB,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HybridRetrievedChunk {
    pub chunk_id: Uuid,
    pub document_id: Uuid,
    pub title: String,
    pub citation: String,
    pub source_type: String,
    pub language: String,
    pub review_status: String,
    pub chunk_text: String,
    pub keyword_score: f32,
    pub vector_score: f32,
    pub graph_score: f32,
    pub source_trust_score: f32,
    pub final_score: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HybridRagResult {
    pub query: String,
    pub language: String,
    pub retrieval_strategy: String,
    pub retrieved_chunks: Vec<HybridRetrievedChunk>,
    pub source_ranking: Vec<String>,
    pub citations: Vec<SourceReference>,
    pub graph_path: Vec<String>,
    pub compressed_tokens_before: usize,
    pub compressed_tokens_after: usize,
    pub compression_ratio: f32,
    pub weak_evidence_blocked: bool,
}

#[derive(Debug, Clone)]
pub struct HybridRagService {
    pool: PgPool,
    embeddings: EmbeddingsService,
    qdrant: QdrantVectorDB,
    graph: KnowledgeGraphService,
    compressor: ContextCompressionService,
}

impl HybridRagService {
    pub fn new(
        pool: PgPool,
        embeddings: EmbeddingsService,
        qdrant: QdrantVectorDB,
        graph: KnowledgeGraphService,
        compressor: ContextCompressionService,
    ) -> Self {
        Self {
            pool,
            embeddings,
            qdrant,
            graph,
            compressor,
        }
    }

    async fn keyword_search(
        &self,
        query: &str,
        language: &str,
        limit: usize,
    ) -> Result<Vec<HybridRetrievedChunk>, ApiError> {
        let tokens = query
            .split(|c: char| !c.is_alphanumeric() && c != '_' && c != 'آ' && c != 'ء')
            .filter(|token| !token.is_empty())
            .map(|token| token.to_ascii_lowercase())
            .collect::<Vec<_>>();
        let rows = sqlx::query(
            r#"
            SELECT c.id, c.document_id, c.chunk_text, c.citation_text, c.language, c.review_status,
                   c.source_type, d.title AS document_title, s.title AS source_title
            FROM sakina_ai.islamic_chunks c
            JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE c.chunk_text ILIKE $1
              AND ($2::text IS NULL OR c.language = $2)
              AND c.review_status IN ('verified', 'approved')
              AND s.review_status IN ('verified', 'approved')
            ORDER BY c.created_at DESC
            LIMIT $3
            "#,
        )
        .bind(format!("%{}%", query.trim()))
        .bind(if language.trim().is_empty() {
            None::<String>
        } else {
            Some(language.to_string())
        })
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to run keyword search"))?;

        let mut chunks = Vec::new();
        for row in rows {
            let text: String = row.get("chunk_text");
            let overlap = tokens
                .iter()
                .filter(|token| text.to_ascii_lowercase().contains(token.as_str()))
                .count();
            let keyword_score = if tokens.is_empty() {
                0.0
            } else {
                overlap as f32 / tokens.len() as f32
            };
            let source_type: String = row.get("source_type");
            let review_status: String = row.get("review_status");
            let mut chunk = HybridRetrievedChunk {
                chunk_id: row.get("id"),
                document_id: row.get("document_id"),
                title: row.get::<String, _>("source_title"),
                citation: row.get("citation_text"),
                source_type,
                language: row.get("language"),
                review_status,
                chunk_text: text,
                keyword_score,
                vector_score: 0.0,
                graph_score: 0.0,
                source_trust_score: 0.0,
                final_score: 0.0,
            };
            chunk.source_trust_score =
                Self::source_trust_score(&chunk.source_type, &chunk.review_status);
            Self::recompute_final_score(&mut chunk);
            chunks.push(chunk);
        }
        Ok(chunks)
    }

    fn source_trust_score(source_type: &str, review_status: &str) -> f32 {
        let type_score = match source_type.trim().to_ascii_lowercase().as_str() {
            "quran" => 1.0,
            "hadith" => 0.9,
            "tafsir" => 0.82,
            "fiqh" | "scholar-reviewed" => 0.76,
            "internal-approved" => 0.62,
            _ => 0.35,
        };
        let review_multiplier = match review_status.trim().to_ascii_lowercase().as_str() {
            "verified" => 1.0,
            "approved" => 0.88,
            _ => 0.0,
        };
        type_score * review_multiplier
    }

    fn recompute_final_score(chunk: &mut HybridRetrievedChunk) {
        chunk.final_score = (chunk.keyword_score * 0.38)
            + (chunk.vector_score * 0.32)
            + (chunk.graph_score * 0.12)
            + (chunk.source_trust_score * 0.18);
    }

    async fn vector_search(
        &self,
        query: &str,
        chunks: &mut [HybridRetrievedChunk],
    ) -> Result<Vec<HybridRetrievedChunk>, ApiError> {
        let embedding = match self.embeddings.embed(query).await {
            Ok(embedding) => embedding,
            Err(_) => return Ok(Vec::new()),
        };
        let qdrant_hits = match self.qdrant.search(&embedding, 0.0, 25).await {
            Ok(hits) => hits,
            Err(_) => return Ok(Vec::new()),
        };
        let mut scores = HashMap::new();
        for hit in qdrant_hits {
            if let Some(payload) = hit.payload.as_ref() {
                let chunk_id = payload
                    .get("chunk_id")
                    .and_then(|value| value.as_str())
                    .map(|value| value.to_string())
                    .or_else(|| {
                        payload
                            .get("chunk_id")
                            .and_then(|value| value.as_i64())
                            .map(|value| value.to_string())
                    });
                if let Some(chunk_id) = chunk_id {
                    scores.insert(chunk_id, hit.score);
                }
            }
        }

        let mut missing_chunk_ids = Vec::new();
        for chunk in chunks.iter_mut() {
            let key = chunk.chunk_id.to_string();
            if let Some(score) = scores.get(&key) {
                chunk.vector_score = *score;
                Self::recompute_final_score(chunk);
            }
        }
        for chunk_id in scores.keys() {
            let parsed = match Uuid::parse_str(chunk_id) {
                Ok(value) => value,
                Err(_) => continue,
            };
            if !chunks.iter().any(|chunk| chunk.chunk_id == parsed) {
                missing_chunk_ids.push(parsed);
            }
        }

        if missing_chunk_ids.is_empty() {
            return Ok(Vec::new());
        }

        let rows = sqlx::query(
            r#"
            SELECT c.id, c.document_id, c.chunk_text, c.citation_text, c.language, c.review_status,
                   c.source_type, d.title AS document_title, s.title AS source_title
            FROM sakina_ai.islamic_chunks c
            JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE c.id = ANY($1)
              AND c.review_status IN ('verified', 'approved')
              AND s.review_status IN ('verified', 'approved')
            "#,
        )
        .bind(&missing_chunk_ids)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to resolve vector search chunks"))?;

        let mut vector_chunks = Vec::new();
        for row in rows {
            let chunk_id: Uuid = row.get("id");
            let vector_score = scores
                .get(&chunk_id.to_string())
                .copied()
                .unwrap_or_default();
            let source_type: String = row.get("source_type");
            let review_status: String = row.get("review_status");
            let mut chunk = HybridRetrievedChunk {
                chunk_id,
                document_id: row.get("document_id"),
                title: row.get::<String, _>("source_title"),
                citation: row.get("citation_text"),
                source_type,
                language: row.get("language"),
                review_status,
                chunk_text: row.get("chunk_text"),
                keyword_score: 0.0,
                vector_score,
                graph_score: 0.0,
                source_trust_score: 0.0,
                final_score: 0.0,
            };
            chunk.source_trust_score =
                Self::source_trust_score(&chunk.source_type, &chunk.review_status);
            Self::recompute_final_score(&mut chunk);
            vector_chunks.push(chunk);
        }

        Ok(vector_chunks)
    }

    pub async fn search(
        &self,
        query: &str,
        language: Option<&str>,
        top_k: usize,
    ) -> Result<HybridRagResult, ApiError> {
        let language = language.unwrap_or("en").trim().to_ascii_lowercase();
        let keyword_limit = top_k.saturating_mul(4).max(10);
        let mut chunks = self.keyword_search(query, &language, keyword_limit).await?;
        let vector_only_chunks = self.vector_search(query, &mut chunks).await?;
        chunks.extend(vector_only_chunks);

        let graph_result = self.graph.lookup(query).await?;
        let graph_citations = graph_result.citations.clone();
        let graph_path = graph_result.graph_path.clone();
        for chunk in &mut chunks {
            let chunk_lower = chunk.chunk_text.to_ascii_lowercase();
            let related_hit = graph_result
                .related_topics
                .iter()
                .any(|topic| chunk_lower.contains(&topic.to_ascii_lowercase()));
            if related_hit {
                chunk.graph_score = 0.4;
            }
            Self::recompute_final_score(chunk);
        }

        let mut best_by_chunk: HashMap<Uuid, HybridRetrievedChunk> = HashMap::new();
        for chunk in chunks {
            match best_by_chunk.get(&chunk.chunk_id) {
                Some(existing) if existing.final_score >= chunk.final_score => {}
                _ => {
                    best_by_chunk.insert(chunk.chunk_id, chunk);
                }
            }
        }
        let mut chunks = best_by_chunk.into_values().collect::<Vec<_>>();

        chunks.sort_by(|a, b| {
            b.final_score
                .partial_cmp(&a.final_score)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| {
                    b.keyword_score
                        .partial_cmp(&a.keyword_score)
                        .unwrap_or(std::cmp::Ordering::Equal)
                })
        });
        chunks.truncate(top_k);

        let compressed_inputs = chunks
            .iter()
            .map(|chunk| CompressedEvidenceChunk {
                source_id: chunk.chunk_id.to_string(),
                title: chunk.title.clone(),
                citation: chunk.citation.clone(),
                trust_level: chunk.review_status.clone(),
                language: chunk.language.clone(),
                text: chunk.chunk_text.clone(),
            })
            .collect::<Vec<_>>();
        let compression_report = self.compressor.compress(&compressed_inputs, top_k);

        let mut citations = chunks
            .iter()
            .map(|chunk| SourceReference {
                id: chunk.chunk_id.to_string(),
                title: chunk.title.clone(),
                author: chunk.source_type.clone(),
                chapter: chunk.citation.clone(),
                authenticity_grade: chunk.review_status.clone(),
            })
            .collect::<Vec<_>>();
        citations.extend(
            graph_citations
                .into_iter()
                .enumerate()
                .map(|(index, citation)| SourceReference {
                    id: format!("graph-{}", index),
                    title: citation.clone(),
                    author: "knowledge_graph".to_string(),
                    chapter: citation,
                    authenticity_grade: "verified".to_string(),
                }),
        );
        citations.sort_by(|a, b| a.id.cmp(&b.id));
        citations.dedup_by(|a, b| a.id == b.id);

        let source_ranking = chunks
            .iter()
            .map(|chunk| {
                format!(
                    "{}:{}:{}:trust={:.2}:score={:.2}",
                    chunk.title,
                    chunk.source_type,
                    chunk.review_status,
                    chunk.source_trust_score,
                    chunk.final_score
                )
            })
            .collect::<Vec<_>>();

        let weak_evidence_blocked = chunks.is_empty()
            || chunks
                .first()
                .map(|chunk| chunk.final_score < 0.25)
                .unwrap_or(true);

        Ok(HybridRagResult {
            query: query.to_string(),
            language,
            retrieval_strategy: "keyword+vector+graph".to_string(),
            retrieved_chunks: chunks,
            source_ranking,
            citations: citations.into_iter().take(top_k).collect(),
            graph_path,
            compressed_tokens_before: compression_report.tokens_before,
            compressed_tokens_after: compression_report.tokens_after,
            compression_ratio: compression_report.compression_ratio,
            weak_evidence_blocked,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hybrid_result_serializes() {
        let result = HybridRagResult {
            query: "patience".to_string(),
            language: "en".to_string(),
            retrieval_strategy: "keyword+vector+graph".to_string(),
            retrieved_chunks: vec![],
            source_ranking: vec![],
            citations: vec![],
            graph_path: vec![],
            compressed_tokens_before: 0,
            compressed_tokens_after: 0,
            compression_ratio: 1.0,
            weak_evidence_blocked: true,
        };
        let json = serde_json::to_string(&result).unwrap();
        assert!(json.contains("keyword+vector+graph"));
    }
}
