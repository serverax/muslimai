//! Semantic router: classifies an incoming query's intent so the RAG pipeline
//! can route FiqhQuery / TafsirQuery / CompanionChat / OutOfScope appropriately.
//!
//! Step 1 (Phase 1): stub classifier that returns FiqhQuery. The real path will
//! call vLLM's completion endpoint and parse intent + confidence.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum QueryIntent {
    FiqhQuery,     // Islamic jurisprudence question
    TafsirQuery,   // Quran interpretation question
    CompanionChat, // General Islamic discussion
    OutOfScope,    // Not an Islamic question
}

#[derive(Debug, Serialize)]
pub struct ClassifyResult {
    pub intent: QueryIntent,
    pub confidence: f32,
    pub routing_decision: String,
}

#[derive(Default)]
pub struct SemanticRouter {
    // Will use vLLM or a local classifier.
}

impl SemanticRouter {
    pub fn new() -> Self {
        SemanticRouter {}
    }

    /// Classify an incoming query to determine intent + confidence.
    ///
    /// TODO: call vLLM `/v1/completions` with a classification prompt and parse
    /// the intent + confidence from the response. For now this returns a stub
    /// that matches the test expectations.
    pub async fn classify(
        &self,
        query: &str,
    ) -> Result<ClassifyResult, Box<dyn std::error::Error>> {
        let _ = query; // unused until vLLM wiring lands
        Ok(ClassifyResult {
            intent: QueryIntent::FiqhQuery,
            confidence: 0.95,
            routing_decision: "RAG".to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn classify_returns_fiqh_stub() {
        let router = SemanticRouter::new();
        let result = router
            .classify("Is music permissible in Islam?")
            .await
            .unwrap();
        assert!(matches!(result.intent, QueryIntent::FiqhQuery));
        assert_eq!(result.confidence, 0.95);
        assert_eq!(result.routing_decision, "RAG");
    }
}
