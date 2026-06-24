use actix_multipart::Multipart;
use actix_web::{web, HttpRequest, HttpResponse};
use futures_util::TryStreamExt;
use uuid::Uuid;

use crate::error::ApiError;
use crate::models::BrainRouteRequest;
use crate::services::{
    authenticated_user_id, AiaOrchestrator, IslamicAnswerService, MultimodalAnalysisRequest,
    MultimodalService,
};

#[derive(Default)]
struct MultipartUpload {
    asset_type: Option<String>,
    original_name: Option<String>,
    mime_type: Option<String>,
    language: Option<String>,
    file: Vec<u8>,
}

async fn read_text_field(mut field: actix_multipart::Field) -> Result<String, ApiError> {
    let mut bytes = Vec::new();
    while let Some(chunk) = field
        .try_next()
        .await
        .map_err(|_| ApiError::bad_request("failed to read multipart field"))?
    {
        bytes.extend_from_slice(&chunk);
        if bytes.len() > 4096 {
            return Err(ApiError::bad_request("multipart field is too large"));
        }
    }
    String::from_utf8(bytes)
        .map(|value| value.trim().to_string())
        .map_err(|_| ApiError::bad_request("multipart text field must be UTF-8"))
}

async fn parse_multipart(mut payload: Multipart) -> Result<MultipartUpload, ApiError> {
    let mut upload = MultipartUpload::default();
    while let Some(mut field) = payload
        .try_next()
        .await
        .map_err(|_| ApiError::bad_request("invalid multipart upload"))?
    {
        let Some(name) = field.name().map(str::to_string) else {
            continue;
        };
        match name.as_str() {
            "asset_type" => upload.asset_type = Some(read_text_field(field).await?),
            "mime_type" => upload.mime_type = Some(read_text_field(field).await?),
            "language" => upload.language = Some(read_text_field(field).await?),
            "file" => {
                if let Some(filename) = field
                    .content_disposition()
                    .and_then(|value| value.get_filename())
                    .map(str::to_string)
                {
                    upload.original_name = Some(filename);
                }
                while let Some(chunk) = field
                    .try_next()
                    .await
                    .map_err(|_| ApiError::bad_request("failed to read uploaded file"))?
                {
                    upload.file.extend_from_slice(&chunk);
                    if upload.file.len() > 10 * 1024 * 1024 {
                        return Err(ApiError::bad_request("uploaded file is too large"));
                    }
                }
            }
            _ => {
                let _ = read_text_field(field).await?;
            }
        }
    }
    Ok(upload)
}

pub async fn analyze(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    islamic_service: web::Data<IslamicAnswerService>,
    service: web::Data<MultimodalService>,
    payload: Multipart,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, service.pool()).await?;
    let trace_id = req
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    let upload = parse_multipart(payload).await?;
    let asset_type = upload
        .asset_type
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError::bad_request("asset_type multipart field is required"))?;
    let mime_type = upload
        .mime_type
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError::bad_request("mime_type multipart field is required"))?;
    let original_name = upload
        .original_name
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "upload.bin".to_string());
    let language = upload
        .language
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "en".to_string());

    let route = aia.route(&BrainRouteRequest {
        message: format!("multimodal {asset_type} {mime_type} {original_name}"),
        language: Some(language.clone()),
        user_subscription_tier: "premium".to_string(),
        safety_context: Some(serde_json::json!({
            "operation": "multimodal_analyze",
            "asset_type": asset_type,
            "mime_type": mime_type,
            "request_id": trace_id
        })),
        request_id: Some(trace_id.clone()),
    });
    if !route.can_generate {
        return Err(ApiError::unauthorized(
            "multimodal analysis not permitted by Mother Brain",
        ));
    }

    let result = service
        .analyze(
            MultimodalAnalysisRequest {
                user_id,
                asset_type,
                original_name,
                mime_type,
                content: upload.file,
                language,
                request_id: trace_id.clone(),
            },
            &aia,
            &islamic_service,
        )
        .await?;
    Ok(HttpResponse::Ok()
        .insert_header(("x-request-id", trace_id))
        .json(result))
}

pub async fn get_asset(
    req: HttpRequest,
    service: web::Data<MultimodalService>,
    asset_id: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, service.pool()).await?;
    match service.get_asset(user_id, asset_id.into_inner()).await? {
        Some(asset) => Ok(HttpResponse::Ok().json(asset)),
        None => Ok(HttpResponse::NotFound().json(serde_json::json!({
            "found": false
        }))),
    }
}

pub async fn delete_asset(
    req: HttpRequest,
    service: web::Data<MultimodalService>,
    asset_id: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, service.pool()).await?;
    let deleted = service.delete_asset(user_id, asset_id.into_inner()).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "deleted": deleted
    })))
}
