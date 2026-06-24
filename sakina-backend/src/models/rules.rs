use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RulesEvaluateRequest {
    pub message: String,
    pub language: String,
    pub intent: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RulesEvaluateResponse {
    pub allowed: bool,
    pub action: String, // allow, block, escalate
    pub reason: String,
    pub fallback_answer: Option<String>,
}
