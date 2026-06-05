use crate::error::ApiError;
use crate::models::{ClassifyRequest, ClassifyResponse};
use crate::services::AiaOrchestrator;
use actix_web::{web, HttpResponse};

pub async fn classify_intent(
    req: web::Json<ClassifyRequest>,
    aia: web::Data<AiaOrchestrator>,
) -> Result<HttpResponse, ApiError> {
    let result = aia.classify(&req.text).await?;
    Ok(HttpResponse::Ok().json(ClassifyResponse {
        intent: format!("{:?}", result.intent),
        confidence: result.confidence,
        routing_decision: result.routing_decision,
    }))
}
