//! Semantic router: classifies an incoming query's intent so the RAG pipeline
//! can route FiqhQuery / TafsirQuery / CompanionChat / OutOfScope appropriately.
//!
//! Uses deterministic routing rules first so obviously out-of-scope traffic is
//! rejected without spending LLM or vector-search capacity. A later version can
//! replace the keyword rules with a local classifier while preserving this API.

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
pub struct SemanticRouter;

impl SemanticRouter {
    pub fn new() -> Self {
        SemanticRouter
    }

    /// Classify an incoming query to determine intent + confidence.
    ///
    pub async fn classify(
        &self,
        query: &str,
    ) -> Result<ClassifyResult, Box<dyn std::error::Error>> {
        let normalized = query.to_lowercase();
        let (intent, confidence, routing_decision) = if contains_any(
            &normalized,
            &[
                "tafsir",
                "quran",
                "surah",
                "ayah",
                "verse",
                "تفسير",
                "قرآن",
                "سورة",
                "آية",
            ],
        ) {
            (QueryIntent::TafsirQuery, 0.88, "RAG")
        } else if contains_any(
            &normalized,
            &[
                "fiqh",
                "halal",
                "haram",
                "permissible",
                "madhhab",
                "wudu",
                "salah",
                "zakat",
                "fasting",
                "حلال",
                "حرام",
                "فقه",
                "وضوء",
                "صلاة",
            ],
        ) {
            (QueryIntent::FiqhQuery, 0.90, "RAG")
        } else if contains_any(
            &normalized,
            &[
                "islam", "muslim", "dua", "hadith", "sunnah", "prophet", "الله", "حديث", "دعاء",
                "سنة",
            ],
        ) {
            (QueryIntent::CompanionChat, 0.80, "RAG")
        } else {
            (QueryIntent::OutOfScope, 0.75, "DECLINE")
        };

        Ok(ClassifyResult {
            intent,
            confidence,
            routing_decision: routing_decision.to_string(),
        })
    }
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn classifies_fiqh_query() {
        let router = SemanticRouter::new();
        let result = router
            .classify("Is music permissible in Islam?")
            .await
            .unwrap();
        assert!(matches!(result.intent, QueryIntent::FiqhQuery));
        assert_eq!(result.confidence, 0.90);
        assert_eq!(result.routing_decision, "RAG");
    }

    #[tokio::test]
    async fn classifies_out_of_scope_query() {
        let router = SemanticRouter::new();
        let result = router
            .classify("How do I tune a database index?")
            .await
            .unwrap();
        assert!(matches!(result.intent, QueryIntent::OutOfScope));
        assert_eq!(result.routing_decision, "DECLINE");
    }
}
