use actix_web::{web, HttpRequest, HttpResponse};
use sqlx::Row;

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

pub async fn list(
    req: HttpRequest,
    engine: web::Data<MemoryEngine>,
) -> Result<HttpResponse, ApiError> {
    let auth_user_id = authenticated_user_id(&req, engine.pool()).await?;
    let rows = sqlx::query(
        r#"
        SELECT id, user_id, workspace_id, memory_key, memory_type, sensitivity_level,
               source_language, consent_required, consent_granted, allowed,
               created_at::text AS created_at
        FROM sakina_ai.user_memory_entries
        WHERE user_id = $1
          AND deleted_at IS NULL
        ORDER BY created_at DESC
        LIMIT 50
        "#,
    )
    .bind(auth_user_id)
    .fetch_all(engine.pool())
    .await
    .map_err(|_| ApiError::internal("failed to list memories"))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "user_id": auth_user_id,
        "memories": rows.into_iter().map(|row| serde_json::json!({
            "id": row.get::<Uuid, _>("id"),
            "workspace_id": row.get::<Option<Uuid>, _>("workspace_id"),
            "memory_key": row.get::<String, _>("memory_key"),
            "memory_type": row.get::<String, _>("memory_type"),
            "sensitivity_level": row.get::<String, _>("sensitivity_level"),
            "source_language": row.get::<String, _>("source_language"),
            "consent_required": row.get::<bool, _>("consent_required"),
            "consent_granted": row.get::<bool, _>("consent_granted"),
            "allowed": row.get::<bool, _>("allowed"),
            "created_at": row.get::<String, _>("created_at"),
        })).collect::<Vec<_>>()
    })))
}

pub async fn list_workspace(
    req: HttpRequest,
    engine: web::Data<MemoryEngine>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let auth_user_id = authenticated_user_id(&req, engine.pool()).await?;
    let workspace_id = path.into_inner();
    let owner = sqlx::query_scalar::<_, Option<Uuid>>(
        "SELECT user_id FROM sakina_ai.workspaces WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(workspace_id)
    .fetch_optional(engine.pool())
    .await
    .map_err(|_| ApiError::internal("failed to load workspace"))?
    .flatten();
    if owner != Some(auth_user_id) {
        return Err(ApiError::not_found("workspace memory not found"));
    }
    let rows = sqlx::query(
        r#"
        SELECT id, memory_key, memory_type, sensitivity_level, created_at::text AS created_at
        FROM sakina_ai.user_memory_entries
        WHERE user_id = $1
          AND workspace_id = $2
          AND deleted_at IS NULL
        ORDER BY created_at DESC
        LIMIT 50
        "#,
    )
    .bind(auth_user_id)
    .bind(workspace_id)
    .fetch_all(engine.pool())
    .await
    .map_err(|_| ApiError::internal("failed to list workspace memories"))?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "workspace_id": workspace_id,
        "memories": rows.into_iter().map(|row| serde_json::json!({
            "id": row.get::<Uuid, _>("id"),
            "memory_key": row.get::<String, _>("memory_key"),
            "memory_type": row.get::<String, _>("memory_type"),
            "sensitivity_level": row.get::<String, _>("sensitivity_level"),
            "created_at": row.get::<String, _>("created_at"),
        })).collect::<Vec<_>>()
    })))
}
