use crate::error::ApiError;
use crate::models::rules::{RulesEvaluateRequest, RulesEvaluateResponse};
use crate::models::{
    BrainRouteRequest, BrainRouteResponse, RagQuery, RagResponse, SakinaAskRequest,
};
use serde_json::Value;

#[derive(Clone)]
pub struct DistributedClient {
    client: reqwest::Client,
}

impl Default for DistributedClient {
    fn default() -> Self {
        Self::new()
    }
}

impl DistributedClient {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(150))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self { client }
    }

    pub async fn evaluate_rules(
        &self,
        url: &str,
        request: &RulesEvaluateRequest,
    ) -> Result<RulesEvaluateResponse, ApiError> {
        let res = self
            .client
            .post(format!("{}/api/rules/evaluate", url))
            .json(request)
            .send()
            .await
            .map_err(|e| {
                ApiError::internal(format!("failed to call rules engine service: {}", e))
            })?;

        if !res.status().is_success() {
            return Err(ApiError::internal(format!(
                "rules engine service returned error: {}",
                res.status()
            )));
        }

        res.json()
            .await
            .map_err(|e| ApiError::internal(format!("failed to parse rules response: {}", e)))
    }

    pub async fn route_brain(
        &self,
        url: &str,
        request: &BrainRouteRequest,
    ) -> Result<BrainRouteResponse, ApiError> {
        let res = self
            .client
            .post(format!("{}/api/brain/route", url))
            .json(request)
            .send()
            .await
            .map_err(|e| ApiError::internal(format!("failed to call brain service: {}", e)))?;

        if !res.status().is_success() {
            return Err(ApiError::internal(format!(
                "brain service returned error: {}",
                res.status()
            )));
        }

        res.json()
            .await
            .map_err(|e| ApiError::internal(format!("failed to parse brain response: {}", e)))
    }

    pub async fn query_rag(&self, url: &str, request: &RagQuery) -> Result<RagResponse, ApiError> {
        let res = self
            .client
            .post(format!("{}/api/rag/query", url))
            .json(request)
            .send()
            .await
            .map_err(|e| ApiError::internal(format!("failed to call rag service: {}", e)))?;

        if !res.status().is_success() {
            return Err(ApiError::internal(format!(
                "rag service returned error: {}",
                res.status()
            )));
        }

        res.json()
            .await
            .map_err(|e| ApiError::internal(format!("failed to parse rag response: {}", e)))
    }

    pub async fn answer_sakina(
        &self,
        url: &str,
        request: &SakinaAskRequest,
        auth_header: Option<&str>,
    ) -> Result<Value, ApiError> {
        let mut rb = self
            .client
            .post(format!("{}/api/sakina/ask", url))
            .json(request);

        if let Some(auth) = auth_header {
            rb = rb.header("Authorization", auth);
        }

        let res = rb.send().await.map_err(|e| {
            ApiError::internal(format!("failed to call islamic knowledge service: {}", e))
        })?;

        if !res.status().is_success() {
            let status = res.status();
            let body = res.text().await.unwrap_or_default();
            return Err(ApiError::internal(format!(
                "islamic knowledge service returned error {}: {}",
                status, body
            )));
        }

        res.json().await.map_err(|e| {
            ApiError::internal(format!("failed to parse islamic knowledge response: {}", e))
        })
    }

    pub async fn check_evaluation(
        &self,
        url: &str,
        answer: &str,
        citations: Vec<String>,
        message: &str,
        language: &str,
    ) -> Result<Value, ApiError> {
        let res = self
            .client
            .post(format!("{}/api/evaluation/check", url))
            .json(&serde_json::json!({
                "message": message,
                "answer": answer,
                "citations": citations,
                "language": language,
            }))
            .send()
            .await
            .map_err(|e| ApiError::internal(format!("failed to call evaluation service: {}", e)))?;

        if !res.status().is_success() {
            return Err(ApiError::internal(format!(
                "evaluation service returned error: {}",
                res.status()
            )));
        }

        res.json()
            .await
            .map_err(|e| ApiError::internal(format!("failed to parse evaluation response: {}", e)))
    }
}
