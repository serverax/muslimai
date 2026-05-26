//! Qdrant vector-DB client over its REST API (Step 16).
//!
//! Uses `reqwest` (http) instead of the `qdrant-client` gRPC crate to avoid the
//! `tonic` dependency tree. NOT runtime-tested here (no live Qdrant); the pure
//! threshold-filter logic is unit-tested.

use reqwest::Client;
use serde::{Deserialize, Serialize};
use tokio::time::{sleep, Duration};
use uuid::Uuid;

pub struct QdrantVectorDB {
    client: Client,
    base_url: String,
    collection: String,
}

#[derive(Serialize)]
struct SearchBody<'a> {
    vector: &'a [f32],
    limit: usize,
    with_payload: bool,
    score_threshold: f32,
}

#[derive(Serialize)]
struct CreateCollectionBody {
    vectors: VectorParams,
}

#[derive(Serialize)]
struct VectorParams {
    size: usize,
    distance: &'static str,
}

#[derive(Serialize)]
struct UpsertBody {
    points: Vec<UpsertPoint>,
}

#[derive(Serialize)]
struct UpsertPoint {
    id: Uuid,
    vector: Vec<f32>,
    payload: serde_json::Value,
}

#[derive(Deserialize)]
struct SearchEnvelope {
    result: Vec<ScoredPoint>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ScoredPoint {
    /// Qdrant point id (integer or UUID) — kept as raw JSON.
    pub id: serde_json::Value,
    pub score: f32,
    #[serde(default)]
    pub payload: Option<serde_json::Value>,
}

impl QdrantVectorDB {
    pub fn new(base_url: &str, collection: &str) -> Self {
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(20))
            .build()
            .unwrap_or_else(|_| Client::new());
        QdrantVectorDB {
            client,
            base_url: base_url.trim_end_matches('/').to_string(),
            collection: collection.to_string(),
        }
    }

    /// Create the collection if it does not already exist.
    pub async fn ensure_collection(
        &self,
        vector_size: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let url = format!(
            "{}/collections/{}",
            self.base_url.trim_end_matches('/'),
            self.collection
        );
        self.client
            .put(url)
            .json(&CreateCollectionBody {
                vectors: VectorParams {
                    size: vector_size,
                    distance: "Cosine",
                },
            })
            .send()
            .await?
            .error_for_status()?;
        Ok(())
    }

    /// Upsert one verified chunk vector with enough payload for citation lookup.
    pub async fn upsert_chunk(
        &self,
        chunk_id: Uuid,
        source_id: Uuid,
        vector: Vec<f32>,
        payload: serde_json::Value,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let url = format!(
            "{}/collections/{}/points?wait=true",
            self.base_url.trim_end_matches('/'),
            self.collection
        );
        let payload = match payload {
            serde_json::Value::Object(mut map) => {
                map.insert("chunk_id".to_string(), serde_json::json!(chunk_id));
                map.insert("source_id".to_string(), serde_json::json!(source_id));
                serde_json::Value::Object(map)
            }
            _ => serde_json::json!({
                "chunk_id": chunk_id,
                "source_id": source_id
            }),
        };
        self.client
            .put(url)
            .json(&UpsertBody {
                points: vec![UpsertPoint {
                    id: chunk_id,
                    vector,
                    payload,
                }],
            })
            .send()
            .await?
            .error_for_status()?;
        Ok(())
    }

    /// Search for the nearest points at or above `threshold`.
    pub async fn search(
        &self,
        query_embedding: &[f32],
        threshold: f32,
        limit: usize,
    ) -> Result<Vec<ScoredPoint>, Box<dyn std::error::Error>> {
        let url = format!(
            "{}/collections/{}/points/search",
            self.base_url.trim_end_matches('/'),
            self.collection
        );
        let body = SearchBody {
            vector: query_embedding,
            limit,
            with_payload: true,
            score_threshold: threshold,
        };
        let mut last_err: Option<String> = None;
        let mut env: Option<SearchEnvelope> = None;
        for attempt in 1..=3 {
            let response = self.client.post(&url).json(&body).send().await;
            match response {
                Ok(http_response) => {
                    let http_response = http_response.error_for_status()?;
                    env = Some(http_response.json().await?);
                    break;
                }
                Err(err) => {
                    last_err = Some(err.to_string());
                    if attempt < 3 {
                        sleep(Duration::from_millis(150 * attempt as u64)).await;
                    }
                }
            }
        }
        let env = match env {
            Some(value) => value,
            None => {
                return Err(last_err
                    .unwrap_or_else(|| "qdrant search failed".to_string())
                    .into())
            }
        };
        // Qdrant applies score_threshold server-side; filter defensively too.
        Ok(filter_by_threshold(env.result, threshold))
    }

    pub async fn health_check(&self) -> bool {
        self.client
            .get(format!("{}/health", self.base_url))
            .send()
            .await
            .map(|resp| resp.status().is_success())
            .unwrap_or(false)
    }
}

/// Pure threshold filter (unit-tested without a live Qdrant).
pub fn filter_by_threshold(points: Vec<ScoredPoint>, threshold: f32) -> Vec<ScoredPoint> {
    points
        .into_iter()
        .filter(|p| p.score >= threshold)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(score: f32) -> ScoredPoint {
        ScoredPoint {
            id: serde_json::json!(1),
            score,
            payload: None,
        }
    }

    #[test]
    fn filters_points_below_threshold() {
        let kept = filter_by_threshold(vec![point(0.95), point(0.70), point(0.92)], 0.85);
        assert_eq!(kept.len(), 2);
        assert!(kept.iter().all(|p| p.score >= 0.85));
    }

    #[test]
    fn filters_url_independent_payload_points() {
        let kept = filter_by_threshold(vec![point(0.85), point(0.84)], 0.85);
        assert_eq!(kept.len(), 1);
    }
}
