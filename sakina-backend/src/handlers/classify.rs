use actix_web::{web, HttpRequest, HttpResponse};
use std::sync::Arc;
use std::time::Duration;

use crate::error::ApiError;
use crate::middleware::rate_limit::enforce_rate_limit;
use crate::models::{ClassifyRequest, ClassifyResponse};
use crate::services::SemanticRouter;

pub async fn classify_intent(
    request: HttpRequest,
    body: web::Json<ClassifyRequest>,
    router: web::Data<Arc<SemanticRouter>>,
) -> Result<HttpResponse, ApiError> {
    enforce_rate_limit(&request, "classify", 30, Duration::from_secs(60))?;
    let result = router.classify(&body.text).await.map_err(ApiError::from)?;
    Ok(HttpResponse::Ok().json(ClassifyResponse {
        intent: format!("{:?}", result.intent),
        confidence: result.confidence,
        routing_decision: result.routing_decision,
    }))
}
