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

#[derive(Debug, Clone)]
pub struct EmbeddingsService {
    client: Client,
    base_url: String,
    model: String,
}

impl EmbeddingsService {
    pub fn new(base_url: &str) -> Self {
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(10))
            .timeout(Duration::from_secs(120))
            .build()
            .unwrap_or_else(|_| Client::new());
        EmbeddingsService {
            client,
            base_url: base_url.trim_end_matches('/').to_string(),
            model: std::env::var("VLLM_EMBEDDING_MODEL")
                .unwrap_or_else(|_| "sakina-local-embedding".to_string()),
        }
    }

    #[cfg(test)]
    fn deterministic_embedding(&self, text: &str) -> Vec<f32> {
        let dim = std::env::var("VLLM_EMBEDDING_DIM")
            .ok()
            .and_then(|v| v.parse::<usize>().ok())
            .unwrap_or(128)
            .max(8);
        let mut vector = vec![0.0_f32; dim];
        for (index, token) in text
            .split(|ch: char| !ch.is_alphanumeric() && ch != '_' && ch != 'ء' && ch != 'آ')
            .filter(|token| !token.is_empty())
            .enumerate()
        {
            let mut hash = 0u64;
            for byte in token.to_lowercase().bytes() {
                hash = hash
                    .wrapping_mul(1099511628211)
                    .wrapping_add(byte as u64 + 1);
            }
            let bucket = (hash as usize + index) % dim;
            vector[bucket] += 1.0;
            let neighbor = (bucket + 1) % dim;
            vector[neighbor] += 0.25;
        }
        let norm = vector.iter().map(|value| value * value).sum::<f32>().sqrt();
        if norm > 0.0 {
            for value in &mut vector {
                *value /= norm;
            }
        }
        vector
    }

    /// Get the embedding vector for `text` from vLLM.
    pub async fn embed(&self, text: &str) -> Result<Vec<f32>, Box<dyn std::error::Error>> {
        if self.base_url.contains("mock://") && !std::env::var("ALLOW_MOCK_PROD_OVERRIDE").is_ok() {
            return Err("mock embedding endpoints are not allowed in production paths".into());
        }
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
        if self.base_url.contains("mock://") && !std::env::var("ALLOW_MOCK_PROD_OVERRIDE").is_ok() {
            return false;
        }
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
        let json = serde_json::to_string(&req).expect("serialize embedding request");
        assert!(json.contains("\"input\":\"test\""));
        assert!(json.contains("\"model\":\"m\""));
    }

    #[test]
    fn deterministic_test_embeddings_are_normalized() {
        let service = EmbeddingsService::new("http://embedding-service");
        let a = service.deterministic_embedding("What is patience in Islam?");
        let b = service.deterministic_embedding("What is patience in Islam?");
        assert_eq!(a, b);
        let norm = a.iter().map(|value| value * value).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 0.0001 || norm == 0.0);
    }
}
