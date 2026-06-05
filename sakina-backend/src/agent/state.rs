use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum AgentNode {
    Orchestrator,
    Researcher,
    Validator,
    HumanReview,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct AgentOutcome {
    pub node: AgentNode,
    pub decision: String,
    pub confidence: f32,
    pub latency_ms: u128,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct SakinaState {
    pub trace_id: Uuid,
    pub user_id: Uuid,
    pub user_query: String,
    pub language: String,
    pub intent: String,
    pub risk_level: String,
    pub context: Option<String>,
    pub memory_trace: Vec<String>,
    pub confidence_score: f32,
    pub next_node: AgentNode,
    pub outcomes: Vec<AgentOutcome>,
}

impl SakinaState {
    pub fn new(user_id: Uuid, user_query: impl Into<String>, language: impl Into<String>) -> Self {
        Self {
            trace_id: Uuid::new_v4(),
            user_id,
            user_query: user_query.into(),
            language: language.into(),
            intent: "unknown".to_string(),
            risk_level: "unclassified".to_string(),
            context: None,
            memory_trace: Vec::new(),
            confidence_score: 0.0,
            next_node: AgentNode::Orchestrator,
            outcomes: Vec::new(),
        }
    }

    pub fn record(&mut self, node: AgentNode, decision: impl Into<String>, confidence: f32) {
        self.outcomes.push(AgentOutcome {
            node,
            decision: decision.into(),
            confidence,
            latency_ms: 0,
        });
    }
}
