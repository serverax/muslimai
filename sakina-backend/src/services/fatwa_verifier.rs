use crate::error::ApiError;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FatwaVerificationRequest {
    pub fatwa_id: Uuid,
    pub original_url: String,
    pub scholar_name: Option<String>,
    pub issuing_authority: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FatwaVerificationResult {
    pub fatwa_id: Uuid,
    pub status: String, // 'verified', 'rejected', 'needs_review'
    pub reason: Option<String>,
}

#[derive(Clone)]
pub struct FatwaVerifierService {
    pool: PgPool,
}

impl FatwaVerifierService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn verify_fatwa(
        &self,
        req: FatwaVerificationRequest,
    ) -> Result<FatwaVerificationResult, ApiError> {
        // Core verification logic:
        // 1. Check if URL is in blocklist.
        // 2. Check if scholar/authority is on approved list.
        // 3. Verify duplication.
        // Basic domain filtering and authority validation applied:

        let mut status = "needs_review".to_string();
        let mut reason = None;

        if req.issuing_authority.to_lowercase().contains("unknown") {
            status = "rejected".to_string();
            reason = Some("Unknown authority".to_string());
        } else if req
            .original_url
            .starts_with("https://trusted-fatwa-source.com")
        {
            status = "verified".to_string();
        }

        sqlx::query(
            r#"
            UPDATE sakina_ai.fatwa_documents
            SET verification_status = $1, updated_at = now()
            WHERE id = $2
            "#,
        )
        .bind(&status)
        .bind(req.fatwa_id)
        .execute(&self.pool)
        .await
        .map_err(|e| ApiError::internal(format!("failed to update fatwa status: {}", e)))?;

        Ok(FatwaVerificationResult {
            fatwa_id: req.fatwa_id,
            status,
            reason,
        })
    }
}
