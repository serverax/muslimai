use crate::models::{
    DecisionModule, DecisionRequest, DecisionResponse, DecisionSource, ReviewStatus, SafetyRisk,
};

#[derive(Debug, Clone, PartialEq)]
pub struct ModuleClassification {
    pub module: DecisionModule,
    pub confidence: f32,
}

pub trait ModuleClassifier {
    fn classify(&self, question: &str, selected_module: &str) -> ModuleClassification;
}

pub trait SafetyClassifier {
    fn classify(&self, question: &str, safety_context: Option<&str>) -> SafetyRisk;
}

pub trait RagRetriever {
    fn retrieve(&self, module: &DecisionModule, language: &str, query: &str)
        -> Vec<DecisionSource>;
}

pub trait LlmFormatter {
    fn summarize(
        &self,
        language: &str,
        question: &str,
        evidence: &[DecisionSource],
    ) -> Option<String>;
}

#[derive(Default)]
pub struct DefaultModuleClassifier;

impl ModuleClassifier for DefaultModuleClassifier {
    fn classify(&self, question: &str, selected_module: &str) -> ModuleClassification {
        let s = selected_module.trim().to_ascii_lowercase();
        let q = question.to_ascii_lowercase();
        let module = match s.as_str() {
            "quran" => DecisionModule::Quran,
            "prayer" => DecisionModule::Prayer,
            "knowledge" => DecisionModule::Knowledge,
            "community" => DecisionModule::Community,
            "general_chat" => DecisionModule::GeneralChat,
            _ => {
                if q.contains("quran") || q.contains("surah") {
                    DecisionModule::Quran
                } else if q.contains("prayer") || q.contains("salah") {
                    DecisionModule::Prayer
                } else if q.contains("community") {
                    DecisionModule::Community
                } else if q.contains("fiqh") || q.contains("knowledge") {
                    DecisionModule::Knowledge
                } else {
                    DecisionModule::Unsupported
                }
            }
        };
        let confidence = if matches!(module, DecisionModule::Unsupported) {
            0.45
        } else if s == "unknown" || s.is_empty() {
            0.62
        } else {
            0.9
        };
        ModuleClassification { module, confidence }
    }
}

#[derive(Default)]
pub struct DefaultSafetyClassifier;

impl SafetyClassifier for DefaultSafetyClassifier {
    fn classify(&self, question: &str, safety_context: Option<&str>) -> SafetyRisk {
        let mut text = question.to_ascii_lowercase();
        if let Some(extra) = safety_context {
            text.push(' ');
            text.push_str(&extra.to_ascii_lowercase());
        }
        if text.contains("suicide") || text.contains("self harm") {
            return SafetyRisk::CrisisSensitive;
        }
        if text.contains("fatwa") || text.contains("halal") || text.contains("haram") {
            return SafetyRisk::ReligiousSensitive;
        }
        if text.contains("medicine") || text.contains("diagnosis") {
            return SafetyRisk::MedicalSensitive;
        }
        if text.contains("legal") || text.contains("court") {
            return SafetyRisk::LegalSensitive;
        }
        if text.contains("child") || text.contains("minor") {
            return SafetyRisk::ChildSensitive;
        }
        SafetyRisk::Safe
    }
}

#[derive(Default)]
pub struct EmptyRetriever;

impl RagRetriever for EmptyRetriever {
    fn retrieve(
        &self,
        _module: &DecisionModule,
        _language: &str,
        _query: &str,
    ) -> Vec<DecisionSource> {
        Vec::new()
    }
}

#[derive(Default)]
pub struct StrictFormatter;

impl LlmFormatter for StrictFormatter {
    fn summarize(
        &self,
        _language: &str,
        question: &str,
        evidence: &[DecisionSource],
    ) -> Option<String> {
        if evidence.is_empty() {
            return None;
        }
        let first = evidence.first()?;
        Some(format!(
            "Verified summary for \"{}\" from {} ({})",
            question, first.source_name, first.source_reference
        ))
    }
}

fn feature_flag_for_module(module: &DecisionModule) -> Option<&'static str> {
    match module {
        DecisionModule::Quran => Some("SAKINA_FEATURE_QURAN"),
        DecisionModule::Prayer => Some("SAKINA_FEATURE_PRAYER"),
        DecisionModule::Knowledge => Some("SAKINA_FEATURE_KNOWLEDGE"),
        DecisionModule::Community => Some("SAKINA_FEATURE_COMMUNITY"),
        DecisionModule::GeneralChat => Some("SAKINA_FEATURE_CHAT"),
        DecisionModule::Unsupported => None,
    }
}

fn flag_enabled(key: &str) -> bool {
    std::env::var(key)
        .ok()
        .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
}

fn entitled(tier: &str) -> bool {
    matches!(
        tier.trim().to_ascii_lowercase().as_str(),
        "premium" | "pro" | "founding"
    )
}

fn rank_and_filter(
    module: &DecisionModule,
    language: &str,
    mut items: Vec<DecisionSource>,
) -> Vec<DecisionSource> {
    items.retain(|it| {
        let module_match = it
            .source_reference
            .to_ascii_lowercase()
            .contains(&format!("{:?}", module).to_ascii_lowercase())
            || !it.source_reference.trim().is_empty();
        let language_match = it.language.eq_ignore_ascii_case(language);
        it.review_status == ReviewStatus::Verified
            && !it.citation.trim().is_empty()
            && !it.content_hash.trim().is_empty()
            && it.similarity_score >= 0.70
            && module_match
            && language_match
    });
    items.sort_by(|a, b| {
        b.similarity_score
            .partial_cmp(&a.similarity_score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    items
}

pub fn decide(
    req: &DecisionRequest,
    module_classifier: &dyn ModuleClassifier,
    safety_classifier: &dyn SafetyClassifier,
    rag_retriever: &dyn RagRetriever,
    llm_formatter: &dyn LlmFormatter,
) -> DecisionResponse {
    let classification = module_classifier.classify(&req.question, &req.selected_module);
    let safety = safety_classifier.classify(&req.question, req.safety_context.as_deref());
    let module = classification.module.clone();
    let language = req.language.clone();

    if let Some(flag) = feature_flag_for_module(&module) {
        if !flag_enabled(flag) {
            return DecisionResponse {
                answer: "Module is disabled or in preview mode.".to_string(),
                module,
                language,
                confidence: classification.confidence,
                safety_status: SafetyRisk::Unknown,
                review_status: ReviewStatus::Disabled,
                sources: Vec::new(),
                citations: Vec::new(),
                generated_from_verified_sources: false,
                requires_scholar_review: false,
            };
        }
    }

    if !entitled(&req.user_subscription_tier) {
        return DecisionResponse {
            answer: "This module requires an eligible subscription tier.".to_string(),
            module,
            language,
            confidence: classification.confidence,
            safety_status: SafetyRisk::Unknown,
            review_status: ReviewStatus::Disabled,
            sources: Vec::new(),
            citations: Vec::new(),
            generated_from_verified_sources: false,
            requires_scholar_review: false,
        };
    }

    if classification.confidence < 0.60 || matches!(module, DecisionModule::Unsupported) {
        return DecisionResponse {
            answer: "Please clarify your request so I can route it safely.".to_string(),
            module,
            language,
            confidence: classification.confidence,
            safety_status: safety,
            review_status: ReviewStatus::ScholarReviewRequired,
            sources: Vec::new(),
            citations: Vec::new(),
            generated_from_verified_sources: false,
            requires_scholar_review: true,
        };
    }

    let raw = rag_retriever.retrieve(&module, &language, &req.question);
    let verified = rank_and_filter(&module, &language, raw);
    if verified.is_empty() {
        return DecisionResponse {
            answer: "No verified source is available yet. This topic is under review.".to_string(),
            module,
            language,
            confidence: classification.confidence * 0.8,
            safety_status: safety.clone(),
            review_status: ReviewStatus::ScholarReviewRequired,
            sources: Vec::new(),
            citations: Vec::new(),
            generated_from_verified_sources: false,
            requires_scholar_review: true,
        };
    }

    let requires_scholar_review = matches!(
        safety,
        SafetyRisk::ReligiousSensitive
            | SafetyRisk::MedicalSensitive
            | SafetyRisk::LegalSensitive
            | SafetyRisk::CrisisSensitive
            | SafetyRisk::ChildSensitive
    );
    let citations: Vec<String> = verified.iter().map(|s| s.citation.clone()).collect();
    let summary = llm_formatter.summarize(&language, &req.question, &verified);
    let answer = if requires_scholar_review {
        format!(
            "{} This is educational information only; consult a qualified scholar/professional.",
            summary.unwrap_or_else(|| "Verified sources found.".to_string())
        )
    } else {
        summary.unwrap_or_else(|| "Verified sources found.".to_string())
    };

    DecisionResponse {
        answer,
        module,
        language,
        confidence: classification.confidence,
        safety_status: safety,
        review_status: ReviewStatus::Verified,
        sources: verified,
        citations,
        generated_from_verified_sources: true,
        requires_scholar_review,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::DecisionSource;

    struct LowConfidenceClassifier;
    impl ModuleClassifier for LowConfidenceClassifier {
        fn classify(&self, _q: &str, _m: &str) -> ModuleClassification {
            ModuleClassification {
                module: DecisionModule::Unsupported,
                confidence: 0.4,
            }
        }
    }

    struct FixedSafety(SafetyRisk);
    impl SafetyClassifier for FixedSafety {
        fn classify(&self, _q: &str, _s: Option<&str>) -> SafetyRisk {
            self.0.clone()
        }
    }

    #[derive(Default)]
    struct CountingRetriever {
        calls: std::sync::Mutex<u32>,
        items: Vec<DecisionSource>,
    }
    impl RagRetriever for CountingRetriever {
        fn retrieve(&self, _m: &DecisionModule, _l: &str, _q: &str) -> Vec<DecisionSource> {
            *self.calls.lock().expect("calls lock") += 1;
            self.items.clone()
        }
    }

    #[derive(Default)]
    struct CountingFormatter {
        calls: std::sync::Mutex<u32>,
    }
    impl LlmFormatter for CountingFormatter {
        fn summarize(&self, _l: &str, _q: &str, evidence: &[DecisionSource]) -> Option<String> {
            *self.calls.lock().expect("calls lock") += 1;
            if evidence.is_empty() {
                None
            } else {
                Some("summary".to_string())
            }
        }
    }

    fn req(module: &str, tier: &str, q: &str) -> DecisionRequest {
        DecisionRequest {
            question: q.to_string(),
            selected_module: module.to_string(),
            language: "en".to_string(),
            user_subscription_tier: tier.to_string(),
            safety_context: None,
        }
    }

    fn verified_source(sim: f32) -> DecisionSource {
        DecisionSource {
            source_type: "tafsir".to_string(),
            source_name: "Verified Source".to_string(),
            source_reference: "quran:1:1".to_string(),
            citation: "Quran 1:1".to_string(),
            language: "en".to_string(),
            review_status: ReviewStatus::Verified,
            effective_date: None,
            content_hash: "hash".to_string(),
            retrieved_at: chrono::Utc::now().to_rfc3339(),
            similarity_score: sim,
        }
    }

    #[test]
    fn disabled_feature_does_not_call_rag_or_llm() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "false");
        let retriever = CountingRetriever::default();
        let formatter = CountingFormatter::default();
        let out = decide(
            &req("quran", "premium", "quran question"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &retriever,
            &formatter,
        );
        assert_eq!(out.review_status, ReviewStatus::Disabled);
        assert_eq!(*retriever.calls.lock().expect("calls lock"), 0);
        assert_eq!(*formatter.calls.lock().expect("calls lock"), 0);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn missing_entitlement_blocks_algorithm() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let retriever = CountingRetriever::default();
        let formatter = CountingFormatter::default();
        let out = decide(
            &req("quran", "free", "quran question"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &retriever,
            &formatter,
        );
        assert_eq!(out.review_status, ReviewStatus::Disabled);
        assert_eq!(*retriever.calls.lock().expect("calls lock"), 0);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn low_classifier_confidence_asks_clarification() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_CHAT", "true");
        let out = decide(
            &req("unknown", "premium", "hello"),
            &LowConfidenceClassifier,
            &DefaultSafetyClassifier,
            &EmptyRetriever,
            &StrictFormatter,
        );
        assert!(out.answer.to_ascii_lowercase().contains("clarify"));
        assert!(!out.generated_from_verified_sources);
        std::env::remove_var("SAKINA_FEATURE_CHAT");
    }

    #[test]
    fn unverified_source_is_rejected() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let mut s = verified_source(0.9);
        s.review_status = ReviewStatus::Unverified;
        let retriever = CountingRetriever {
            calls: std::sync::Mutex::new(0),
            items: vec![s],
        };
        let out = decide(
            &req("quran", "premium", "quran q"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &retriever,
            &StrictFormatter,
        );
        assert!(out.sources.is_empty());
        assert!(!out.generated_from_verified_sources);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn missing_citation_is_rejected() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let mut s = verified_source(0.9);
        s.citation = "".to_string();
        let retriever = CountingRetriever {
            calls: std::sync::Mutex::new(0),
            items: vec![s],
        };
        let out = decide(
            &req("quran", "premium", "quran q"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &retriever,
            &StrictFormatter,
        );
        assert!(out.sources.is_empty());
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn verified_source_is_returned() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let retriever = CountingRetriever {
            calls: std::sync::Mutex::new(0),
            items: vec![verified_source(0.91)],
        };
        let out = decide(
            &req("quran", "premium", "quran q"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &retriever,
            &StrictFormatter,
        );
        assert_eq!(out.review_status, ReviewStatus::Verified);
        assert_eq!(out.sources.len(), 1);
        assert!(!out.citations.is_empty());
        assert!(out.generated_from_verified_sources);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn llm_cannot_answer_without_retrieved_evidence() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let formatter = CountingFormatter::default();
        let out = decide(
            &req("quran", "premium", "quran q"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &EmptyRetriever,
            &formatter,
        );
        assert!(!out.generated_from_verified_sources);
        assert_eq!(*formatter.calls.lock().expect("calls lock"), 0);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn sensitive_question_requires_stricter_policy() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let retriever = CountingRetriever {
            calls: std::sync::Mutex::new(0),
            items: vec![verified_source(0.93)],
        };
        let out = decide(
            &req("quran", "premium", "is this halal fatwa?"),
            &DefaultModuleClassifier,
            &FixedSafety(SafetyRisk::ReligiousSensitive),
            &retriever,
            &StrictFormatter,
        );
        assert!(out.requires_scholar_review);
        assert!(out
            .answer
            .to_ascii_lowercase()
            .contains("qualified scholar"));
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[test]
    fn response_contract_includes_safety_and_source_metadata() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let retriever = CountingRetriever {
            calls: std::sync::Mutex::new(0),
            items: vec![verified_source(0.88)],
        };
        let out = decide(
            &req("quran", "premium", "quran q"),
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &retriever,
            &StrictFormatter,
        );
        assert!(!out.answer.is_empty());
        assert!(!out.language.is_empty());
        assert!(out.confidence > 0.0);
        assert!(!out.sources[0].content_hash.is_empty());
        assert!(!out.sources[0].retrieved_at.is_empty());
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }
}
