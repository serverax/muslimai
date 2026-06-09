use crate::error::ApiError;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TafsirIngestionRequest {
    pub source_key: String,
    pub surah_number: i32,
    pub ayah_range_start: i32,
    pub ayah_range_end: i32,
    pub tafsir_text: String,
    pub language: String,
    pub translator: Option<String>,
    pub source_url: Option<String>,
}

#[derive(Clone)]
pub struct TafsirIngestionService {
    pool: PgPool,
}

impl TafsirIngestionService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn start_ingestion_job(&self, source_id: Uuid) -> Result<Uuid, ApiError> {
        let job_id = sqlx::query_scalar::<_, Uuid>(
            r#"
            INSERT INTO sakina_ai.quran_tafsir_ingestion_jobs (source_id, status, started_at)
            VALUES ($1, 'running', now())
            RETURNING id
            "#,
        )
        .bind(source_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| ApiError::internal(format!("failed to start tafsir job: {}", e)))?;

        Ok(job_id)
    }

    pub async fn ingest_entry(
        &self,
        req: TafsirIngestionRequest,
        source_id: Uuid,
    ) -> Result<Uuid, ApiError> {
        let entry_id = sqlx::query_scalar::<_, Uuid>(
            r#"
            INSERT INTO sakina_ai.quran_tafsir_entries 
            (source_id, surah_number, ayah_number, ayah_range_start, ayah_range_end, tafsir_text, language, translator, source_url)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING id
            "#
        )
        .bind(source_id)
        .bind(req.surah_number)
        .bind(req.ayah_range_start)
        .bind(req.ayah_range_start)
        .bind(req.ayah_range_end)
        .bind(&req.tafsir_text)
        .bind(&req.language)
        .bind(&req.translator)
        .bind(&req.source_url)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| ApiError::internal(format!("failed to ingest tafsir entry: {}", e)))?;

        Ok(entry_id)
    }
}
