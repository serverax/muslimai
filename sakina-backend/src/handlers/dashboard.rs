use crate::error::ApiError;
use actix_web::{web, HttpResponse};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow)]
struct GuardrailAuditRow {
    timestamp: chrono::NaiveDateTime,
    payload: Option<Value>,
    user_id: Option<Uuid>,
}

pub async fn get_guardrails(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows: Vec<GuardrailAuditRow> = sqlx::query_as(
        "SELECT timestamp, payload, user_id \
         FROM audit.logs \
         WHERE event_type = 'guardrail_triggered' \
         ORDER BY timestamp DESC \
         LIMIT 100",
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|e| {
        tracing::error!("guardrail dashboard query failed: {}", e);
        ApiError::internal("failed to fetch guardrail events")
    })?;

    let response: Vec<Value> = rows
        .into_iter()
        .map(|row| {
            let payload = row.payload.unwrap_or_else(|| json!({}));
            json!({
                "timestamp": row.timestamp.and_utc().to_rfc3339(),
                "query": payload.get("query").and_then(Value::as_str).unwrap_or(""),
                "trigger_reason": payload
                    .get("trigger_reason")
                    .and_then(Value::as_str)
                    .unwrap_or("UNKNOWN"),
                "confidence": payload.get("confidence").and_then(Value::as_f64),
                "user_id": row.user_id
            })
        })
        .collect();

    Ok(HttpResponse::Ok().json(response))
}
