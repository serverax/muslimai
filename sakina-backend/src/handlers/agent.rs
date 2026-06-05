use std::time::Instant;

use actix_web::{web, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::agent::{AgenticOrchestrator, SakinaMemoryStore, SakinaState};
use crate::error::ApiError;

#[derive(Debug, Deserialize)]
pub struct AgentRouteProbeRequest {
    pub trace_id: Option<Uuid>,
    pub user_id: Option<Uuid>,
    pub query: String,
    pub language: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AgentRouteProbeResponse {
    pub trace_id: Uuid,
    pub selected_node: String,
    pub intent: String,
    pub risk_level: String,
    pub context: Option<String>,
    pub memory_trace: Vec<String>,
    pub redis_shared_state_loaded: bool,
    pub memory_load_ms: u128,
}

#[derive(Debug, Deserialize)]
pub struct AgentValidationProbeRequest {
    pub input: String,
}

pub async fn rollout_route_probe(
    req: HttpRequest,
    body: web::Json<AgentRouteProbeRequest>,
) -> Result<HttpResponse, ApiError> {
    require_rollout_probe_enabled(&req)?;
    let redis_url = std::env::var("SAKINA_REDIS_URL")
        .map_err(|_| ApiError::service_unavailable("SAKINA_REDIS_URL is required"))?;
    let store = SakinaMemoryStore::from_url(&redis_url)
        .map_err(|_| ApiError::service_unavailable("failed to create redis agent memory pool"))?;
    let orchestrator = AgenticOrchestrator::default().with_memory_store(store);
    let request = body.into_inner();
    let mut state = SakinaState::new(
        request.user_id.unwrap_or_else(Uuid::new_v4),
        request.query,
        request.language.unwrap_or_else(|| "en".to_string()),
    );
    if let Some(trace_id) = request.trace_id {
        state.trace_id = trace_id;
    }

    let started = Instant::now();
    let result = orchestrator
        .route_with_memory(state)
        .await
        .map_err(|error| ApiError::bad_request(format!("agent route rejected: {error:?}")))?;
    let memory_load_ms = started.elapsed().as_millis();
    let redis_shared_state_loaded = result
        .state
        .memory_trace
        .iter()
        .any(|entry| entry == "loaded_existing_state_from_redis");

    Ok(HttpResponse::Ok().json(AgentRouteProbeResponse {
        trace_id: result.state.trace_id,
        selected_node: format!("{:?}", result.selected_node),
        intent: result.state.intent,
        risk_level: result.state.risk_level,
        context: result.state.context,
        memory_trace: result.state.memory_trace,
        redis_shared_state_loaded,
        memory_load_ms,
    }))
}

pub async fn rollout_validate_probe(
    req: HttpRequest,
    body: web::Json<AgentValidationProbeRequest>,
) -> Result<HttpResponse, ApiError> {
    require_rollout_probe_enabled(&req)?;
    let wasm_path = std::env::var("SAKINA_VALIDATOR_WASM_PATH")
        .unwrap_or_else(|_| "/opt/sakina/wasm/sakina_validator.wasm".to_string());
    if !std::path::Path::new(&wasm_path).is_file() {
        return Err(ApiError::service_unavailable(
            "validator wasm artifact is not mounted",
        ));
    }
    let reason = sakina_validator::validate_output_reason(&body.input);
    if reason != "allow" {
        return Err(ApiError::bad_request(format!(
            "validator rejected output: {reason}"
        )));
    }
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "status": "allow",
        "wasm_path": wasm_path
    })))
}

fn require_rollout_probe_enabled(req: &HttpRequest) -> Result<(), ApiError> {
    let enabled = std::env::var("SAKINA_AGENT_ROLLOUT_PROBE_ENABLED")
        .map(|value| value == "true")
        .unwrap_or(false);
    let header_enabled = req
        .headers()
        .get("x-sakina-rollout-probe")
        .and_then(|value| value.to_str().ok())
        .map(|value| value == "true")
        .unwrap_or(false);
    if enabled && header_enabled {
        Ok(())
    } else {
        Err(ApiError::not_found("agent rollout probe is not enabled"))
    }
}
