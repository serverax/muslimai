use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use sqlx::{PgPool, Row};

use crate::error::ApiError;
use crate::services::authenticated_user_id;

#[derive(Debug, Deserialize)]
pub struct AgentFeedbackRequest {
    pub trace_id: String,
    pub rating: bool,
}

pub async fn submit_feedback(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<AgentFeedbackRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let request = body.into_inner();
    let trace_id = request.trace_id.trim();
    if trace_id.is_empty() {
        return Err(ApiError::bad_request("trace_id is required"));
    }

    let trace = sqlx::query(
        r#"
        SELECT request_id, user_id, execution_trace
        FROM sakina_ai.brain_decision_traces
        WHERE request_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(trace_id)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load agent trace"))?;

    let Some(trace) = trace else {
        return Err(ApiError::not_found("trace not found"));
    };

    let trace_user_id: Option<String> = trace.get("user_id");
    if trace_user_id.as_deref() != Some(&user_id.to_string()) {
        return Err(ApiError::unauthorized(
            "trace does not belong to authenticated user",
        ));
    }

    let label = if request.rating {
        "positive"
    } else {
        "negative"
    };
    let reasoning_trace: serde_json::Value = trace.get("execution_trace");
    let feedback_id: uuid::Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO sakina_ai.agent_feedback (trace_id, user_id, rating, label, reasoning_trace)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id
        "#,
    )
    .bind(trace_id)
    .bind(user_id)
    .bind(request.rating)
    .bind(label)
    .bind(reasoning_trace)
    .fetch_one(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to persist agent feedback"))?;

    Ok(HttpResponse::Created().json(serde_json::json!({
        "feedback_id": feedback_id,
        "trace_id": trace_id,
        "label": label
    })))
}
