use crate::error::ApiError;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct SakinaLlmGateway {
    client: reqwest::Client,
    base_url: String,
    model: String,
    enabled: bool,
    timeout_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SakinaLlmGatewayRequest {
    pub trace_id: String,
    pub workspace_id: String,
    pub language: String,
    pub intent: String,
    pub user_stage: String,
    pub safe_user_message: String,
    pub local_db_context: String,
    pub rag_context: String,
    pub graph_context: String,
    pub safety_flags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SakinaLlmGatewayResult {
    pub answer: String,
    pub provider: String,
    pub model: String,
    pub used: bool,
    pub fallback_used: bool,
    pub status: String,
    pub latency_ms: Option<u64>,
    pub token_usage: Option<serde_json::Value>,
}

impl SakinaLlmGateway {
    pub fn from_env() -> Self {
        let enabled = matches!(
            std::env::var("SAKINA_LLM_ENABLED")
                .unwrap_or_else(|_| "false".to_string())
                .trim()
                .to_ascii_lowercase()
                .as_str(),
            "1" | "true" | "yes" | "on"
        );
        let timeout_seconds = std::env::var("SAKINA_LLM_TIMEOUT_SECONDS")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(60);
        Self {
            client: reqwest::Client::new(),
            base_url: std::env::var("SAKINA_LLM_GATEWAY_URL")
                .unwrap_or_else(|_| "http://sakina-llm-gateway:8087".to_string()),
            model: std::env::var("SAKINA_LLM_MODEL")
                .unwrap_or_else(|_| "sakina-islamic-support:cpu".to_string()),
            enabled,
            timeout_seconds,
        }
    }

    pub fn enabled(&self) -> bool {
        self.enabled
    }

    pub fn model(&self) -> &str {
        &self.model
    }

    pub async fn generate_sakina_answer(
        &self,
        request: SakinaLlmGatewayRequest,
    ) -> Result<SakinaLlmGatewayResult, ApiError> {
        if !self.enabled {
            return Ok(SakinaLlmGatewayResult {
                answer: String::new(),
                provider: "ollama".to_string(),
                model: self.model.clone(),
                used: false,
                fallback_used: false,
                status: "disabled_closed".to_string(),
                latency_ms: None,
                token_usage: None,
            });
        }
        if request.local_db_context.trim().is_empty()
            && request.rag_context.trim().is_empty()
            && request.graph_context.trim().is_empty()
        {
            return Ok(SakinaLlmGatewayResult {
                answer: String::new(),
                provider: "ollama".to_string(),
                model: self.model.clone(),
                used: false,
                fallback_used: true,
                status: "blocked_no_allowed_context".to_string(),
                latency_ms: None,
                token_usage: None,
            });
        }

        let url = format!("{}/generate", self.base_url.trim_end_matches('/'));
        let response = self
            .client
            .post(url)
            .timeout(std::time::Duration::from_secs(self.timeout_seconds))
            .json(&request)
            .send()
            .await
            .map_err(|err| ApiError::internal(format!("llm gateway request failed: {err}")))?;

        if !response.status().is_success() {
            return Err(ApiError::internal(format!(
                "llm gateway returned non-success status: {}",
                response.status()
            )));
        }

        let body = response
            .json::<SakinaLlmGatewayResult>()
            .await
            .map_err(|err| {
                ApiError::internal(format!("llm gateway response parse failed: {err}"))
            })?;
        Ok(body)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backend_client_targets_llm_gateway_not_ollama() {
        let gateway = SakinaLlmGateway::from_env();
        assert!(gateway.base_url.contains("sakina-llm-gateway"));
    }

    #[test]
    fn request_carries_trace_and_workspace_identity() {
        let request = SakinaLlmGatewayRequest {
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
        };
        assert_eq!(request.trace_id, "trace-1");
        assert_eq!(request.workspace_id, "workspace-1");
    }
}
