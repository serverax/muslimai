//! vLLM embeddings client (Step 17).
//!
//! `reqwest` -> vLLM's OpenAI-compatible `/v1/embeddings`. NOT runtime-tested
//! here (no live vLLM / no GPU); request serialization is unit-tested.

use reqwest::Client;
use serde::{Deserialize, Serialize};

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
        EmbeddingsService {
            client: Client::new(),
            base_url: base_url.to_string(),
            model: "text-embedding-3-small".to_string(),
        }
    }

    /// Get the embedding vector for `text` from vLLM.
    pub async fn embed(&self, text: &str) -> Result<Vec<f32>, Box<dyn std::error::Error>> {
        let req = EmbeddingRequest {
            input: text.to_string(),
            model: self.model.clone(),
        };
        let resp: EmbeddingResponse = self
            .client
            .post(format!("{}/v1/embeddings", self.base_url))
            .json(&req)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;
        match resp.data.into_iter().next() {
            Some(d) => Ok(d.embedding),
            None => Err("vLLM returned an empty embeddings response".to_string().into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_serializes() {
        let req = EmbeddingRequest { input: "test".to_string(), model: "m".to_string() };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("\"input\":\"test\""));
        assert!(json.contains("\"model\":\"m\""));
    }
}
