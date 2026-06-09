use crate::error::ApiError;
use crate::services::fatwa_verifier::{FatwaVerificationRequest, FatwaVerifierService};
use actix_web::{web, HttpResponse};

pub async fn verify_fatwa(
    service: web::Data<FatwaVerifierService>,
    payload: web::Json<FatwaVerificationRequest>,
) -> Result<HttpResponse, ApiError> {
    let result = service.verify_fatwa(payload.into_inner()).await?;
    Ok(HttpResponse::Ok().json(result))
}
