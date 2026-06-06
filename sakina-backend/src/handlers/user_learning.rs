use actix_web::{web, HttpRequest, HttpResponse};
use sqlx::Row;
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::authenticated_user_id;

async fn ensure_default_workspace(pool: &sqlx::PgPool, user_id: Uuid) -> Result<Uuid, ApiError> {
    sqlx::query_scalar::<_, Uuid>("SELECT sakina_ai.ensure_default_workspace($1)")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|_| ApiError::internal("failed to load user workspace"))
}

pub async fn profile(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let workspace_id = ensure_default_workspace(pool.get_ref(), user_id).await?;
    let preferences = sqlx::query(
        r#"
        SELECT preference_key, preference_value, confidence::text AS confidence, updated_at::text AS updated_at
        FROM sakina_ai.user_learning_preferences
        WHERE user_id = $1
          AND workspace_id = $2
          AND deleted_at IS NULL
        ORDER BY updated_at DESC
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load learning profile"))?
    .into_iter()
    .map(|row| {
        serde_json::json!({
            "key": row.get::<String, _>("preference_key"),
            "value": row.get::<String, _>("preference_value"),
            "confidence": row.get::<String, _>("confidence"),
            "updated_at": row.get::<String, _>("updated_at"),
        })
    })
    .collect::<Vec<_>>();

    let permissions = sqlx::query(
        r#"
        SELECT learning_enabled, local_memory_enabled, server_memory_enabled
        FROM sakina_ai.user_memory_permissions
        WHERE user_id = $1 AND workspace_id = $2
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load learning consent"))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "user_id": user_id,
        "workspace_id": workspace_id,
        "preferences": preferences,
        "consent": permissions.map(|row| serde_json::json!({
            "learning_enabled": row.get::<bool, _>("learning_enabled"),
            "local_memory_enabled": row.get::<bool, _>("local_memory_enabled"),
            "server_memory_enabled": row.get::<bool, _>("server_memory_enabled"),
        })).unwrap_or_else(|| serde_json::json!({})),
    })))
}

#[derive(Debug, serde::Deserialize)]
pub struct LearningConsentRequest {
    pub learning_enabled: bool,
    pub local_memory_enabled: bool,
    pub server_memory_enabled: bool,
}

pub async fn consent(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<LearningConsentRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let workspace_id = ensure_default_workspace(pool.get_ref(), user_id).await?;
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.user_memory_permissions (
            user_id, workspace_id, learning_enabled, local_memory_enabled, server_memory_enabled
        )
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id, workspace_id)
        DO UPDATE SET learning_enabled = EXCLUDED.learning_enabled,
                      local_memory_enabled = EXCLUDED.local_memory_enabled,
                      server_memory_enabled = EXCLUDED.server_memory_enabled,
                      updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .bind(payload.learning_enabled)
    .bind(payload.local_memory_enabled)
    .bind(payload.server_memory_enabled)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to update learning consent"))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "user_id": user_id,
        "workspace_id": workspace_id,
        "learning_enabled": payload.learning_enabled,
        "local_memory_enabled": payload.local_memory_enabled,
        "server_memory_enabled": payload.server_memory_enabled,
    })))
}

pub async fn export(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
) -> Result<HttpResponse, ApiError> {
    profile(req, pool).await
}

pub async fn delete_profile(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let workspace_id = ensure_default_workspace(pool.get_ref(), user_id).await?;
    let deleted = sqlx::query(
        r#"
        UPDATE sakina_ai.user_learning_preferences
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE user_id = $1 AND workspace_id = $2 AND deleted_at IS NULL
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to delete learning profile"))?
    .rows_affected();

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "deleted": deleted,
        "workspace_id": workspace_id,
    })))
}

#[derive(Debug, serde::Deserialize)]
pub struct LearningEventRequest {
    pub signal_type: String,
    pub signal_value: String,
}

pub async fn event(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<LearningEventRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let workspace_id = ensure_default_workspace(pool.get_ref(), user_id).await?;
    let signal_type = payload.signal_type.trim();
    let signal_value = payload.signal_value.trim();
    if signal_type.is_empty() || signal_value.is_empty() {
        return Err(ApiError::bad_request(
            "signal_type and signal_value are required",
        ));
    }
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.user_habit_signals (
            user_id, workspace_id, signal_type, signal_value, confidence
        )
        VALUES ($1, $2, $3, $4, 0.7500)
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .bind(signal_type)
    .bind(signal_value)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to record learning event"))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "stored": true,
        "workspace_id": workspace_id,
    })))
}
