//! vLLM embeddings client using the OpenAI-compatible `/v1/embeddings` API.

use reqwest::Client;
use serde::{Deserialize, Serialize};
use tokio::time::{sleep, Duration};

#[derive(Serialize)]
pub struct EmbeddingRequest {
    pub input: String,
    pub model: String,
}

#[derive(Deserialize)]
struct EmbeddingResponse {
    data: Vec<EmbeddingData>,
}

#[derive(Deserialize)]
struct EmbeddingData {
    embedding: Vec<f32>,
}

pub struct EmbeddingsService {
    client: Client,
    base_url: String,
    model: String,
}

impl EmbeddingsService {
    pub fn new(base_url: &str) -> Self {
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(20))
            .build()
            .unwrap_or_else(|_| Client::new());
        EmbeddingsService {
            client,
            base_url: base_url.trim_end_matches('/').to_string(),
            model: std::env::var("VLLM_EMBEDDING_MODEL")
                .unwrap_or_else(|_| "sakina-local-embedding".to_string()),
        }
    }

    /// Get the embedding vector for `text` from vLLM.
    pub async fn embed(&self, text: &str) -> Result<Vec<f32>, Box<dyn std::error::Error>> {
        let req = EmbeddingRequest {
            input: text.to_string(),
            model: self.model.clone(),
        };
        let mut last_err: Option<String> = None;
        for attempt in 1..=3 {
            let response = self
                .client
                .post(format!("{}/v1/embeddings", self.base_url))
                .json(&req)
                .send()
                .await;
            match response {
                Ok(resp) => {
                    let resp = resp.error_for_status()?;
                    let resp: EmbeddingResponse = resp.json().await?;
                    return match resp.data.into_iter().next() {
                        Some(d) => Ok(d.embedding),
                        None => Err("vLLM returned an empty embeddings response"
                            .to_string()
                            .into()),
                    };
                }
                Err(err) => {
                    last_err = Some(err.to_string());
                    if attempt < 3 {
                        sleep(Duration::from_millis(200 * attempt as u64)).await;
                    }
                }
            }
        }

        Err(last_err
            .unwrap_or_else(|| "embedding request failed".to_string())
            .into())
    }

    pub async fn health_check(&self) -> bool {
        self.client
            .get(format!("{}/v1/models", self.base_url))
            .send()
            .await
            .map(|resp| resp.status().is_success())
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_serializes() {
        let req = EmbeddingRequest {
            input: "test".to_string(),
            model: "m".to_string(),
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("\"input\":\"test\""));
        assert!(json.contains("\"model\":\"m\""));
    }
}
