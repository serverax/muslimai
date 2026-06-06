use actix_web::{web, App, HttpResponse, HttpServer};
use sakina_backend::services::{SakinaLlmGatewayRequest, SakinaLlmGatewayResult};
use serde::Deserialize;
use serde_json::json;
use std::time::Instant;

#[derive(Clone)]
struct GatewayState {
    client: reqwest::Client,
    ollama_base_url: String,
    model: String,
    timeout_seconds: u64,
}

#[derive(Debug, Deserialize)]
struct OllamaGenerateResponse {
    response: Option<String>,
    prompt_eval_count: Option<u64>,
    eval_count: Option<u64>,
}

fn env_value(name: &str, default_value: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| default_value.to_string())
}

fn build_controlled_prompt(request: &SakinaLlmGatewayRequest) -> String {
    format!(
        "SYSTEM CONTROL:\n\
You are Sakina AI, a Sunni Muslim companion and new-Muslim support assistant.\n\
Answer only from the allowed context.\n\
Reply in the user language: {language}.\n\
Do not invent Quran, hadith, fatwa, scholar names, or references.\n\
If the context is not enough, say you cannot verify.\n\
Do not mention private data.\n\
Do not answer out-of-scope topics.\n\n\
USER INTENT: {intent}\n\n\
USER STAGE:\n\
{user_stage}\n\n\
ALLOWED LOCAL DB CONTEXT:\n\
{local_db_context}\n\n\
ALLOWED RAG CONTEXT:\n\
{rag_context}\n\n\
ALLOWED GRAPH CONTEXT:\n\
{graph_context}\n\n\
SAFETY FLAGS:\n\
{safety_flags}\n\n\
USER MESSAGE AFTER PRIVACY REDACTION:\n\
{safe_user_message}\n\n\
Now produce a short, calm, Sunni-safe answer.",
        language = request.language,
        intent = request.intent,
        user_stage = request.user_stage,
        local_db_context = request.local_db_context,
        rag_context = request.rag_context,
        graph_context = request.graph_context,
        safety_flags = request.safety_flags.join(", "),
        safe_user_message = request.safe_user_message,
    )
}

async fn health() -> HttpResponse {
    HttpResponse::Ok().json(json!({
        "service": "sakina-llm-gateway",
        "status": "healthy"
    }))
}

async fn ready(state: web::Data<GatewayState>) -> HttpResponse {
    let url = format!("{}/api/tags", state.ollama_base_url.trim_end_matches('/'));
    match state
        .client
        .get(url)
        .timeout(std::time::Duration::from_secs(3))
        .send()
        .await
    {
        Ok(response) if response.status().is_success() => HttpResponse::Ok().json(json!({
            "service": "sakina-llm-gateway",
            "status": "ready",
            "ollama_reachable": true,
            "model": state.model
        })),
        Ok(response) => HttpResponse::ServiceUnavailable().json(json!({
            "service": "sakina-llm-gateway",
            "status": "not_ready",
            "ollama_reachable": false,
            "ollama_status": response.status().as_u16(),
            "model": state.model
        })),
        Err(error) => HttpResponse::ServiceUnavailable().json(json!({
            "service": "sakina-llm-gateway",
            "status": "not_ready",
            "ollama_reachable": false,
            "error": error.to_string(),
            "model": state.model
        })),
    }
}

async fn generate(
    state: web::Data<GatewayState>,
    payload: web::Json<SakinaLlmGatewayRequest>,
) -> HttpResponse {
    let request = payload.into_inner();
    if request.trace_id.trim().is_empty() || request.workspace_id.trim().is_empty() {
        return HttpResponse::BadRequest().json(json!({
            "error": "trace_id and workspace_id are required",
            "status": "rejected_missing_trace_or_workspace"
        }));
    }
    if request.local_db_context.trim().is_empty()
        && request.rag_context.trim().is_empty()
        && request.graph_context.trim().is_empty()
    {
        return HttpResponse::BadRequest().json(json!({
            "error": "allowed context is required before model generation",
            "status": "rejected_no_allowed_context",
            "trace_id": request.trace_id,
            "workspace_id": request.workspace_id
        }));
    }

    let started = Instant::now();
    let prompt = build_controlled_prompt(&request);
    let url = format!(
        "{}/api/generate",
        state.ollama_base_url.trim_end_matches('/')
    );
    let response = match state
        .client
        .post(url)
        .timeout(std::time::Duration::from_secs(state.timeout_seconds))
        .json(&json!({
            "model": state.model,
            "prompt": prompt,
            "stream": false,
            "keep_alive": "10m",
            "options": {
                "temperature": 0.2,
                "num_ctx": 1024,
                "num_predict": 96
            }
        }))
        .send()
        .await
    {
        Ok(response) => response,
        Err(error) => {
            tracing::error!(
                trace_id = %request.trace_id,
                workspace_id = %request.workspace_id,
                route = "generate",
                model = %state.model,
                error = %error,
                "sakina llm gateway request failed"
            );
            return HttpResponse::BadGateway().json(json!({
                "error": "ollama request failed",
                "status": "provider_unavailable",
                "trace_id": request.trace_id,
                "workspace_id": request.workspace_id
            }));
        }
    };

    if !response.status().is_success() {
        let status = response.status();
        tracing::warn!(
            trace_id = %request.trace_id,
            workspace_id = %request.workspace_id,
            route = "generate",
            model = %state.model,
            provider_status = status.as_u16(),
            "sakina llm gateway provider returned non-success"
        );
        return HttpResponse::BadGateway().json(json!({
            "error": "provider returned non-success status",
            "status": "provider_non_success",
            "provider_status": status.as_u16(),
            "trace_id": request.trace_id,
            "workspace_id": request.workspace_id
        }));
    }

    let body = match response.json::<OllamaGenerateResponse>().await {
        Ok(body) => body,
        Err(error) => {
            return HttpResponse::BadGateway().json(json!({
                "error": "provider response parse failed",
                "status": "provider_parse_failed",
                "detail": error.to_string(),
                "trace_id": request.trace_id,
                "workspace_id": request.workspace_id
            }));
        }
    };
    let answer = match body.response.map(|value| value.trim().to_string()) {
        Some(answer) if !answer.is_empty() => answer,
        _ => {
            return HttpResponse::BadGateway().json(json!({
                "error": "provider response was empty",
                "status": "provider_empty_response",
                "trace_id": request.trace_id,
                "workspace_id": request.workspace_id
            }));
        }
    };
    let latency_ms = started.elapsed().as_millis() as u64;
    let token_usage = json!({
        "prompt_eval_count": body.prompt_eval_count,
        "eval_count": body.eval_count
    });
    tracing::info!(
        trace_id = %request.trace_id,
        workspace_id = %request.workspace_id,
        route = "generate",
        model = %state.model,
        latency_ms,
        token_usage = %token_usage,
        "sakina llm gateway completed"
    );
    HttpResponse::Ok().json(SakinaLlmGatewayResult {
        answer,
        provider: "ollama".to_string(),
        model: state.model.clone(),
        used: true,
        fallback_used: false,
        status: "ok".to_string(),
        latency_ms: Some(latency_ms),
        token_usage: Some(token_usage),
    })
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    tracing_subscriber::fmt::init();

    let state = web::Data::new(GatewayState {
        client: reqwest::Client::new(),
        ollama_base_url: env_value("OLLAMA_BASE_URL", "http://sakina-ollama:11434"),
        model: env_value("SAKINA_LLM_MODEL", "qwen2.5:3b"),
        timeout_seconds: env_value("SAKINA_LLM_TIMEOUT_SECONDS", "60")
            .parse()
            .unwrap_or(60),
    });
    let bind_addr = env_value("SAKINA_LLM_GATEWAY_BIND", "0.0.0.0:8087");
    HttpServer::new(move || {
        App::new()
            .app_data(state.clone())
            .route("/health", web::get().to(health))
            .route("/ready", web::get().to(ready))
            .route("/generate", web::post().to(generate))
    })
    .bind(bind_addr)?
    .run()
    .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn controlled_prompt_uses_redacted_message_only() {
        let prompt = build_controlled_prompt(&SakinaLlmGatewayRequest {
            trace_id: "trace-1".to_string(),
            workspace_id: "workspace-1".to_string(),
            language: "en".to_string(),
            intent: "new_muslim".to_string(),
            user_stage: "new_muslim".to_string(),
            safe_user_message: "My name is [REDACTED_NAME] and I live at [REDACTED_ADDRESS]."
                .to_string(),
            local_db_context: "Local context".to_string(),
            rag_context: "RAG context".to_string(),
            graph_context: "Graph context".to_string(),
            safety_flags: vec!["pii_removed".to_string()],
        });
        assert!(prompt.contains("[REDACTED_NAME]"));
        assert!(prompt.contains("[REDACTED_ADDRESS]"));
        assert!(!prompt.contains("Ahmed"));
        assert!(!prompt.contains("22 Green Street"));
    }
}
