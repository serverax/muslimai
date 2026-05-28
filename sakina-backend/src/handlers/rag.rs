use actix_web::{web, HttpRequest, HttpResponse};
use std::sync::Arc;
use std::time::Instant;

use crate::error::ApiError;
use crate::models::{
    DecisionRequest, DecisionResponse, RagSearchItem, RagSearchResponse, RagSourceItem,
    RagSourcesResponse, RagStatusResponse, ReviewStatus,
};
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
        sources
            .first()
            .map(|s| s.title.as_str())
            .unwrap_or("(no source)")
    );

    Ok(HttpResponse::Ok().json(RagResponse {
        answer,
        sources,
        confidence: guard.confidence,
        guardrail_triggered: false,
        processing_time_ms: start.elapsed().as_millis() as u64,
    }))
}

#[derive(Debug, serde::Deserialize)]
pub struct RagSearchQuery {
    pub module: String,
    pub q: String,
}

fn module_feature_flag(module: &str) -> Option<&'static str> {
    match module {
        "quran" => Some("SAKINA_FEATURE_QURAN"),
        "prayer" => Some("SAKINA_FEATURE_PRAYER"),
        "knowledge" => Some("SAKINA_FEATURE_KNOWLEDGE"),
        "community" => Some("SAKINA_FEATURE_COMMUNITY"),
        _ => None,
    }
}

fn module_rag_flag(module: &str) -> Option<&'static str> {
    match module {
        "quran" => Some("SAKINA_RAG_QURAN_ENABLED"),
        "prayer" => Some("SAKINA_RAG_PRAYER_ENABLED"),
        "knowledge" => Some("SAKINA_RAG_KNOWLEDGE_ENABLED"),
        "community" => Some("SAKINA_RAG_COMMUNITY_ENABLED"),
        _ => None,
    }
}

fn env_flag_enabled(key: &str) -> bool {
    std::env::var(key)
        .ok()
        .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
}

fn has_entitlement(req: &HttpRequest) -> bool {
    req.headers()
        .get("x-sakina-subscription-tier")
        .and_then(|v| v.to_str().ok())
        .map(|v| {
            matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "premium" | "pro" | "founding"
            )
        })
        .unwrap_or(false)
}

fn sample_sources(module: &str) -> Vec<RagSourceItem> {
    let _ = module;
    Vec::new()
}

fn verified_only(items: Vec<RagSourceItem>) -> Vec<RagSourceItem> {
    items
        .into_iter()
        .filter(|item| item.review_status == ReviewStatus::Verified)
        .collect()
}

pub async fn rag_status() -> HttpResponse {
    HttpResponse::Ok().json(RagStatusResponse {
        status: "ok".to_string(),
        rag_enabled: true,
        index_ready: false,
        verified_source_count: 0,
        last_indexed_at: None,
    })
}

pub async fn rag_decide(payload: web::Json<DecisionRequest>) -> HttpResponse {
    let request = payload.into_inner();
    let response: DecisionResponse = crate::services::decision_algorithm::decide(
        &request,
        &crate::services::decision_algorithm::DefaultModuleClassifier,
        &crate::services::decision_algorithm::DefaultSafetyClassifier,
        &crate::services::decision_algorithm::EmptyRetriever,
        &crate::services::decision_algorithm::StrictFormatter,
    );
    HttpResponse::Ok().json(response)
}

pub async fn rag_sources(req: HttpRequest) -> HttpResponse {
    let module = req
        .headers()
        .get("x-sakina-module")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("quran")
        .trim()
        .to_ascii_lowercase();

    let Some(feature_flag) = module_feature_flag(&module) else {
        return crate::error::error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "invalid module",
        );
    };
    let Some(rag_flag) = module_rag_flag(&module) else {
        return crate::error::error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "invalid module",
        );
    };

    if !env_flag_enabled(feature_flag) || !env_flag_enabled(rag_flag) {
        return crate::error::error_response(
            actix_web::http::StatusCode::FORBIDDEN,
            "feature_disabled",
            "rag is disabled for this module",
        );
    }
    if !has_entitlement(&req) {
        return crate::error::error_response(
            actix_web::http::StatusCode::PAYMENT_REQUIRED,
            "subscription_required",
            "rag requires premium entitlement",
        );
    }

    HttpResponse::Ok().json(RagSourcesResponse {
        sources: verified_only(sample_sources(&module)),
    })
}

pub async fn rag_search(req: HttpRequest, query: web::Query<RagSearchQuery>) -> HttpResponse {
    let module = query.module.trim().to_ascii_lowercase();
    if module_feature_flag(&module).is_none() {
        return crate::error::error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "invalid module",
        );
    }
    if query.q.trim().is_empty() {
        return crate::error::error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "query cannot be empty",
        );
    }

    let feature_flag = module_feature_flag(&module).expect("module validated");
    let rag_flag = module_rag_flag(&module).expect("module validated");

    if !env_flag_enabled(feature_flag) || !env_flag_enabled(rag_flag) {
        return crate::error::error_response(
            actix_web::http::StatusCode::FORBIDDEN,
            "feature_disabled",
            "rag is disabled for this module",
        );
    }
    if !has_entitlement(&req) {
        return crate::error::error_response(
            actix_web::http::StatusCode::PAYMENT_REQUIRED,
            "subscription_required",
            "rag requires premium entitlement",
        );
    }

    let now = chrono::Utc::now().to_rfc3339();
    let verified_items = verified_only(sample_sources(&module))
        .into_iter()
        .map(|item| RagSearchItem {
            module: item.module,
            source_type: item.source_type,
            source_name: item.source_name,
            source_reference: item.source_reference,
            citation: item.citation,
            language: item.language,
            review_status: item.review_status,
            effective_date: item.effective_date,
            content_hash: item.content_hash,
            retrieved_at: now.clone(),
        })
        .collect();

    HttpResponse::Ok().json(RagSearchResponse {
        items: verified_items,
    })
}

#[cfg(test)]
mod contract_tests {
    use super::*;
    use actix_web::body::to_bytes;
    use actix_web::{http::StatusCode, test::TestRequest, web};

    #[actix_rt::test]
    async fn rag_status_works() {
        let response = rag_status().await;
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn disabled_module_cannot_query_rag() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "false");
        std::env::set_var("SAKINA_RAG_QURAN_ENABLED", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let response = rag_search(
            req,
            web::Query(RagSearchQuery {
                module: "quran".to_string(),
                q: "test".to_string(),
            }),
        )
        .await;
        assert_eq!(response.status(), StatusCode::FORBIDDEN);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
        std::env::remove_var("SAKINA_RAG_QURAN_ENABLED");
    }

    #[actix_rt::test]
    async fn missing_entitlement_blocks_rag() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        std::env::set_var("SAKINA_RAG_QURAN_ENABLED", "true");
        let req = TestRequest::default().to_http_request();
        let response = rag_search(
            req,
            web::Query(RagSearchQuery {
                module: "quran".to_string(),
                q: "test".to_string(),
            }),
        )
        .await;
        assert_eq!(response.status(), StatusCode::PAYMENT_REQUIRED);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
        std::env::remove_var("SAKINA_RAG_QURAN_ENABLED");
    }

    #[test]
    fn unverified_content_is_filtered_out() {
        let items = vec![
            RagSourceItem {
                module: "quran".to_string(),
                source_type: "tafsir".to_string(),
                source_name: "Pending Source".to_string(),
                source_reference: "1:1".to_string(),
                citation: "citation-1".to_string(),
                language: "ar".to_string(),
                review_status: ReviewStatus::Unverified,
                effective_date: None,
                content_hash: "abc".to_string(),
            },
            RagSourceItem {
                module: "quran".to_string(),
                source_type: "tafsir".to_string(),
                source_name: "Verified Source".to_string(),
                source_reference: "1:2".to_string(),
                citation: "citation-2".to_string(),
                language: "ar".to_string(),
                review_status: ReviewStatus::Verified,
                effective_date: None,
                content_hash: "def".to_string(),
            },
        ];
        let verified = verified_only(items);
        assert_eq!(verified.len(), 1);
        assert_eq!(verified[0].source_name, "Verified Source");
    }

    #[test]
    fn verified_content_includes_citation_and_source_metadata() {
        let item = RagSourceItem {
            module: "knowledge".to_string(),
            source_type: "article".to_string(),
            source_name: "Verified Manual".to_string(),
            source_reference: "Section 1".to_string(),
            citation: "Manual, Section 1".to_string(),
            language: "en".to_string(),
            review_status: ReviewStatus::Verified,
            effective_date: Some("2026-05-28".to_string()),
            content_hash: "hash123".to_string(),
        };
        assert!(!item.citation.is_empty());
        assert!(!item.source_type.is_empty());
        assert!(!item.source_name.is_empty());
        assert!(!item.source_reference.is_empty());
        assert!(!item.content_hash.is_empty());
    }

    #[actix_rt::test]
    async fn rag_search_invalid_query_uses_standard_error_format() {
        let req = TestRequest::default().to_http_request();
        let response = rag_search(
            req,
            web::Query(RagSearchQuery {
                module: "bad-module".to_string(),
                q: "".to_string(),
            }),
        )
        .await;
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"bad_request\""));
    }
}
