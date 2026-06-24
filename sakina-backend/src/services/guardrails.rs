//! Guardrails: enforce the similarity-confidence threshold before answering.
//!
//! The live RAG path supplies the best retrieval score from the verified
//! knowledge index. This service only makes the final threshold decision.

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

    /// Check the strongest retrieval score from the verified-knowledge index.
    pub async fn check(
        &self,
        retrieval_scores: &[f32],
    ) -> Result<GuardrailResult, Box<dyn std::error::Error>> {
        let top_score = retrieval_scores
            .iter()
            .copied()
            .filter(|score| score.is_finite())
            .fold(0.0_f32, f32::max);
        Ok(self.evaluate_score(top_score))
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

    #[tokio::test]
    async fn check_uses_top_retrieval_score() {
        let g = Guardrails::new(0.85);
        let r = g.check(&[0.61, 0.91, 0.72]).await.expect("guardrail check");
        assert!(r.passed);
        assert_eq!(r.confidence, 0.91);
    }
}
