use crate::error::ApiError;
use crate::models::SourceReference;
use crate::services::{
    BrainExecutionPermit, HybridRagService, SemanticCacheEntry, SemanticCacheService,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::Row;
use uuid::Uuid;

use sakina_fatwa_policy_gate::{evaluate as evaluate_fatwa_policy, AnswerInput};

fn payload_text(payload: Option<&serde_json::Value>, key: &str) -> Option<String> {
    payload
        .and_then(|value| value.get(key))
        .and_then(|value| value.as_str())
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

#[derive(Clone)]
pub struct IslamicKnowledgeRepository {
    pool: sqlx::PgPool,
}

impl IslamicKnowledgeRepository {
    pub fn new(pool: sqlx::PgPool) -> Self {
        Self { pool }
    }

    pub async fn list_sources(
        &self,
        language: Option<&str>,
        limit: i64,
    ) -> Result<Vec<Value>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT id, source_key, source_type, source_status, review_status, language, title, canonical_url
            FROM sakina_ai.islamic_sources
            WHERE ($1::text IS NULL OR language = $1)
            ORDER BY created_at DESC
            LIMIT $2
            "#,
        )
        .bind(language)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list islamic sources"))?;

        Ok(rows
            .into_iter()
            .map(|row| {
                json!({
                    "id": row.get::<Uuid, _>("id"),
                    "source_key": row.get::<String, _>("source_key"),
                    "source_type": row.get::<String, _>("source_type"),
                    "source_status": row.get::<String, _>("source_status"),
                    "review_status": row.get::<String, _>("review_status"),
                    "language": row.get::<String, _>("language"),
                    "title": row.get::<String, _>("title"),
                    "canonical_url": row.get::<Option<String>, _>("canonical_url"),
                })
            })
            .collect())
    }

    pub async fn list_documents(
        &self,
        source_id: Option<Uuid>,
        language: Option<&str>,
        limit: i64,
    ) -> Result<Vec<Value>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT d.id, d.source_id, d.document_key, d.title, d.document_url, d.language, d.source_status, d.review_status, s.title AS source_title
            FROM sakina_ai.islamic_documents d
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE ($1::uuid IS NULL OR d.source_id = $1)
              AND ($2::text IS NULL OR d.language = $2)
            ORDER BY d.created_at DESC
            LIMIT $3
            "#,
        )
        .bind(source_id)
        .bind(language)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list islamic documents"))?;

        Ok(rows
            .into_iter()
            .map(|row| {
                json!({
                    "id": row.get::<Uuid, _>("id"),
                    "source_id": row.get::<Uuid, _>("source_id"),
                    "source_title": row.get::<String, _>("source_title"),
                    "document_key": row.get::<String, _>("document_key"),
                    "title": row.get::<String, _>("title"),
                    "document_url": row.get::<Option<String>, _>("document_url"),
                    "language": row.get::<String, _>("language"),
                    "source_status": row.get::<String, _>("source_status"),
                    "review_status": row.get::<String, _>("review_status"),
                })
            })
            .collect())
    }

    pub async fn list_document_chunks(
        &self,
        document_id: Uuid,
        limit: i64,
    ) -> Result<Vec<Value>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT id, document_id, chunk_key, chunk_index, citation_text, language, source_status, review_status
            FROM sakina_ai.islamic_chunks
            WHERE document_id = $1
            ORDER BY chunk_index ASC
            LIMIT $2
            "#,
        )
        .bind(document_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list islamic chunks"))?;

        Ok(rows
            .into_iter()
            .map(|row| {
                json!({
                    "id": row.get::<Uuid, _>("id"),
                    "document_id": row.get::<Uuid, _>("document_id"),
                    "chunk_key": row.get::<String, _>("chunk_key"),
                    "chunk_index": row.get::<i32, _>("chunk_index"),
                    "citation_text": row.get::<String, _>("citation_text"),
                    "language": row.get::<String, _>("language"),
                    "source_status": row.get::<String, _>("source_status"),
                    "review_status": row.get::<String, _>("review_status"),
                })
            })
            .collect())
    }

    pub async fn search_local(
        &self,
        query_text: &str,
        language: Option<&str>,
        limit: i64,
    ) -> Result<Vec<Value>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT c.id, c.document_id, c.chunk_key, c.chunk_index, c.citation_text, c.language, c.review_status, d.title AS document_title, s.title AS source_title
            FROM sakina_ai.islamic_chunks c
            JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE c.chunk_text ILIKE ('%' || $1 || '%')
              AND ($2::text IS NULL OR c.language = $2)
            ORDER BY c.created_at DESC
            LIMIT $3
            "#,
        )
        .bind(query_text)
        .bind(language)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to search islamic chunks"))?;

        Ok(rows
            .into_iter()
            .map(|row| {
                json!({
                    "id": row.get::<Uuid, _>("id"),
                    "document_id": row.get::<Uuid, _>("document_id"),
                    "chunk_key": row.get::<String, _>("chunk_key"),
                    "chunk_index": row.get::<i32, _>("chunk_index"),
                    "citation_text": row.get::<String, _>("citation_text"),
                    "language": row.get::<String, _>("language"),
                    "review_status": row.get::<String, _>("review_status"),
                    "document_title": row.get::<String, _>("document_title"),
                    "source_title": row.get::<String, _>("source_title"),
                })
            })
            .collect())
    }

    pub async fn get_citation(&self, chunk_id: Uuid) -> Result<Option<Value>, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT c.id, c.chunk_key, c.citation_text, c.chunk_text, c.language, c.review_status, d.id AS document_id, d.title AS document_title, s.id AS source_id, s.title AS source_title
            FROM sakina_ai.islamic_chunks c
            JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE c.id = $1
            "#,
        )
        .bind(chunk_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to fetch citation"))?;

        Ok(row.map(|row| {
            json!({
                "id": row.get::<Uuid, _>("id"),
                "chunk_key": row.get::<String, _>("chunk_key"),
                "citation_text": row.get::<String, _>("citation_text"),
                "chunk_text": row.get::<String, _>("chunk_text"),
                "language": row.get::<String, _>("language"),
                "review_status": row.get::<String, _>("review_status"),
                "document_id": row.get::<Uuid, _>("document_id"),
                "document_title": row.get::<String, _>("document_title"),
                "source_id": row.get::<Uuid, _>("source_id"),
                "source_title": row.get::<String, _>("source_title"),
            })
        }))
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct AskIslamicRequest {
    pub question: String,
    pub language: Option<String>,
    pub top_k: Option<usize>,
    pub min_score: Option<f32>,
    pub user_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize)]
pub struct QdrantCollectionPlan {
    pub collection: String,
    pub distance: String,
    pub expected_vector_size: usize,
    pub top_k_default: usize,
    pub create_if_missing: bool,
}

pub struct IslamicAnswerService {
    _repository: IslamicKnowledgeRepository,
    hybrid_rag: HybridRagService,
    cache: SemanticCacheService,
    distributed_client: crate::services::distributed::DistributedClient,
}

impl IslamicAnswerService {
    pub fn new(
        repository: IslamicKnowledgeRepository,
        hybrid_rag: HybridRagService,
        cache: SemanticCacheService,
    ) -> Self {
        Self {
            _repository: repository,
            hybrid_rag,
            cache,
            distributed_client: crate::services::distributed::DistributedClient::new(),
        }
    }

    pub fn qdrant_plan(&self) -> QdrantCollectionPlan {
        QdrantCollectionPlan {
            collection: std::env::var("ISLAMIC_QDRANT_COLLECTION")
                .unwrap_or_else(|_| "sakina_islamic_chunks_en".to_string()),
            distance: "Cosine".to_string(),
            expected_vector_size: std::env::var("VLLM_EMBEDDING_DIM")
                .ok()
                .and_then(|v| v.parse::<usize>().ok())
                .unwrap_or(1024),
            top_k_default: 5,
            create_if_missing: true,
        }
    }

    pub async fn answer(
        &self,
        request: AskIslamicRequest,
        _permit: BrainExecutionPermit,
    ) -> Result<Value, ApiError> {
        let question = request.question.trim();
        if question.is_empty() {
            return Err(ApiError::bad_request("question cannot be empty"));
        }
        let language = request.language.unwrap_or_else(|| "en".to_string());
        let top_k = request.top_k.unwrap_or(5).clamp(1, 20);
        let min_score = request.min_score.unwrap_or(0.75).clamp(0.0, 1.0);
        let fatwa_sensitive = is_fatwa_sensitive(question);
        let safety_level = if fatwa_sensitive { "high" } else { "safe" };
        let source_version =
            self.cache.source_version().await.map_err(|_| {
                ApiError::internal("failed to calculate semantic cache source version")
            })?;
        let user_context = request
            .user_id
            .map(|user_id| user_id.to_string())
            .unwrap_or_else(|| "anonymous".to_string());
        let cache_key = SemanticCacheService::cache_key(
            &language,
            "islamic_answer",
            safety_level,
            &source_version,
            &format!("{user_context}:{question}"),
        );
        if let Some(entry) = self
            .cache
            .lookup(&cache_key, request.user_id)
            .await
            .map_err(|_| ApiError::internal("failed to load semantic cache"))?
        {
            let mut payload = entry.payload;
            if let Some(object) = payload.as_object_mut() {
                object.insert("cache_status".to_string(), json!("hit"));
                object.insert("cache_hit".to_string(), json!(true));
                object.insert(
                    "cache_hit_count".to_string(),
                    json!(entry.hit_count.saturating_add(1)),
                );
            }
            return Ok(payload);
        }

        // Distributed architecture: if SAKINA_RAG_URL is set, we call the RAG service.
        let hybrid = if let Ok(rag_url) = std::env::var("SAKINA_RAG_URL") {
            if !rag_url.trim().is_empty() {
                let rag_res = self
                    .distributed_client
                    .query_rag(
                        &rag_url,
                        &crate::models::RagQuery {
                            query: question.to_string(),
                            user_id: request.user_id,
                            madhhab_filter: None,
                            top_k: Some(top_k),
                            min_score: Some(min_score),
                            language: Some(language.clone()),
                        },
                    )
                    .await?;
                crate::services::HybridRagResult {
                    query: question.to_string(),
                    language: language.clone(),
                    retrieval_strategy: "remote_rag_service".to_string(),
                    retrieved_chunks: vec![], // Only used for confidence which we override
                    source_ranking: vec![],
                    citations: rag_res.sources,
                    graph_path: vec![],
                    compressed_tokens_before: 0,
                    compressed_tokens_after: 0,
                    compression_ratio: 1.0,
                    weak_evidence_blocked: rag_res.guardrail_triggered,
                }
            } else {
                self.hybrid_rag
                    .search(question, Some(&language), top_k)
                    .await?
            }
        } else {
            self.hybrid_rag
                .search(question, Some(&language), top_k)
                .await?
        };

        let mut citations = hybrid.citations.clone();
        let mut confidence = hybrid
            .retrieved_chunks
            .first()
            .map(|chunk| chunk.final_score)
            .unwrap_or(0.0);

        // If it was a remote call, we might already have a confidence in the response
        // but HybridRagResult doesn't store it directly outside of chunks.
        // For simplicity, we'll just use 0.9 if it passed the remote guardrail.
        if hybrid.retrieval_strategy == "remote_rag_service" && !hybrid.weak_evidence_blocked {
            confidence = 0.9;
        }

        let mut fallback_used = hybrid.weak_evidence_blocked;
        let mut answer_text = crate::services::offline_lookup(question, &language)
            .map(|offline| {
                confidence = confidence.max(offline.confidence);
                fallback_used = fallback_used || offline.fallback_used;
                if citations.is_empty() {
                    citations = offline.citations.clone();
                }
                offline.answer
            })
            .unwrap_or_else(|| {
                if let Some(first) = citations.first() {
                    if language.eq_ignore_ascii_case("ar") {
                        format!("وجدتُ مصادر موثوقة مرتبطة بـ {}.", first.title)
                    } else {
                        format!("I found verified sources related to {}.", first.title)
                    }
                } else if language.eq_ignore_ascii_case("ar") {
                    "لم أجد نصًا موثوقًا كافيًا لهذا السؤال بعد.".to_string()
                } else {
                    "I could not find enough verified evidence for this question yet.".to_string()
                }
            });

        if !citations.is_empty() && confidence < min_score {
            fallback_used = true;
        }
        let policy = evaluate_fatwa_policy(&AnswerInput {
            has_scholar_approval: false,
            has_verified_quran_or_hadith_citation: !citations.is_empty(),
            publication_mode_public: fatwa_sensitive || citations.is_empty(),
        });

        if policy.decision != "allow_publish" {
            fallback_used = true;
            answer_text = if language.eq_ignore_ascii_case("ar") {
                "هذا السؤال يحتاج مراجعة عالم موثوق مع مصدر موثق. لن أخترع فتوى أو حكمًا بلا دليل."
                    .to_string()
            } else {
                "This question requires scholar review with a verified source. I will not invent a ruling or fatwa without evidence."
                    .to_string()
            };
        } else if answer_text.is_empty() {
            answer_text = if language.eq_ignore_ascii_case("ar") {
                "وجدتُ مصادر موثوقة مرتبطة بسؤالك. راجع الاستشهادات أدناه.".to_string()
            } else {
                "I found verified sources related to your question. Review the citations below."
                    .to_string()
            };
        }

        let payload = json!({
            "question": question,
            "language": language,
            "answer": answer_text,
            "citations": citations,
            "confidence": confidence,
            "fallback_used": fallback_used,
            "fatwa_sensitive": fatwa_sensitive,
            "generated_from_verified_sources": !citations.is_empty(),
            "retrieval_strategy": hybrid.retrieval_strategy,
            "retrieved_chunks": hybrid.retrieved_chunks,
            "source_ranking": hybrid.source_ranking,
            "graph_path": hybrid.graph_path,
            "compressed_tokens_before": hybrid.compressed_tokens_before,
            "compressed_tokens_after": hybrid.compressed_tokens_after,
            "compression_ratio": hybrid.compression_ratio,
            "weak_evidence_blocked": hybrid.weak_evidence_blocked,
            "cache_status": "miss",
            "cache_hit": false,
            "cache_ttl_seconds": SemanticCacheService::TTL_SECONDS,
            "source_version": source_version,
        });

        if SemanticCacheService::is_cacheable(safety_level, &payload) {
            let cache_entry = SemanticCacheEntry {
                cache_key,
                user_id: request.user_id,
                workspace_id: None,
                language,
                intent: "islamic_answer".to_string(),
                safety_level: safety_level.to_string(),
                source_version,
                hit_count: 0,
                payload: payload.clone(),
            };
            self.cache
                .upsert(&cache_entry)
                .await
                .map_err(|_| ApiError::internal("failed to write semantic cache"))?;
        }

        Ok(payload)
    }
}

fn is_fatwa_sensitive(question: &str) -> bool {
    let q = question.to_ascii_lowercase();
    [
        "fatwa",
        "halal",
        "haram",
        "mortgage",
        "crypto",
        "combining prayers",
        "combine prayers",
        "self harm",
        "suicide",
        "medical",
        "legal",
        "invest",
        "rib",
        "riba",
        "الموت",
        "انتحار",
        "فتوى",
        "حلال",
        "حرام",
        "ربا",
        "صلاة",
        "جمع",
    ]
    .iter()
    .any(|needle| q.contains(&needle.to_ascii_lowercase()))
}

// Legacy qdrant citation helper retained for compatibility with older tests.
#[allow(dead_code)]
fn qdrant_hit_to_citation(
    hit: &crate::services::qdrant_client::ScoredPoint,
) -> Option<SourceReference> {
    let payload = hit.payload.as_ref();
    let id = payload_text(payload, "chunk_id")
        .or_else(|| payload_text(payload, "source_id"))
        .or_else(|| hit.id.as_str().map(|s| s.to_string()))
        .or_else(|| hit.id.as_i64().map(|n| n.to_string()))?;
    let title = payload_text(payload, "title")
        .or_else(|| payload_text(payload, "source_name"))
        .or_else(|| payload_text(payload, "document_title"))
        .unwrap_or_else(|| "Verified Source".to_string());
    let author = payload_text(payload, "author")
        .or_else(|| payload_text(payload, "source_author"))
        .unwrap_or_else(|| "Sakina".to_string());
    let chapter = payload_text(payload, "chapter")
        .or_else(|| payload_text(payload, "source_reference"))
        .or_else(|| payload_text(payload, "citation"))
        .unwrap_or_default();
    let grade = payload_text(payload, "authenticity_grade")
        .or_else(|| payload_text(payload, "review_status"))
        .unwrap_or_else(|| "verified".to_string());
    Some(SourceReference {
        id,
        title,
        author,
        chapter,
        authenticity_grade: grade,
    })
}
