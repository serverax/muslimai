use actix_web::{web, HttpResponse};
use std::sync::Arc;
use std::time::Instant;

use crate::error::ApiError;
use crate::models::{RagQuery, RagResponse, SourceReference};
use crate::services::{CitationEngine, Guardrails, SemanticRouter};

pub async fn query_rag(
    router: web::Data<Arc<SemanticRouter>>,
    guardrails: web::Data<Arc<Guardrails>>,
    citations: web::Data<Arc<CitationEngine>>,
    query: web::Json<RagQuery>,
) -> Result<HttpResponse, ApiError> {
    let start = Instant::now();

    // 1. Classify intent (routing decision; not yet branched on — stub).
    let _intent = router.classify(&query.query).await?;

    // 2. Guardrails: embed the query, then check the similarity threshold.
    //    The embedding is stubbed (empty) until vLLM embeddings are wired.
    let embedding: Vec<f32> = Vec::new();
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

    // 3. Citations for retrieved chunks (chunk IDs stubbed until retrieval lands).
    let chunk_ids: Vec<i64> = vec![];
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

    // 4. Answer generation is stubbed until vLLM is wired.
    Ok(HttpResponse::Ok().json(RagResponse {
        answer: format!("Response to: {}", query.query),
        sources,
        confidence: guard.confidence,
        guardrail_triggered: false,
        processing_time_ms: start.elapsed().as_millis() as u64,
    }))
}
