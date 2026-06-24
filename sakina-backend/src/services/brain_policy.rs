use crate::models::{BrainRouteRequest, BrainRouteResponse, SafetyRisk};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BrainPolicyDecision {
    pub allowed: bool,
    pub requires_escalation: bool,
    pub memory_allowed: bool,
    pub review_required: bool,
    pub reason: String,
}

#[derive(Debug, Default, Clone)]
pub struct BrainSafetyPolicy;

impl BrainSafetyPolicy {
    pub fn new() -> Self {
        Self
    }

    pub fn evaluate(
        &self,
        request: &BrainRouteRequest,
        route: &BrainRouteResponse,
    ) -> BrainPolicyDecision {
        let tier = request.user_subscription_tier.trim().to_ascii_lowercase();
        let subscription_allowed = matches!(tier.as_str(), "premium" | "pro" | "founding");
        let high_risk = matches!(route.risk_level.as_str(), "critical" | "high");
        let review_required = route.scholar_review_required
            || matches!(route.risk_level.as_str(), "medium" | "high" | "critical");

        if !subscription_allowed
            && matches!(
                route.selected_agent.as_str(),
                "Family/Marriage Advice Agent" | "Content Review Agent"
            )
        {
            return BrainPolicyDecision {
                allowed: false,
                requires_escalation: false,
                memory_allowed: false,
                review_required,
                reason: "subscription tier does not allow this routed capability".to_string(),
            };
        }

        if route.selected_agent == "Safety/Escalation Agent" || high_risk {
            return BrainPolicyDecision {
                allowed: false,
                requires_escalation: true,
                memory_allowed: false,
                review_required: true,
                reason: "safety policy requires escalation".to_string(),
            };
        }

        BrainPolicyDecision {
            allowed: route.can_generate,
            requires_escalation: false,
            memory_allowed: !matches!(route.risk_level.as_str(), "critical" | "high"),
            review_required,
            reason: if route.can_generate {
                "policy allows generation".to_string()
            } else {
                "routing decision blocked generation".to_string()
            },
        }
    }

    pub fn classify_risk_level(&self, route: &BrainRouteResponse) -> SafetyRisk {
        match route.risk_level.as_str() {
            "critical" => SafetyRisk::CrisisSensitive,
            "high" => SafetyRisk::ReligiousSensitive,
            "medium" => SafetyRisk::ReligiousSensitive,
            _ => SafetyRisk::Safe,
        }
    }
}
