use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::middleware::rate_limit::enforce_rate_limit;

#[derive(Debug, Deserialize)]
pub struct BackupUploadRequest {
    pub data: String,
}

pub async fn upload_backup(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    user_id: web::Path<Uuid>,
    body: web::Json<BackupUploadRequest>,
) -> Result<HttpResponse, ApiError> {
    let requested_user_id = user_id.into_inner();
    enforce_rate_limit(&req, "sync_upload", 10, std::time::Duration::from_secs(60))?;
    authorize_user_access(&req, requested_user_id)?;
    if body.data.len() > 256 * 1024 {
        return Err(ApiError::bad_request("backup payload exceeds 256KB limit"));
    }

    let encrypted = body.data.as_bytes();
    let backup_hash = sha256_hex(encrypted);

    sqlx::query(
        "INSERT INTO public.user_backups (user_id, encrypted_blob, backup_hash) \
         VALUES ($1, $2, $3)",
    )
    .bind(requested_user_id)
    .bind(encrypted)
    .bind(&backup_hash)
    .execute(pool.get_ref())
    .await
    .map_err(|e| {
        tracing::error!("upload backup db error: {}", e);
        ApiError::internal("failed to store backup")
    })?;

    Ok(HttpResponse::Ok().json(json!({
        "success": true,
        "backup_hash": backup_hash,
        "sync_timestamp": chrono::Utc::now().to_rfc3339()
    })))
}

pub async fn download_backup(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    user_id: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let requested_user_id = user_id.into_inner();
    enforce_rate_limit(&req, "sync_download", 20, std::time::Duration::from_secs(60))?;
    authorize_user_access(&req, requested_user_id)?;
    let row: Option<(Vec<u8>, String, chrono::NaiveDateTime)> = sqlx::query_as(
        "SELECT encrypted_blob, backup_hash, created_at \
         FROM public.user_backups \
         WHERE user_id = $1 \
         ORDER BY created_at DESC \
         LIMIT 1",
    )
    .bind(requested_user_id)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|e| {
        tracing::error!("download backup db error: {}", e);
        ApiError::internal("failed to load backup")
    })?;

    match row {
        Some((blob, backup_hash, created_at)) => {
            let data = String::from_utf8(blob).map_err(|e| {
                tracing::error!("backup blob decode error: {}", e);
                ApiError::internal("stored backup is unreadable")
            })?;
            Ok(HttpResponse::Ok().json(json!({
                "data": data,
                "backup_hash": backup_hash,
                "sync_timestamp": created_at.and_utc().to_rfc3339()
            })))
        }
        None => Ok(HttpResponse::NotFound().json(json!({
            "error": "backup not found"
        }))),
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    digest.iter().map(|b| format!("{b:02x}")).collect()
}

fn authorize_user_access(req: &HttpRequest, requested_user_id: Uuid) -> Result<(), ApiError> {
    let authenticated_user_id = req
        .extensions()
        .get::<Uuid>()
        .copied()
        .ok_or_else(|| ApiError::unauthorized("missing authenticated user identity"))?;
    if authenticated_user_id != requested_user_id {
        return Err(ApiError::forbidden(
            "requested user_id does not match authenticated identity",
        ));
    }
    Ok(())
}
