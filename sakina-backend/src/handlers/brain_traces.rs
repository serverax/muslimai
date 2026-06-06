use actix_web::{web, HttpRequest, HttpResponse};
use sqlx::Row;

use crate::error::ApiError;
use crate::services::authenticated_user_id;

pub async fn get_trace(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    path: web::Path<String>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let trace_id = path.into_inner();
    let row = sqlx::query(
        r#"
        SELECT request_id, user_id, workspace_id, intent, language, risk_level,
               selected_agent, selected_model, selected_pipeline, source_strategy,
               evaluation_result, final_action, execution_trace, created_at::text AS created_at
        FROM sakina_ai.brain_decision_traces
        WHERE request_id = $1
          AND user_id = $2
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(&trace_id)
    .bind(user_id.to_string())
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load brain trace"))?;

    let Some(row) = row else {
        return Ok(HttpResponse::NotFound().json(serde_json::json!({
            "found": false,
            "reason": "trace not found for authenticated user"
        })));
    };

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "request_id": row.get::<String, _>("request_id"),
        "user_id": row.get::<Option<String>, _>("user_id"),
        "workspace_id": row.get::<Option<uuid::Uuid>, _>("workspace_id"),
        "intent": row.get::<String, _>("intent"),
        "language": row.get::<String, _>("language"),
        "risk_level": row.get::<String, _>("risk_level"),
        "selected_agent": row.get::<String, _>("selected_agent"),
        "selected_model": row.get::<String, _>("selected_model"),
        "selected_pipeline": row.get::<String, _>("selected_pipeline"),
        "source_strategy": row.get::<String, _>("source_strategy"),
        "evaluation_result": row.get::<String, _>("evaluation_result"),
        "final_action": row.get::<String, _>("final_action"),
        "execution_trace": row.get::<serde_json::Value, _>("execution_trace"),
        "created_at": row.get::<String, _>("created_at"),
    })))
}
