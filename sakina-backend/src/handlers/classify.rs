use actix_web::{web, HttpResponse};
use std::sync::Arc;

use crate::error::ApiError;
use crate::models::{ClassifyRequest, ClassifyResponse};
use crate::services::SemanticRouter;

pub async fn classify_intent(
    req: web::Json<ClassifyRequest>,
    router: web::Data<Arc<SemanticRouter>>,
) -> Result<HttpResponse, ApiError> {
    let result = router.classify(&req.text).await?;
    Ok(HttpResponse::Ok().json(ClassifyResponse {
        intent: format!("{:?}", result.intent),
        confidence: result.confidence,
        routing_decision: result.routing_decision,
    }))
}
