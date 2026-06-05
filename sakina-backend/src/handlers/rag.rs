use actix_web::{web, HttpRequest, HttpResponse};
use sqlx::Row;
use std::sync::Arc;
use std::time::Instant;

use crate::error::ApiError;
use crate::models::{
    BrainRouteRequest, DecisionRequest, DecisionResponse, RagSearchItem, RagSearchResponse,
    RagSourceItem, RagSourcesResponse, RagStatusResponse, ReviewStatus,
};
use crate::models::{RagQuery, RagResponse, SourceReference};
use crate::services::{
    AiaOrchestrator, EmbeddingsService, Guardrails, HybridRagService, QdrantVectorDB,
};

fn payload_text(payload: Option<&serde_json::Value>, key: &str) -> Option<String> {
    payload
        .and_then(|value| value.get(key))
        .and_then(|value| value.as_str())
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn source_from_payload(
    hit: &crate::services::qdrant_client::ScoredPoint,
) -> Option<SourceReference> {
    let payload = hit.payload.as_ref();
    let source_id = payload_text(payload, "source_id")
        .or_else(|| payload_text(payload, "chunk_id"))
        .or_else(|| hit.id.as_i64().map(|id| id.to_string()))
        .or_else(|| hit.id.as_str().map(|id| id.to_string()))?;
    Some(SourceReference {
        id: source_id,
        title: payload_text(payload, "title")
            .or_else(|| payload_text(payload, "source_name"))
            .unwrap_or_default(),
        author: payload_text(payload, "author")
            .or_else(|| payload_text(payload, "source_author"))
            .unwrap_or_default(),
        chapter: payload_text(payload, "chapter")
            .or_else(|| payload_text(payload, "source_reference"))
            .unwrap_or_default(),
        authenticity_grade: payload_text(payload, "authenticity_grade")
            .or_else(|| payload_text(payload, "review_status"))
            .unwrap_or_default(),
    })
}

/// Real RAG pipeline (Step 18): classify -> embed -> guardrail -> Qdrant search.
///
/// Structured for production but NOT runtime-tested here: it needs a live vLLM
/// (embeddings), a live Qdrant with indexed chunks, and a populated Postgres.
/// This endpoint is evidence-only: it does not generate answer text.
#[tracing::instrument(skip_all)]
pub async fn query_rag(
    aia: web::Data<AiaOrchestrator>,
    guardrails: web::Data<Arc<Guardrails>>,
    qdrant: web::Data<QdrantVectorDB>,
    embeddings: web::Data<EmbeddingsService>,
    query: web::Json<RagQuery>,
) -> Result<HttpResponse, ApiError> {
    let start = Instant::now();

    // 1. Classify intent (routing decision; not yet branched on).
    let _trace = aia.route(&BrainRouteRequest {
        message: query.query.clone(),
        language: None,
        user_subscription_tier: "premium".to_string(),
        safety_context: None,
        request_id: None,
    });

    // 2. Embed the query (vLLM).
    let embedding = embeddings.embed(&query.query).await?;

    // 3. Vector search for supporting chunks.
    let hits = qdrant.search(&embedding, 0.0, 5).await?;
    if hits.is_empty() {
        return Ok(HttpResponse::Ok().json(RagResponse {
            answer: String::new(),
            sources: vec![],
            confidence: 0.0,
            guardrail_triggered: true,
            processing_time_ms: start.elapsed().as_millis() as u64,
        }));
    }

    // 4. Guardrail check on the strongest verified retrieval score.
    let top_similarity = hits.iter().map(|point| point.score).fold(0.0_f32, f32::max);
    let guard = guardrails.evaluate_score(top_similarity);
    if !guard.passed {
        return Ok(HttpResponse::Ok().json(RagResponse {
            answer: String::new(),
            sources: vec![],
            confidence: guard.confidence,
            guardrail_triggered: true,
            processing_time_ms: start.elapsed().as_millis() as u64,
        }));
    }

    // 5. Build evidence references only from returned retrieval metadata.
    let sources: Vec<SourceReference> = hits.iter().filter_map(source_from_payload).collect();
    let confidence = guard.confidence.min(top_similarity);

    Ok(HttpResponse::Ok().json(RagResponse {
        answer: String::new(),
        sources,
        confidence,
        guardrail_triggered: false,
        processing_time_ms: start.elapsed().as_millis() as u64,
    }))
}

#[derive(Debug, serde::Deserialize)]
pub struct ApiRagSearchRequest {
    pub query: String,
    pub language: Option<String>,
}

pub async fn api_rag_search(
    aia: web::Data<AiaOrchestrator>,
    hybrid: web::Data<HybridRagService>,
    payload: web::Json<ApiRagSearchRequest>,
) -> Result<HttpResponse, ApiError> {
    let request = payload.into_inner();
    let route = aia.route(&BrainRouteRequest {
        message: request.query.clone(),
        language: request.language.clone(),
        user_subscription_tier: "premium".to_string(),
        safety_context: None,
        request_id: None,
    });
    let result = hybrid
        .search(&request.query, request.language.as_deref(), 5)
        .await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "selected_agent": route.selected_agent,
        "selected_model": route.selected_model,
        "selected_pipeline": route.selected_pipeline,
        "retrieval_strategy": result.retrieval_strategy,
        "retrieved_chunks": result.retrieved_chunks,
        "source_ranking": result.source_ranking,
        "citations": result.citations,
        "graph_path": result.graph_path,
        "compressed_tokens_before": result.compressed_tokens_before,
        "compressed_tokens_after": result.compressed_tokens_after,
        "compression_ratio": result.compression_ratio,
        "weak_evidence_blocked": result.weak_evidence_blocked,
    })))
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

async fn approved_sources_from_db(
    pool: &sqlx::PgPool,
    module: &str,
) -> Result<Vec<RagSourceItem>, ApiError> {
    let rows = sqlx::query(
        r#"
        SELECT
            s.source_type,
            s.title AS source_name,
            COALESCE(c.chunk_key, d.document_key, s.source_key) AS source_reference,
            c.citation_text AS citation,
            COALESCE(c.language, d.language, s.language) AS language,
            d.approved_at::text AS effective_date,
            md5(c.chunk_text) AS content_hash
        FROM sakina_ai.islamic_sources s
        JOIN sakina_ai.islamic_documents d ON d.source_id = s.id
        JOIN sakina_ai.islamic_chunks c ON c.document_id = d.id
        WHERE s.source_status = 'approved'
          AND s.review_status IN ('verified', 'approved')
          AND d.source_status = 'approved'
          AND d.review_status IN ('verified', 'approved')
          AND c.source_status = 'approved'
          AND c.review_status IN ('verified', 'approved')
          AND s.source_type = $1
        ORDER BY s.created_at DESC, d.created_at DESC, c.chunk_index ASC
        LIMIT 50
        "#,
    )
    .bind(module)
    .fetch_all(pool)
    .await
    .map_err(|_| ApiError::internal("failed to load approved rag sources"))?;

    Ok(rows
        .into_iter()
        .map(|row| RagSourceItem {
            module: module.to_string(),
            source_type: row.get("source_type"),
            source_name: row.get("source_name"),
            source_reference: row.get("source_reference"),
            citation: row.get("citation"),
            language: row.get("language"),
            review_status: ReviewStatus::Verified,
            effective_date: row.get("effective_date"),
            content_hash: row.get("content_hash"),
        })
        .collect())
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

pub async fn rag_decide(
    payload: web::Json<DecisionRequest>,
    aia: web::Data<AiaOrchestrator>,
) -> HttpResponse {
    let request = payload.into_inner();
    let response: DecisionResponse = aia.decide(&request);
    HttpResponse::Ok().json(response)
}

pub async fn rag_sources(pool: web::Data<sqlx::PgPool>, req: HttpRequest) -> HttpResponse {
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

    match approved_sources_from_db(pool.get_ref(), &module).await {
        Ok(sources) => HttpResponse::Ok().json(RagSourcesResponse { sources }),
        Err(err) => crate::error::error_response(err.status, err.code, err.message),
    }
}

pub async fn rag_search(
    pool: web::Data<sqlx::PgPool>,
    req: HttpRequest,
    query: web::Query<RagSearchQuery>,
) -> HttpResponse {
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
    match approved_sources_from_db(pool.get_ref(), &module).await {
        Ok(items) => {
            let verified_items = items
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
        Err(err) => crate::error::error_response(err.status, err.code, err.message),
    }
}

#[cfg(test)]
#[allow(clippy::await_holding_lock)]
mod contract_tests {
    use super::*;
    use actix_web::body::to_bytes;
    use actix_web::{http::StatusCode, test::TestRequest, web, App};
    use std::sync::Arc;

    fn aia_data() -> web::Data<AiaOrchestrator> {
        web::Data::new(AiaOrchestrator::new(Arc::new(
            crate::services::SemanticRouter::new(),
        )))
    }

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
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let response = rag_search(
            web::Data::new(pool),
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
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let req = TestRequest::default().to_http_request();
        let response = rag_search(
            web::Data::new(pool),
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
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let req = TestRequest::default().to_http_request();
        let response = rag_search(
            web::Data::new(pool),
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

    #[actix_rt::test]
    async fn rag_decide_accepts_object_safety_context() {
        let app = actix_web::test::init_service(
            App::new()
                .app_data(aia_data())
                .route("/v1/rag/decide", web::post().to(rag_decide)),
        )
        .await;
        let req = TestRequest::post()
            .uri("/v1/rag/decide")
            .set_json(serde_json::json!({
                "question": "What does Islam say about prayer?",
                "selected_module": "quran",
                "language": "en",
                "user_subscription_tier": "free",
                "safety_context": {}
            }))
            .to_request();
        let response = actix_web::test::call_service(&app, req).await;
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn rag_decide_accepts_string_safety_context() {
        let app = actix_web::test::init_service(
            App::new()
                .app_data(aia_data())
                .route("/v1/rag/decide", web::post().to(rag_decide)),
        )
        .await;
        let req = TestRequest::post()
            .uri("/v1/rag/decide")
            .set_json(serde_json::json!({
                "question": "What does Islam say about prayer?",
                "selected_module": "quran",
                "language": "en",
                "user_subscription_tier": "free",
                "safety_context": ""
            }))
            .to_request();
        let response = actix_web::test::call_service(&app, req).await;
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn rag_decide_accepts_null_safety_context() {
        let app = actix_web::test::init_service(
            App::new()
                .app_data(aia_data())
                .route("/v1/rag/decide", web::post().to(rag_decide)),
        )
        .await;
        let req = TestRequest::post()
            .uri("/v1/rag/decide")
            .set_json(serde_json::json!({
                "question": "What does Islam say about prayer?",
                "selected_module": "quran",
                "language": "en",
                "user_subscription_tier": "free",
                "safety_context": null
            }))
            .to_request();
        let response = actix_web::test::call_service(&app, req).await;
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn rag_decide_accepts_omitted_safety_context() {
        let app = actix_web::test::init_service(
            App::new()
                .app_data(aia_data())
                .route("/v1/rag/decide", web::post().to(rag_decide)),
        )
        .await;
        let req = TestRequest::post()
            .uri("/v1/rag/decide")
            .set_json(serde_json::json!({
                "question": "What does Islam say about prayer?",
                "selected_module": "quran",
                "language": "en",
                "user_subscription_tier": "free"
            }))
            .to_request();
        let response = actix_web::test::call_service(&app, req).await;
        assert_eq!(response.status(), StatusCode::OK);
    }
}
