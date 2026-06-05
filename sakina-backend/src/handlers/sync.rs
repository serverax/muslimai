use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{error_response, ApiError};
use crate::services::authenticated_user_id;

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
    let authenticated_user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    if authenticated_user_id != requested_user_id {
        return Ok(error_response(
            actix_web::http::StatusCode::UNAUTHORIZED,
            "unauthorized",
            "requested user_id does not match authenticated user",
        ));
    }
    if body.data.len() > 256 * 1024 {
        return Ok(error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "backup payload exceeds 256KB limit",
        ));
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
    let authenticated_user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    if authenticated_user_id != requested_user_id {
        return Ok(error_response(
            actix_web::http::StatusCode::UNAUTHORIZED,
            "unauthorized",
            "requested user_id does not match authenticated user",
        ));
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
        None => Ok(error_response(
            actix_web::http::StatusCode::NOT_FOUND,
            "not_found",
            "backup not found",
        )),
    }
}

fn checksum_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let digest = Sha256::digest(bytes);
    format!("{:x}", digest)
}

#[cfg(test)]
mod tests {
    use super::checksum_hex;

    #[test]
    fn checksum_is_deterministic_sha256() {
        let input = b"abc";
        let expected =
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad".to_string();
        assert_eq!(checksum_hex(input), expected);
        assert_eq!(checksum_hex(input), expected);
    }
}
