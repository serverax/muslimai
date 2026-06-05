use crate::error::ApiError;
use crate::services::{
    AiaOrchestrator, AskIslamicRequest, IslamicAnswerService, IslamicKnowledgeRepository,
};
use actix_web::{web, HttpResponse};
use uuid::Uuid;

#[derive(Debug, serde::Deserialize)]
pub struct ListingQuery {
    pub limit: Option<i64>,
    pub language: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
pub struct DocumentsQuery {
    pub source_id: Option<Uuid>,
    pub limit: Option<i64>,
    pub language: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
pub struct SearchQuery {
    pub q: String,
    pub limit: Option<i64>,
    pub language: Option<String>,
}

fn sanitize_limit(value: Option<i64>, default_value: i64, max_value: i64) -> i64 {
    value.unwrap_or(default_value).clamp(1, max_value)
}

pub async fn list_sources(
    repo: web::Data<IslamicKnowledgeRepository>,
    query: web::Query<ListingQuery>,
) -> Result<HttpResponse, ApiError> {
    let limit = sanitize_limit(query.limit, 25, 100);
    let items = repo.list_sources(query.language.as_deref(), limit).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "items": items })))
}

pub async fn list_documents(
    repo: web::Data<IslamicKnowledgeRepository>,
    query: web::Query<DocumentsQuery>,
) -> Result<HttpResponse, ApiError> {
    let limit = sanitize_limit(query.limit, 25, 100);
    let items = repo
        .list_documents(query.source_id, query.language.as_deref(), limit)
        .await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "items": items })))
}

pub async fn list_document_chunks(
    repo: web::Data<IslamicKnowledgeRepository>,
    path: web::Path<Uuid>,
    query: web::Query<ListingQuery>,
) -> Result<HttpResponse, ApiError> {
    let limit = sanitize_limit(query.limit, 50, 200);
    let items = repo.list_document_chunks(path.into_inner(), limit).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "items": items })))
}

pub async fn search_local(
    repo: web::Data<IslamicKnowledgeRepository>,
    query: web::Query<SearchQuery>,
) -> Result<HttpResponse, ApiError> {
    if query.q.trim().is_empty() {
        return Err(ApiError::bad_request("q cannot be empty"));
    }
    let limit = sanitize_limit(query.limit, 10, 50);
    let items = repo
        .search_local(query.q.trim(), query.language.as_deref(), limit)
        .await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "items": items })))
}

pub async fn get_citation(
    repo: web::Data<IslamicKnowledgeRepository>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    match repo.get_citation(path.into_inner()).await? {
        Some(item) => Ok(HttpResponse::Ok().json(item)),
        None => Ok(crate::error::error_response(
            actix_web::http::StatusCode::NOT_FOUND,
            "not_found",
            "citation not found",
        )),
    }
}

pub async fn ask(
    aia: web::Data<AiaOrchestrator>,
    service: web::Data<IslamicAnswerService>,
    body: web::Json<AskIslamicRequest>,
) -> Result<HttpResponse, ApiError> {
    let request = body.into_inner();
    let response = aia.answer_islamic(&service, request).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn qdrant_plan(service: web::Data<IslamicAnswerService>) -> HttpResponse {
    HttpResponse::Ok().json(service.qdrant_plan())
}

pub async fn ingestion_scaffolds() -> HttpResponse {
    HttpResponse::Ok().json(serde_json::json!({
        "required_env": ["DATABASE_URL", "QDRANT_URL", "ISLAMIC_QDRANT_COLLECTION", "SAKINA_EMBEDDING_PROVIDER_CONFIG"],
        "recommended_pipeline": ["sync_sources", "normalize_documents", "split_chunks", "generate_embeddings", "upsert_qdrant"],
        "status": "provider_controlled_by_services"
    }))
}
