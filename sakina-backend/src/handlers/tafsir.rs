use actix_web::{web, HttpResponse};
use crate::error::ApiError;
use crate::services::tafsir_ingestion::{TafsirIngestionService, TafsirIngestionRequest};
use uuid::Uuid;

pub async fn start_tafsir_job(
    service: web::Data<TafsirIngestionService>,
    source_id: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let job_id = service.start_ingestion_job(source_id.into_inner()).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "job_id": job_id,
        "status": "started"
    })))
}

pub async fn ingest_tafsir_entry(
    service: web::Data<TafsirIngestionService>,
    source_id: web::Path<Uuid>,
    payload: web::Json<TafsirIngestionRequest>,
) -> Result<HttpResponse, ApiError> {
    let entry_id = service.ingest_entry(payload.into_inner(), source_id.into_inner()).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "entry_id": entry_id,
        "status": "ingested"
    })))
}
