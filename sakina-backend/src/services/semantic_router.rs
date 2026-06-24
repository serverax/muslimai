//! Semantic router: classifies an incoming query's intent so the RAG pipeline
//! can route FiqhQuery / TafsirQuery / CompanionChat / OutOfScope appropriately.
//!
//! The production fallback is deterministic and conservative. Provider-backed
//! routing can override it, but this path never fabricates a universal intent.

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
pub struct SemanticRouter {}

impl SemanticRouter {
    pub fn new() -> Self {
        SemanticRouter {}
    }

    /// Classify an incoming query to determine intent + confidence.
    pub async fn classify(
        &self,
        query: &str,
    ) -> Result<ClassifyResult, Box<dyn std::error::Error>> {
        let q = query.to_lowercase();
        let (intent, confidence) = if contains_any(
            &q,
            &[
                "tafsir",
                "ayah",
                "surah",
                "quran",
                "verse",
                "تفسير",
                "آية",
                "سورة",
                "قرآن",
            ],
        ) {
            (QueryIntent::TafsirQuery, 0.88)
        } else if contains_any(
            &q,
            &[
                "permissible",
                "halal",
                "haram",
                "ruling",
                "fatwa",
                "zakat",
                "fasting",
                "حلال",
                "حرام",
                "حكم",
                "فتوى",
                "زكاة",
                "صيام",
            ],
        ) {
            (QueryIntent::FiqhQuery, 0.87)
        } else if contains_any(
            &q,
            &[
                "salam", "dua", "dhikr", "prayer", "anxiety", "remember", "دعاء", "ذكر", "صلاة",
                "قلق",
            ],
        ) {
            (QueryIntent::CompanionChat, 0.82)
        } else {
            (QueryIntent::OutOfScope, 0.70)
        };
        let routing_decision = match intent {
            QueryIntent::FiqhQuery | QueryIntent::TafsirQuery => "RAG",
            QueryIntent::CompanionChat => "BRAIN_COMPANION",
            QueryIntent::OutOfScope => "SAFETY_CLARIFY",
        };
        Ok(ClassifyResult {
            intent,
            confidence,
            routing_decision: routing_decision.to_string(),
        })
    }
}

fn contains_any(text: &str, terms: &[&str]) -> bool {
    terms.iter().any(|term| text.contains(term))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn classify_detects_fiqh_query() {
        let router = SemanticRouter::new();
        let result = router
            .classify("Is music permissible in Islam?")
            .await
            .expect("classify fiqh query");
        assert!(matches!(result.intent, QueryIntent::FiqhQuery));
        assert!(result.confidence >= 0.85);
        assert_eq!(result.routing_decision, "RAG");
    }

    #[tokio::test]
    async fn classify_detects_out_of_scope_query() {
        let router = SemanticRouter::new();
        let result = router
            .classify("How do I tune a guitar?")
            .await
            .expect("classify out of scope query");
        assert!(matches!(result.intent, QueryIntent::OutOfScope));
        assert_eq!(result.routing_decision, "SAFETY_CLARIFY");
    }
}
