use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

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
    if !authorize_user_access(&req, requested_user_id) {
        return Ok(HttpResponse::Unauthorized().json(json!({
            "error": "requested user_id does not match x-sakina-user-id header"
        })));
    }
    if body.data.len() > 256 * 1024 {
        return Ok(HttpResponse::BadRequest().json(json!({
            "error": "backup payload exceeds 256KB limit"
        })));
    }

    let encrypted = body.data.as_bytes();
    let backup_hash = checksum_hex(encrypted);

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
        ApiError("failed to store backup".to_string())
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
    if !authorize_user_access(&req, requested_user_id) {
        return Ok(HttpResponse::Unauthorized().json(json!({
            "error": "requested user_id does not match x-sakina-user-id header"
        })));
    }
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
        ApiError("failed to load backup".to_string())
    })?;

    match row {
        Some((blob, backup_hash, created_at)) => {
            let data = String::from_utf8(blob).map_err(|e| {
                tracing::error!("backup blob decode error: {}", e);
                ApiError("stored backup is unreadable".to_string())
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

fn checksum_hex(bytes: &[u8]) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let mut hasher = DefaultHasher::new();
    bytes.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

fn authorize_user_access(req: &HttpRequest, requested_user_id: Uuid) -> bool {
    req.headers()
        .get("x-sakina-user-id")
        .and_then(|h| h.to_str().ok())
        .and_then(|s| Uuid::parse_str(s).ok())
        .map(|header_user_id| header_user_id == requested_user_id)
        .unwrap_or(false)
}
