use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use sqlx::PgPool;
use std::sync::Arc;
use std::time::Instant;

use crate::error::ApiError;
use crate::middleware::rate_limit::enforce_rate_limit;
use crate::models::{RagQuery, RagResponse, SourceReference};
use crate::services::{
    CitationEngine, EmbeddingsService, Guardrails, LlmService, QdrantVectorDB, QueryIntent,
    RetrievedContext, SemanticRouter,
};
use uuid::Uuid;

/// Real RAG pipeline (Step 18): classify -> embed -> guardrail -> Qdrant search
/// -> cite -> answer.
///
/// Structured for production but NOT runtime-tested here: it needs a live vLLM
/// (embeddings), a live Qdrant with indexed chunks, and a populated Postgres.
#[tracing::instrument(skip_all)]
pub async fn query_rag(
    req: HttpRequest,
    services: web::Data<RagServices>,
    qdrant: web::Data<QdrantVectorDB>,
    embeddings: web::Data<EmbeddingsService>,
    llm: web::Data<LlmService>,
    pool: web::Data<PgPool>,
    query: web::Json<RagQuery>,
) -> Result<HttpResponse, ApiError> {
    let start = Instant::now();
    const THRESHOLD: f32 = 0.85;
    enforce_rate_limit(&req, "rag_query", 20, std::time::Duration::from_secs(60))?;
    if let Some(authenticated_user_id) = req.extensions().get::<Uuid>().copied() {
        if authenticated_user_id != query.user_id {
            return Err(ApiError::forbidden(
                "user_id does not match authenticated identity",
            ));
        }
    }

    // 1. Classify intent before spending vector/LLM capacity.
    let intent = services
        .router
        .classify(&query.query)
        .await
        .map_err(ApiError::from)?;
    if matches!(intent.intent, QueryIntent::OutOfScope) {
        persist_guardrail_event(
            pool.get_ref(),
            query.user_id,
            &query.query,
            "OUT_OF_SCOPE",
            intent.confidence,
        )
        .await;
        return Ok(HttpResponse::Ok().json(RagResponse {
            answer: "I can only help with Islamic guidance grounded in verified sources."
                .to_string(),
            sources: vec![],
            confidence: intent.confidence,
            guardrail_triggered: true,
            processing_time_ms: start.elapsed().as_millis() as u64,
        }));
    }

    // 2. Embed the query (vLLM).
    let embedding = embeddings
        .embed(&query.query)
        .await
        .map_err(ApiError::from)?;

    // 3. Search first without threshold so the guardrail can inspect the real
    // top score, then keep only support above the production threshold.
    let all_hits = qdrant
        .search(&embedding, 0.0, 5)
        .await
        .map_err(ApiError::from)?;
    let top_score = all_hits.first().map(|hit| hit.score).unwrap_or(0.0);
    let guard = services.guardrails.evaluate_score(top_score);
    if !guard.passed {
        persist_guardrail_event(
            pool.get_ref(),
            query.user_id,
            &query.query,
            guard
                .reason
                .as_deref()
                .unwrap_or("SIMILARITY_THRESHOLD_FAILED"),
            guard.confidence,
        )
        .await;
        return Ok(HttpResponse::Ok().json(RagResponse {
            answer: "To maintain accuracy, I cannot provide an answer below our \
                     confidence threshold. Please consult a qualified Islamic scholar."
                .to_string(),
            sources: vec![],
            confidence: 0.0,
            guardrail_triggered: true,
            processing_time_ms: start.elapsed().as_millis() as u64,
        }));
    }

    // 4. Keep only supporting chunks that satisfy the guardrail threshold.
    let hits: Vec<_> = all_hits
        .into_iter()
        .filter(|hit| hit.score >= THRESHOLD)
        .collect();
    let contexts: Vec<RetrievedContext> = hits.iter().filter_map(context_from_hit).collect();
    if hits.is_empty() || contexts.is_empty() {
        persist_guardrail_event(
            pool.get_ref(),
            query.user_id,
            &query.query,
            if hits.is_empty() {
                "NO_VERIFIED_SOURCES"
            } else {
                "NO_RETRIEVED_CONTEXT"
            },
            guard.confidence,
        )
        .await;
        return Ok(HttpResponse::Ok().json(RagResponse {
            answer: "I don't have reliable verified sources on this topic. Please \
                     consult a qualified Islamic scholar."
                .to_string(),
            sources: vec![],
            confidence: 0.0,
            guardrail_triggered: true,
            processing_time_ms: start.elapsed().as_millis() as u64,
        }));
    }

    // 5. Citations for the retrieved chunk IDs.
    let chunk_ids: Vec<Uuid> = hits.iter().filter_map(chunk_id_from_hit).collect();
    let sources: Vec<SourceReference> = services
        .citations
        .cite(&chunk_ids)
        .await?
        .into_iter()
        .enumerate()
        .map(|(i, c)| SourceReference {
            id: format!("chunk-{}", i + 1),
            title: c.title,
            author: c.author,
            chapter: c.chapter.unwrap_or_default(),
            authenticity_grade: c.authenticity_grade.unwrap_or_default(),
        })
        .collect();

    // 6. Grounded answer generation using only retrieved context.
    let answer = llm
        .generate_grounded_answer(&query.query, &contexts)
        .await?;

    Ok(HttpResponse::Ok().json(RagResponse {
        answer,
        sources,
        confidence: guard.confidence,
        guardrail_triggered: false,
        processing_time_ms: start.elapsed().as_millis() as u64,
    }))
}

pub struct RagServices {
    pub router: Arc<SemanticRouter>,
    pub guardrails: Arc<Guardrails>,
    pub citations: Arc<CitationEngine>,
}

fn chunk_id_from_hit(point: &crate::services::ScoredPoint) -> Option<Uuid> {
    point
        .payload
        .as_ref()
        .and_then(|payload| payload.get("chunk_id"))
        .and_then(|id| id.as_str())
        .or_else(|| point.id.as_str())
        .and_then(|id| Uuid::parse_str(id).ok())
}

fn context_from_hit(point: &crate::services::ScoredPoint) -> Option<RetrievedContext> {
    let payload = point.payload.as_ref()?;
    let text = payload.get("text").and_then(|v| v.as_str())?.trim();
    if text.is_empty() {
        return None;
    }

    let chunk_id = payload
        .get("chunk_id")
        .and_then(|id| id.as_str())
        .or_else(|| point.id.as_str())
        .unwrap_or("")
        .to_string();
    let title = payload
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("Verified Islamic source")
        .to_string();

    Some(RetrievedContext {
        chunk_id,
        title,
        text: text.to_string(),
    })
}

async fn persist_guardrail_event(
    pool: &PgPool,
    user_id: Uuid,
    query: &str,
    reason: &str,
    confidence: f32,
) {
    if let Err(e) = sqlx::query(
        "INSERT INTO audit.logs (event_type, payload, user_id) \
         VALUES ($1, $2, $3)",
    )
    .bind("guardrail_triggered")
    .bind(serde_json::json!({
        "query": query,
        "trigger_reason": reason,
        "confidence": confidence
    }))
    .bind(user_id)
    .execute(pool)
    .await
    {
        tracing::warn!("failed to persist guardrail audit log: {}", e);
    }
}
