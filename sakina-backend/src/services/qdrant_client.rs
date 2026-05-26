//! Qdrant vector-DB client over its REST API (Step 16).
//!
//! Uses `reqwest` (http) instead of the `qdrant-client` gRPC crate to avoid the
//! `tonic` dependency tree. NOT runtime-tested here (no live Qdrant); the pure
//! threshold-filter logic is unit-tested.

use reqwest::Client;
use serde::{Deserialize, Serialize};

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
        QdrantVectorDB {
            client: Client::new(),
            base_url: base_url.to_string(),
            collection: collection.to_string(),
        }
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
            self.base_url, self.collection
        );
        let body = SearchBody {
            vector: query_embedding,
            limit,
            with_payload: true,
            score_threshold: threshold,
        };
        let env: SearchEnvelope = self
            .client
            .post(url)
            .json(&body)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;
        // Qdrant applies score_threshold server-side; filter defensively too.
        Ok(filter_by_threshold(env.result, threshold))
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
}
