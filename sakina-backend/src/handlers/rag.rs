use actix_web::{web, HttpResponse};
use std::sync::Arc;
use std::time::Instant;

use crate::error::ApiError;
use crate::models::{RagQuery, RagResponse, SourceReference};
use crate::services::{
    CitationEngine, EmbeddingsService, Guardrails, QdrantVectorDB, SemanticRouter,
};

/// Real RAG pipeline (Step 18): classify -> embed -> guardrail -> Qdrant search
/// -> cite -> answer.
///
/// Structured for production but NOT runtime-tested here: it needs a live vLLM
/// (embeddings), a live Qdrant with indexed chunks, and a populated Postgres.
/// The final answer generation (vLLM completion) is still a placeholder.
#[tracing::instrument(skip_all)]
pub async fn query_rag(
    router: web::Data<Arc<SemanticRouter>>,
    guardrails: web::Data<Arc<Guardrails>>,
    citations: web::Data<Arc<CitationEngine>>,
    qdrant: web::Data<QdrantVectorDB>,
    embeddings: web::Data<EmbeddingsService>,
    query: web::Json<RagQuery>,
) -> Result<HttpResponse, ApiError> {
    let start = Instant::now();
    const THRESHOLD: f32 = 0.85;

    // 1. Classify intent (routing decision; not yet branched on).
    let _intent = router.classify(&query.query).await?;

    // 2. Embed the query (vLLM).
    let embedding = embeddings.embed(&query.query).await?;

    // 3. Guardrail check on the embedding.
    let guard = guardrails.check(&embedding).await?;
    if !guard.passed {
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

    // 4. Vector search for supporting chunks.
    let hits = qdrant.search(&embedding, THRESHOLD, 5).await?;
    if hits.is_empty() {
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
    let chunk_ids: Vec<i64> = hits.iter().filter_map(|p| p.id.as_i64()).collect();
    let sources: Vec<SourceReference> = citations
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

    // 6. Answer generation (vLLM completion) — placeholder until wired.
    let answer = format!(
        "Based on verified Islamic sources: {}",
        sources.first().map(|s| s.title.as_str()).unwrap_or("(no source)")
    );

    Ok(HttpResponse::Ok().json(RagResponse {
        answer,
        sources,
        confidence: guard.confidence,
        guardrail_triggered: false,
        processing_time_ms: start.elapsed().as_millis() as u64,
    }))
}
