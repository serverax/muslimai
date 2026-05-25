//! Guardrails: enforce the similarity-confidence threshold before answering.
//!
//! Step 2 (Phase 1): threshold logic + a stubbed `check()`. The real path will
//! embed the query and search Qdrant for the top similarity score, then apply
//! `evaluate_score`. The Qdrant client is deliberately NOT wired yet (it pulls
//! ~400 transitive crates that exhaust this machine's RAM during compilation);
//! it lands with the real retrieval step, mirroring how the router defers vLLM.

use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct GuardrailResult {
    pub passed: bool,
    pub reason: Option<String>,
    pub confidence: f32,
}

pub struct Guardrails {
    similarity_threshold: f32, // e.g. 0.85
}

impl Guardrails {
    /// Threshold-only constructor. The roadmap's `new(qdrant, threshold)` gains
    /// the Qdrant client when real retrieval is wired.
    pub fn new(threshold: f32) -> Self {
        Guardrails {
            similarity_threshold: threshold,
        }
    }

    /// Pure decision: does the top similarity score clear the threshold?
    pub fn evaluate_score(&self, top_score: f32) -> GuardrailResult {
        if top_score < self.similarity_threshold {
            GuardrailResult {
                passed: false,
                reason: Some("Query below confidence threshold".to_string()),
                confidence: top_score,
            }
        } else {
            GuardrailResult {
                passed: true,
                reason: None,
                confidence: top_score,
            }
        }
    }

    /// Check a query embedding against the verified-knowledge index.
    ///
    /// TODO: search Qdrant over `query_embedding`, take the top score, then call
    /// `evaluate_score`. Stubbed (passes at 0.92) until qdrant-client is wired.
    pub async fn check(
        &self,
        query_embedding: &[f32],
    ) -> Result<GuardrailResult, Box<dyn std::error::Error>> {
        let _ = query_embedding;
        Ok(self.evaluate_score(0.92))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn below_threshold_is_blocked() {
        let g = Guardrails::new(0.85);
        let r = g.evaluate_score(0.50);
        assert!(!r.passed);
        assert!(r.reason.is_some());
        assert_eq!(r.confidence, 0.50);
    }

    #[test]
    fn at_or_above_threshold_passes() {
        let g = Guardrails::new(0.85);
        assert!(g.evaluate_score(0.85).passed);
        assert!(g.evaluate_score(0.99).passed);
        assert!(g.evaluate_score(0.99).reason.is_none());
    }
}
