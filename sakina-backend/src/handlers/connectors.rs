use actix_web::{web, HttpRequest, HttpResponse};

use crate::error::ApiError;
use crate::services::{authenticated_user_id, McpConnectorRegistry};

pub async fn status(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    registry: web::Data<McpConnectorRegistry>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "user_id": user_id,
        "enabled": registry.enabled(),
        "brain_approval_required": true,
        "connectors": registry.connectors(),
    })))
}
