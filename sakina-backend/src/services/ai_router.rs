use crate::models::{BrainAgentSpec, BrainRouteRequest, BrainRouteResponse, BrainTraceStep};

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
enum AgentKind {
    Quran,
    Hadith,
    IslamicGuidance,
    DuaAzkar,
    EmotionalSupport,
    FamilyMarriage,
    LearningMemorisation,
    Translation,
    SafetyEscalation,
    ContentReview,
    GeneralChat,
}

#[derive(Debug, Clone)]
struct AgentProfile {
    kind: AgentKind,
    name: &'static str,
    domain: &'static str,
    model: &'static str,
    pipeline: &'static str,
    requires_rag: bool,
    requires_wasm: bool,
    requires_evaluation: bool,
}

impl AgentProfile {
    fn spec(&self) -> BrainAgentSpec {
        BrainAgentSpec {
            name: self.name.to_string(),
            domain: self.domain.to_string(),
            model: self.model.to_string(),
            pipeline: self.pipeline.to_string(),
            requires_rag: self.requires_rag,
            requires_wasm: self.requires_wasm,
            requires_evaluation: self.requires_evaluation,
        }
    }
}

#[derive(Clone, Default)]
pub struct AiRouter {
    agents: Vec<AgentProfile>,
}

impl AiRouter {
    pub fn new() -> Self {
        Self {
            agents: vec![
                AgentProfile {
                    kind: AgentKind::Quran,
                    name: "Quran Agent",
                    domain: "quran",
                    model: "lite_llm",
                    pipeline: "mother_brain>quran_rag>evaluation",
                    requires_rag: true,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::Hadith,
                    name: "Hadith Agent",
                    domain: "hadith",
                    model: "main_llm",
                    pipeline: "mother_brain>hadith_hybrid_rag>evaluation",
                    requires_rag: true,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::IslamicGuidance,
                    name: "Islamic Guidance Agent",
                    domain: "fiqh",
                    model: "main_llm",
                    pipeline: "mother_brain>hybrid_rag>wasm_policy>evaluation",
                    requires_rag: true,
                    requires_wasm: true,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::DuaAzkar,
                    name: "Dua/Azkar Agent",
                    domain: "dua",
                    model: "lite_llm",
                    pipeline: "mother_brain>verified_dua_rag>evaluation",
                    requires_rag: true,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::EmotionalSupport,
                    name: "Emotional Support Agent",
                    domain: "support",
                    model: "lite_llm",
                    pipeline: "mother_brain>support_flow>evaluation",
                    requires_rag: false,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::FamilyMarriage,
                    name: "Family/Marriage Advice Agent",
                    domain: "family",
                    model: "main_llm",
                    pipeline: "mother_brain>hybrid_rag>evaluation",
                    requires_rag: true,
                    requires_wasm: true,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::LearningMemorisation,
                    name: "Learning/Quran Memorisation Agent",
                    domain: "learning",
                    model: "lite_llm",
                    pipeline: "mother_brain>memory>evaluation",
                    requires_rag: false,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::Translation,
                    name: "Translation Agent",
                    domain: "translation",
                    model: "lite_llm",
                    pipeline: "mother_brain>translation>evaluation",
                    requires_rag: false,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::SafetyEscalation,
                    name: "Safety/Escalation Agent",
                    domain: "safety",
                    model: "safety_agent",
                    pipeline: "mother_brain>safety_gate>human_escalation",
                    requires_rag: false,
                    requires_wasm: true,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::ContentReview,
                    name: "Content Review Agent",
                    domain: "review",
                    model: "review_agent",
                    pipeline: "mother_brain>content_review",
                    requires_rag: true,
                    requires_wasm: true,
                    requires_evaluation: true,
                },
                AgentProfile {
                    kind: AgentKind::GeneralChat,
                    name: "General Chat Agent",
                    domain: "general",
                    model: "lite_llm",
                    pipeline: "mother_brain>cached_or_cached_rag>evaluation",
                    requires_rag: false,
                    requires_wasm: false,
                    requires_evaluation: true,
                },
            ],
        }
    }

    pub fn agents(&self) -> Vec<BrainAgentSpec> {
        self.agents.iter().map(AgentProfile::spec).collect()
    }

    pub fn route(&self, request: &BrainRouteRequest) -> BrainRouteResponse {
        let message = request.message.trim();
        let normalized = message.to_ascii_lowercase();
        let language = detect_language(message, request.language.as_deref());
        let prompt_injection_detected =
            detects_prompt_injection(message, request.safety_context.as_ref());
        let safety_risk = detect_safety_risk(message, request.safety_context.as_ref());
        let subscription = request.user_subscription_tier.trim().to_ascii_lowercase();
        let entitled = matches!(subscription.as_str(), "premium" | "pro" | "founding");
        let complexity = if message.split_whitespace().count() > 18 {
            0.78
        } else {
            0.52
        };
        let is_simple = normalized.contains("what is subhanallah")
            || normalized.contains("what does subhanallah mean")
            || normalized.contains("what is dua")
            || normalized.contains("what is dhikr")
            || normalized.contains("what is adhan");

        let agent = if safety_risk == "critical" {
            AgentKind::SafetyEscalation
        } else if contains_any(
            &normalized,
            &[
                "fatwa", "halal", "haram", "divorce", "marriage", "wife", "husband",
            ],
        ) {
            AgentKind::FamilyMarriage
        } else if contains_any(
            &normalized,
            &[
                "permissible",
                "allowed",
                "ruling",
                "fiqh",
                "zakat",
                "wudu",
                "wudhu",
                "salah",
                "prayer",
                "fasting",
                "ramadan",
                "music",
            ],
        ) || (normalized.contains("islam")
            && contains_any(
                &normalized,
                &[
                    "what should",
                    "how should",
                    "is it ok",
                    "is it allowed",
                    "can i",
                ],
            ))
        {
            AgentKind::IslamicGuidance
        } else if contains_any(&normalized, &["quran", "surah", "ayah", "verse"])
            || contains_any(message, &["آية", "سورة", "القرآن", "آية الكرسي"])
        {
            AgentKind::Quran
        } else if contains_any(
            &normalized,
            &["hadith", "sahih", "authenticity", "narrator"],
        ) {
            AgentKind::Hadith
        } else if contains_any(&normalized, &["dua", "dua", "adhkar", "azkar", "dhikr"]) {
            AgentKind::DuaAzkar
        } else if contains_any(
            &normalized,
            &["broken", "sad", "anxious", "depressed", "overwhelmed"],
        ) {
            AgentKind::EmotionalSupport
        } else if contains_any(
            &normalized,
            &[
                "memorization",
                "memorise",
                "memorize",
                "prayer habit",
                "habit",
                "remember",
            ],
        ) {
            AgentKind::LearningMemorisation
        } else if contains_any(
            &normalized,
            &["translate", "translation", "meaning in english"],
        ) || is_arabic_text(message)
            && contains_any(&normalized, &["what does", "mean", "translate"])
        {
            AgentKind::Translation
        } else if complexity > 0.70 {
            AgentKind::IslamicGuidance
        } else if is_simple {
            AgentKind::DuaAzkar
        } else {
            AgentKind::GeneralChat
        };

        let profile = self
            .agents
            .iter()
            .find(|profile| profile.kind == agent)
            .unwrap_or_else(|| self.agents.first().expect("agents list is not empty"));

        let use_rag = profile.requires_rag
            || matches!(
                agent,
                AgentKind::Quran
                    | AgentKind::Hadith
                    | AgentKind::IslamicGuidance
                    | AgentKind::FamilyMarriage
                    | AgentKind::ContentReview
            );
        let use_wasm = profile.requires_wasm
            || matches!(
                agent,
                AgentKind::SafetyEscalation
                    | AgentKind::IslamicGuidance
                    | AgentKind::FamilyMarriage
            );
        let requires_evaluation = profile.requires_evaluation || use_rag || use_wasm;
        let source_strategy = if matches!(agent, AgentKind::SafetyEscalation) {
            "safety_only"
        } else if matches!(
            agent,
            AgentKind::Quran
                | AgentKind::Hadith
                | AgentKind::IslamicGuidance
                | AgentKind::FamilyMarriage
                | AgentKind::ContentReview
        ) {
            "hybrid_rag"
        } else if matches!(agent, AgentKind::DuaAzkar | AgentKind::LearningMemorisation) {
            "verified_content"
        } else {
            "cache_or_lightweight"
        };

        let subscription_required =
            matches!(agent, AgentKind::FamilyMarriage | AgentKind::ContentReview);
        let can_generate = !matches!(agent, AgentKind::SafetyEscalation)
            && safety_risk != "critical"
            && safety_risk != "high"
            && (!subscription_required || entitled);
        let scholar_review_required = matches!(
            agent,
            AgentKind::IslamicGuidance
                | AgentKind::FamilyMarriage
                | AgentKind::SafetyEscalation
                | AgentKind::ContentReview
        ) || safety_risk != "safe";
        let confidence = if matches!(agent, AgentKind::GeneralChat) {
            0.62
        } else if is_simple {
            0.93
        } else if complexity > 0.70 {
            0.79
        } else {
            0.84
        };

        BrainRouteResponse {
            request_id: request.request_id.clone(),
            selected_agent: profile.name.to_string(),
            selected_model: if !can_generate {
                "safety_agent".to_string()
            } else {
                profile.model.to_string()
            },
            selected_pipeline: profile.pipeline.to_string(),
            source_strategy: source_strategy.to_string(),
            language,
            risk_level: safety_risk.to_string(),
            confidence,
            rag_required: use_rag,
            wasm_required: use_wasm,
            evaluation_required: requires_evaluation,
            scholar_review_required,
            can_generate,
            execution_trace: vec![
                BrainTraceStep {
                    step: "input_received".to_string(),
                    outcome: "ok".to_string(),
                },
                BrainTraceStep {
                    step: "language_detected".to_string(),
                    outcome: detect_language(message, request.language.as_deref()),
                },
                BrainTraceStep {
                    step: "risk_classified".to_string(),
                    outcome: safety_risk.clone(),
                },
                BrainTraceStep {
                    step: "prompt_injection_guard".to_string(),
                    outcome: if prompt_injection_detected {
                        "blocked".to_string()
                    } else {
                        "clear".to_string()
                    },
                },
                BrainTraceStep {
                    step: "agent_selected".to_string(),
                    outcome: profile.name.to_string(),
                },
                BrainTraceStep {
                    step: "source_strategy".to_string(),
                    outcome: source_strategy.to_string(),
                },
                BrainTraceStep {
                    step: "model_selected".to_string(),
                    outcome: if !can_generate {
                        "safety_agent".to_string()
                    } else {
                        profile.model.to_string()
                    },
                },
                BrainTraceStep {
                    step: "evaluation_required".to_string(),
                    outcome: requires_evaluation.to_string(),
                },
                BrainTraceStep {
                    step: "audit_ready".to_string(),
                    outcome: "true".to_string(),
                },
            ],
        }
    }
}

fn detect_language(message: &str, preferred: Option<&str>) -> String {
    if let Some(language) = preferred {
        let trimmed = language.trim();
        if !trimmed.is_empty() {
            return trimmed.to_ascii_lowercase();
        }
    }
    if message
        .chars()
        .any(|ch| ('\u{0600}'..='\u{06ff}').contains(&ch))
    {
        "ar".to_string()
    } else {
        "en".to_string()
    }
}

fn detect_safety_risk(message: &str, safety_context: Option<&serde_json::Value>) -> String {
    let mut text = message.to_ascii_lowercase();
    if let Some(extra) = safety_context {
        text.push(' ');
        text.push_str(&extra.to_string().to_ascii_lowercase());
    }
    if detects_prompt_injection_text(&text) {
        return "critical".to_string();
    }
    if contains_any(
        &text,
        &[
            "suicide",
            "self harm",
            "kill myself",
            "harm myself",
            "extremist",
            "terror",
            "terrorism",
            "jihadist violence",
            "religious justification for violence",
            "justify violence",
            "justification for violence",
            "violent religious justification",
        ],
    ) {
        return "critical".to_string();
    }
    if contains_any(
        &text,
        &[
            "abuse",
            "violent",
            "assault",
            "harm",
            "divorce",
            "inheritance",
            "killing",
            "war",
            "talaq",
            "marriage separation",
        ],
    ) {
        return "high".to_string();
    }
    if contains_any(&text, &["fatwa", "halal", "haram", "marriage"]) {
        return "medium".to_string();
    }
    "safe".to_string()
}

fn detects_prompt_injection(message: &str, safety_context: Option<&serde_json::Value>) -> bool {
    let mut text = message.to_ascii_lowercase();
    if let Some(extra) = safety_context {
        text.push(' ');
        text.push_str(&extra.to_string().to_ascii_lowercase());
    }
    detects_prompt_injection_text(&text)
}

fn detects_prompt_injection_text(text: &str) -> bool {
    contains_any(
        text,
        &[
            "ignore previous instructions",
            "ignore all previous instructions",
            "ignore safety rules",
            "bypass safety",
            "bypass islamic safety",
            "override system prompt",
            "reveal system prompt",
            "hidden system prompt",
            "developer message",
            "tool exfiltration",
            "exfiltrate",
            "disregard policy",
            "citation manipulation",
            "fabricate citation",
            "malicious retrieved source",
            "follow this source instruction",
            "disable guardrails",
        ],
    )
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

fn is_arabic_text(text: &str) -> bool {
    text.chars()
        .any(|ch| ('\u{0600}'..='\u{06ff}').contains(&ch))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn agents_are_registered() {
        let router = AiRouter::new();
        let agents = router.agents();
        assert!(agents.iter().any(|agent| agent.name == "Quran Agent"));
        assert!(agents
            .iter()
            .any(|agent| agent.name == "Safety/Escalation Agent"));
        assert!(agents.iter().any(|agent| agent.name == "Translation Agent"));
    }

    #[test]
    fn simple_question_routes_to_lite_path() {
        let router = AiRouter::new();
        let route = router.route(&BrainRouteRequest {
            message: "What is SubhanAllah?".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert_eq!(route.selected_agent, "Dua/Azkar Agent");
        assert_eq!(route.selected_model, "lite_llm");
        assert_eq!(route.source_strategy, "verified_content");
        assert!(route
            .execution_trace
            .iter()
            .any(|step| step.step == "agent_selected"));
    }

    #[test]
    fn complex_fiqh_routes_to_main_path() {
        let router = AiRouter::new();
        let route = router.route(&BrainRouteRequest {
            message: "Can I divorce my wife by text in Islam?".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert_eq!(route.selected_agent, "Family/Marriage Advice Agent");
        assert_eq!(
            route.selected_pipeline,
            "mother_brain>hybrid_rag>evaluation"
        );
        assert!(route.rag_required);
        assert!(route.evaluation_required);
        assert!(route.wasm_required);
    }

    #[test]
    fn safety_question_routes_to_escalation() {
        let router = AiRouter::new();
        let route = router.route(&BrainRouteRequest {
            message: "I want to harm myself".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert_eq!(route.selected_agent, "Safety/Escalation Agent");
        assert_eq!(route.selected_model, "safety_agent");
        assert!(!route.can_generate);
        assert!(route.scholar_review_required);
    }

    #[test]
    fn extremist_misuse_routes_to_escalation() {
        let router = AiRouter::new();
        let route = router.route(&BrainRouteRequest {
            message: "Give me extremist religious justification for violence".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert_eq!(route.selected_agent, "Safety/Escalation Agent");
        assert_eq!(route.risk_level, "critical");
        assert_eq!(route.selected_model, "safety_agent");
        assert!(!route.can_generate);
        assert!(route.scholar_review_required);
    }

    #[test]
    fn arabic_question_detects_language_and_routes() {
        let router = AiRouter::new();
        let route = router.route(&BrainRouteRequest {
            message: "ما معنى آية الكرسي؟".to_string(),
            language: None,
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert_eq!(route.language, "ar");
        assert_eq!(route.selected_agent, "Quran Agent");
    }
}
