use base64::{engine::general_purpose::STANDARD, Engine as _};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row};
use std::path::PathBuf;
use tokio::fs;
use tokio::process::Command;
use tokio::time::Duration;
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::pii_redaction;
use crate::services::{AiaOrchestrator, AskIslamicRequest, IslamicAnswerService};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MultimodalAnalysisRequest {
    pub user_id: Uuid,
    pub asset_type: String,
    pub original_name: String,
    pub mime_type: String,
    pub content: Vec<u8>,
    pub language: String,
    pub request_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MultimodalAnalysisResult {
    pub asset_id: Option<Uuid>,
    pub trace_id: String,
    pub status: String,
    pub extracted_text: String,
    pub redacted_text: String,
    pub provider: String,
    pub safety_level: String,
    pub workspace_scope: String,
    pub islamic_answer: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MultimodalAssetRecord {
    pub id: Uuid,
    pub user_id: Uuid,
    pub asset_type: String,
    pub original_name: String,
    pub storage_scope: String,
    pub redacted_text: String,
    pub extracted_text: String,
    pub safety_level: String,
    pub status: String,
    pub metadata: serde_json::Value,
}

#[derive(Debug, Clone)]
pub struct MultimodalService {
    pool: PgPool,
}

impl MultimodalService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }

    fn storage_root() -> PathBuf {
        std::env::var("SAKINA_MULTIMODAL_STORAGE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/tmp/sakina-private-multimodal"))
    }

    fn max_bytes() -> usize {
        std::env::var("SAKINA_MULTIMODAL_MAX_BYTES")
            .ok()
            .and_then(|value| value.parse::<usize>().ok())
            .unwrap_or(5 * 1024 * 1024)
    }

    pub fn redact_text(input: &str) -> String {
        pii_redaction::redact_pii(input).redacted_text
    }

    fn validate_media(asset_type: &str, mime_type: &str, content: &[u8]) -> Result<(), ApiError> {
        if content.is_empty() {
            return Err(ApiError::bad_request("multimodal file content is required"));
        }
        if content.len() > Self::max_bytes() {
            return Err(ApiError::bad_request(
                "multimodal payload exceeds configured size limit",
            ));
        }
        match (asset_type, mime_type) {
            ("image", "image/png") if content.starts_with(b"\x89PNG\r\n\x1a\n") => Ok(()),
            ("image", "image/jpeg") if content.starts_with(b"\xff\xd8\xff") => Ok(()),
            ("document", "text/plain") => Ok(()),
            ("document", "application/pdf") if content.starts_with(b"%PDF-") => Ok(()),
            ("audio", "audio/mpeg") | ("audio", "audio/wav") | ("audio", "audio/mp4") => {
                Err(ApiError::service_unavailable(
                    "speech-to-text provider is not configured for audio uploads",
                ))
            }
            _ => Err(ApiError::bad_request(
                "unsupported or mismatched multimodal file type",
            )),
        }
    }

    async fn persist_private_file(
        user_id: Uuid,
        original_name: &str,
        content: &[u8],
    ) -> Result<(String, String), ApiError> {
        let user_dir = Self::storage_root().join(user_id.to_string());
        fs::create_dir_all(&user_dir)
            .await
            .map_err(|_| ApiError::internal("failed to create private upload directory"))?;
        let mut safe_name = sanitize_filename::sanitize(original_name)
            .chars()
            .take(96)
            .collect::<String>();
        if safe_name.trim().is_empty() {
            safe_name = "upload.bin".to_string();
        }
        let mut hasher = Sha256::new();
        hasher.update(content);
        let sha256 = format!("{:x}", hasher.finalize());
        let path = user_dir.join(format!("{sha256}-{safe_name}"));
        fs::write(&path, content)
            .await
            .map_err(|_| ApiError::internal("failed to persist private upload"))?;
        Ok((path.to_string_lossy().to_string(), sha256))
    }

    async fn provider_extract_text(
        request: &MultimodalAnalysisRequest,
    ) -> Result<(String, String), ApiError> {
        if request.mime_type == "text/plain" {
            let text = String::from_utf8(request.content.clone())
                .map_err(|_| ApiError::bad_request("text upload must be valid UTF-8"))?;
            let text = text.trim().chars().take(6000).collect::<String>();
            if text.is_empty() {
                return Err(ApiError::bad_request("text upload is empty"));
            }
            return Ok((text, "local_text_extractor".to_string()));
        }

        let provider = std::env::var("SAKINA_MULTIMODAL_PROVIDER")
            .unwrap_or_else(|_| "openai_compatible_vision".to_string());
        if provider == "openai_compatible_vision" {
            return Self::openai_compatible_vision(request).await;
        }
        if provider == "local_tesseract_ocr" {
            return Self::local_tesseract_ocr(request).await;
        }
        Err(ApiError::service_unavailable(format!(
            "unsupported multimodal provider: {provider}"
        )))
    }

    async fn local_tesseract_ocr(
        request: &MultimodalAnalysisRequest,
    ) -> Result<(String, String), ApiError> {
        if request.asset_type != "image" {
            return Err(ApiError::service_unavailable(
                "local_tesseract_ocr supports image uploads only",
            ));
        }
        let extension = match request.mime_type.as_str() {
            "image/png" => "png",
            "image/jpeg" => "jpg",
            _ => {
                return Err(ApiError::bad_request(
                    "local_tesseract_ocr requires a PNG or JPEG image",
                ))
            }
        };
        let input_path = std::env::temp_dir().join(format!(
            "sakina-tesseract-{}.{extension}",
            request.request_id
        ));
        fs::write(&input_path, &request.content)
            .await
            .map_err(|_| ApiError::internal("failed to prepare OCR input file"))?;
        let output = Command::new("tesseract")
            .arg(&input_path)
            .arg("stdout")
            .arg("-l")
            .arg("eng")
            .arg("--psm")
            .arg("6")
            .output()
            .await
            .map_err(|err| {
                ApiError::service_unavailable(format!(
                    "local_tesseract_ocr runtime is unavailable: {err}"
                ))
            })?;
        let _ = fs::remove_file(&input_path).await;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr)
                .chars()
                .take(240)
                .collect::<String>();
            return Err(ApiError::service_unavailable(format!(
                "local_tesseract_ocr failed: {stderr}"
            )));
        }
        let text = String::from_utf8(output.stdout)
            .map_err(|_| {
                ApiError::service_unavailable("local_tesseract_ocr returned invalid UTF-8")
            })?
            .trim()
            .chars()
            .take(6000)
            .collect::<String>();
        if text.is_empty() {
            return Err(ApiError::service_unavailable(
                "local_tesseract_ocr returned no recognized text",
            ));
        }
        Ok((text, "local_tesseract_ocr".to_string()))
    }

    async fn openai_compatible_vision(
        request: &MultimodalAnalysisRequest,
    ) -> Result<(String, String), ApiError> {
        let base_url = std::env::var("SAKINA_MULTIMODAL_BASE_URL")
            .or_else(|_| std::env::var("OPENAI_BASE_URL"))
            .unwrap_or_else(|_| "https://api.openai.com".to_string());
        let api_key = std::env::var("SAKINA_MULTIMODAL_API_KEY")
            .or_else(|_| std::env::var("OPENAI_API_KEY"))
            .map_err(|_| {
                ApiError::service_unavailable(
                    "SAKINA_MULTIMODAL_API_KEY or OPENAI_API_KEY is required for live multimodal image/PDF analysis",
                )
            })?;
        let model =
            std::env::var("SAKINA_MULTIMODAL_MODEL").unwrap_or_else(|_| "gpt-4o-mini".to_string());
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(60))
            .build()
            .map_err(|_| ApiError::internal("failed to initialize multimodal provider client"))?;
        let data_url = format!(
            "data:{};base64,{}",
            request.mime_type,
            STANDARD.encode(&request.content)
        );
        let payload = json!({
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": "Extract visible text and describe relevant content from the uploaded image/document. Do not provide religious rulings. Return concise factual observations only."
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Analyze this private Sakina upload for factual text/content to pass into the verified Islamic guidance pipeline."},
                        {"type": "image_url", "image_url": {"url": data_url}}
                    ]
                }
            ],
            "temperature": 0.0,
            "max_tokens": 500
        });
        let response = client
            .post(format!(
                "{}/v1/chat/completions",
                base_url.trim_end_matches('/')
            ))
            .bearer_auth(api_key)
            .json(&payload)
            .send()
            .await
            .map_err(|err| {
                ApiError::service_unavailable(format!("multimodal provider failed: {err}"))
            })?;
        let response = response.error_for_status().map_err(|err| {
            ApiError::service_unavailable(format!("multimodal provider returned error: {err}"))
        })?;
        let body: serde_json::Value = response.json().await.map_err(|_| {
            ApiError::service_unavailable("multimodal provider returned invalid JSON")
        })?;
        let text = body["choices"][0]["message"]["content"]
            .as_str()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .ok_or_else(|| {
                ApiError::service_unavailable("multimodal provider returned no analysis text")
            })?;
        Ok((
            text.chars().take(6000).collect(),
            "openai_compatible_vision".to_string(),
        ))
    }

    pub async fn analyze(
        &self,
        request: MultimodalAnalysisRequest,
        aia: &AiaOrchestrator,
        islamic_service: &IslamicAnswerService,
    ) -> Result<MultimodalAnalysisResult, ApiError> {
        Self::validate_media(&request.asset_type, &request.mime_type, &request.content)?;
        let (private_path, sha256) =
            Self::persist_private_file(request.user_id, &request.original_name, &request.content)
                .await?;
        let (extracted_text, provider) = Self::provider_extract_text(&request).await?;
        let redacted_text = Self::redact_text(&extracted_text);
        let sensitivity_level = if redacted_text.contains("[REDACTED_EMAIL]")
            || redacted_text.contains("[REDACTED_NUMBER]")
        {
            "sensitive"
        } else {
            "safe"
        };
        let islamic_question = format!(
            "The user uploaded a private {} named {}. Provider extracted this factual content: {}. If the extracted content asks for Islamic guidance, answer only using verified Islamic sources and citations; otherwise explain that no Islamic guidance is needed.",
            request.asset_type, request.original_name, redacted_text
        );
        let islamic_answer = aia
            .answer_islamic(
                islamic_service,
                AskIslamicRequest {
                    question: islamic_question,
                    language: Some(request.language.clone()),
                    top_k: Some(5),
                    min_score: Some(0.0),
                    user_id: Some(request.user_id),
                },
            )
            .await?;
        let status = "analyzed";
        let row = sqlx::query(
            r#"
            INSERT INTO sakina_ai.multimodal_assets (
                user_id, asset_type, original_name, storage_scope, redacted_text,
                extracted_text, safety_level, status, metadata
            )
            VALUES ($1, $2, $3, 'user', $4, $5, $6, $7, $8)
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(&request.asset_type)
        .bind(&request.original_name)
        .bind(&redacted_text)
        .bind(&extracted_text)
        .bind(sensitivity_level)
        .bind(status)
        .bind(json!({
            "mime_type": request.mime_type,
            "language": request.language,
            "workspace_scope": "user",
            "redaction_applied": true,
            "provider": provider,
            "private_path": private_path,
            "sha256": sha256,
            "trace_id": request.request_id,
            "citations_count": islamic_answer.get("citations").and_then(|v| v.as_array()).map(|v| v.len()).unwrap_or(0),
            "generated_from_verified_sources": islamic_answer.get("generated_from_verified_sources").cloned().unwrap_or(json!(false)),
            "retrieval_strategy": islamic_answer.get("retrieval_strategy").cloned().unwrap_or(json!(null))
        }))
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to persist multimodal asset"))?;

        Ok(MultimodalAnalysisResult {
            asset_id: Some(row.get("id")),
            trace_id: request.request_id,
            status: status.to_string(),
            extracted_text,
            redacted_text,
            provider,
            safety_level: sensitivity_level.to_string(),
            workspace_scope: "user".to_string(),
            islamic_answer,
        })
    }

    pub async fn get_asset(
        &self,
        user_id: Uuid,
        asset_id: Uuid,
    ) -> Result<Option<MultimodalAssetRecord>, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT id, user_id, asset_type, original_name, storage_scope, redacted_text,
                   extracted_text, safety_level, status, metadata
            FROM sakina_ai.multimodal_assets
            WHERE id = $1 AND user_id = $2
            "#,
        )
        .bind(asset_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load multimodal asset"))?;

        Ok(row.map(|row| MultimodalAssetRecord {
            id: row.get("id"),
            user_id: row.get("user_id"),
            asset_type: row.get("asset_type"),
            original_name: row.get("original_name"),
            storage_scope: row.get("storage_scope"),
            redacted_text: row.get("redacted_text"),
            extracted_text: row.get("extracted_text"),
            safety_level: row.get("safety_level"),
            status: row.get("status"),
            metadata: row.get("metadata"),
        }))
    }

    pub async fn delete_asset(&self, user_id: Uuid, asset_id: Uuid) -> Result<bool, ApiError> {
        let result = sqlx::query(
            r#"
            DELETE FROM sakina_ai.multimodal_assets
            WHERE id = $1 AND user_id = $2
            "#,
        )
        .bind(asset_id)
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to delete multimodal asset"))?;
        Ok(result.rows_affected() > 0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redaction_masks_sensitive_text() {
        let redacted =
            MultimodalService::redact_text("Email me at user@example.com or call 1234567890");
        assert!(redacted.contains("[REDACTED_EMAIL]"));
        assert!(redacted.contains("[REDACTED_NUMBER]"));
    }

    #[test]
    fn rejects_mismatched_media_type() {
        let err = MultimodalService::validate_media("image", "image/png", b"not-png")
            .expect_err("invalid media should fail");
        assert_eq!(err.code, "bad_request");
    }
}
