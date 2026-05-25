use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub pub_key: String,
    pub madhhab_preference: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RagQuery {
    pub query: String,
    pub user_id: Uuid,
    pub madhhab_filter: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RagResponse {
    pub answer: String,
    pub sources: Vec<SourceReference>,
    pub confidence: f32,
    pub guardrail_triggered: bool,
    pub processing_time_ms: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SourceReference {
    pub id: String,
    pub title: String,
    pub author: String,
    pub chapter: String,
    pub authenticity_grade: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClassifyRequest {
    pub text: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClassifyResponse {
    pub intent: String,
    pub confidence: f32,
    pub routing_decision: String,
}
