use actix_web::{web, HttpRequest, HttpResponse};
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::authenticated_user_id;

fn env_flag(name: &str, default_value: bool) -> bool {
    std::env::var(name)
        .ok()
        .map(|value| {
            matches!(
                value.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes"
            )
        })
        .unwrap_or(default_value)
}

async fn ensure_default_workspace(pool: &sqlx::PgPool, user_id: Uuid) -> Result<Uuid, ApiError> {
    sqlx::query_scalar::<_, Uuid>("SELECT sakina_ai.ensure_default_workspace($1)")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|_| ApiError::internal("failed to load user workspace"))
}

pub async fn status(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let workspace_id = ensure_default_workspace(pool.get_ref(), user_id).await?;
    let ollama_enabled = env_flag("SAKINA_LLM_ENABLED", false);
    let cpu_mode = env_flag("OLLAMA_CPU_MODE", true);
    let fallback_enabled = env_flag("SAKINA_LLM_FALLBACK_ENABLED", true);
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "user_id": user_id,
        "workspace_id": workspace_id,
        "providers": [{
            "provider": "ollama",
            "enabled": ollama_enabled,
            "gateway_url": std::env::var("SAKINA_LLM_GATEWAY_URL").unwrap_or_else(|_| "http://sakina-llm-gateway:8087".to_string()),
            "model_name": std::env::var("OLLAMA_DEFAULT_MODEL").unwrap_or_else(|_| "llama3.2:1b".to_string()),
            "cpu_mode": cpu_mode,
            "timeout_seconds": std::env::var("OLLAMA_TIMEOUT_SECONDS").unwrap_or_else(|_| "60".to_string()),
            "fallback_enabled": fallback_enabled,
            "status": if ollama_enabled { "configured" } else { "disabled" }
        }],
        "brain_controlled": true,
    })))
}
