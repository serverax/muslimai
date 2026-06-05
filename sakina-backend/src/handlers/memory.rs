use actix_web::{web, HttpRequest, HttpResponse};

use crate::error::ApiError;
use crate::models::BrainRouteRequest;
use crate::services::authenticated_user_id;
use crate::services::{AiaOrchestrator, MemoryEngine, MemoryWriteRequest};
use uuid::Uuid;

#[derive(Debug, serde::Deserialize)]
pub struct MemoryReadQuery {
    pub user_id: Uuid,
    pub memory_key: String,
}

pub async fn write(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    engine: web::Data<MemoryEngine>,
    payload: web::Json<MemoryWriteRequest>,
) -> Result<HttpResponse, ApiError> {
    let request = payload.into_inner();
    let auth_user_id = authenticated_user_id(&req, engine.pool()).await?;
    if auth_user_id != request.user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    let route = aia.route(&BrainRouteRequest {
        message: format!("memory write {} {}", request.memory_type, request.payload),
        language: Some(request.source_language.clone()),
        user_subscription_tier: "premium".to_string(),
        safety_context: Some(serde_json::json!({ "operation": "memory_write" })),
        request_id: None,
    });
    if !route.can_generate {
        return Err(ApiError::unauthorized(
            "memory write not permitted by Mother Brain",
        ));
    }
    let outcome = engine.write(request).await?;
    Ok(HttpResponse::Ok().json(outcome))
}

pub async fn read(
    req: HttpRequest,
    engine: web::Data<MemoryEngine>,
    query: web::Query<MemoryReadQuery>,
) -> Result<HttpResponse, ApiError> {
    let auth_user_id = authenticated_user_id(&req, engine.pool()).await?;
    if auth_user_id != query.user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    match engine.read(query.user_id, query.memory_key.trim()).await? {
        Some(entry) => Ok(HttpResponse::Ok().json(entry)),
        None => Ok(HttpResponse::NotFound().json(serde_json::json!({
            "found": false
        }))),
    }
}

pub async fn delete(
    req: HttpRequest,
    engine: web::Data<MemoryEngine>,
    query: web::Query<MemoryReadQuery>,
) -> Result<HttpResponse, ApiError> {
    let auth_user_id = authenticated_user_id(&req, engine.pool()).await?;
    if auth_user_id != query.user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    let deleted = engine
        .delete(query.user_id, query.memory_key.trim())
        .await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "deleted": deleted
    })))
}
