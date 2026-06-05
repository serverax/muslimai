use std::sync::Arc;

use crate::error::ApiError;
use crate::models::{
    BrainAgentSpec, BrainRouteRequest, BrainRouteResponse, ClassifyRequest, DecisionRequest,
    DecisionResponse,
};
use crate::services::brain_controller::BrainController;
use crate::services::decision_algorithm::{
    decide, DefaultModuleClassifier, DefaultSafetyClassifier, EmptyRetriever, StrictFormatter,
};
use crate::services::semantic_router::{ClassifyResult, SemanticRouter};
use crate::services::{BrainAuditLog, BrainResponseEvaluator, BrainSafetyPolicy};

#[derive(Clone)]
pub struct AiaOrchestrator {
    semantic_router: Arc<SemanticRouter>,
    brain_router: Arc<crate::services::AiRouter>,
    brain_controller: Arc<BrainController>,
}

impl AiaOrchestrator {
    pub fn new(router: Arc<SemanticRouter>) -> Self {
        let ai_router = Arc::new(crate::services::AiRouter::new());
        let policy = Arc::new(BrainSafetyPolicy::new());
        let evaluator = Arc::new(BrainResponseEvaluator::new());
        let audit_log = Arc::new(BrainAuditLog::new());
        Self {
            semantic_router: router,
            brain_router: ai_router.clone(),
            brain_controller: Arc::new(BrainController::new(
                ai_router, policy, evaluator, audit_log,
            )),
        }
    }

    pub fn new_with_pool(router: Arc<SemanticRouter>, pool: sqlx::PgPool) -> Self {
        let ai_router = Arc::new(crate::services::AiRouter::new());
        let policy = Arc::new(BrainSafetyPolicy::new());
        let evaluator = Arc::new(BrainResponseEvaluator::with_pool(pool.clone()));
        let audit_log = Arc::new(BrainAuditLog::with_pool(pool));
        Self {
            semantic_router: router,
            brain_router: ai_router.clone(),
            brain_controller: Arc::new(BrainController::new(
                ai_router, policy, evaluator, audit_log,
            )),
        }
    }

    pub fn agents(&self) -> Vec<BrainAgentSpec> {
        self.brain_router.agents()
    }

    pub fn route(&self, request: &BrainRouteRequest) -> BrainRouteResponse {
        self.brain_controller.route(request)
    }

    pub async fn classify(&self, text: &str) -> Result<ClassifyResult, ApiError> {
        let brain_route = self.brain_controller.route(&BrainRouteRequest {
            message: text.to_string(),
            language: None,
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        let result = self
            .semantic_router
            .classify(text)
            .await
            .map_err(|_| ApiError::internal("failed to classify request"))?;
        Ok(ClassifyResult {
            intent: result.intent,
            confidence: result.confidence.max(brain_route.confidence),
            routing_decision: brain_route.selected_pipeline,
        })
    }

    pub async fn classify_request(
        &self,
        request: &ClassifyRequest,
    ) -> Result<ClassifyResult, ApiError> {
        self.classify(&request.text).await
    }

    pub fn decide(&self, request: &DecisionRequest) -> DecisionResponse {
        let route = self.route(&BrainRouteRequest {
            message: request.question.clone(),
            language: Some(request.language.clone()),
            user_subscription_tier: request.user_subscription_tier.clone(),
            safety_context: request.safety_context.clone(),
            request_id: None,
        });
        let mut response = decide(
            request,
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &EmptyRetriever,
            &StrictFormatter,
        );
        response.answer = if route.can_generate {
            response.answer
        } else {
            "Request routed to safety or review flow by the Mother Brain controller.".to_string()
        };
        response
    }

    pub fn route_trace(&self, request: &BrainRouteRequest) -> BrainRouteResponse {
        self.route(request)
    }

    pub async fn answer_islamic(
        &self,
        service: &crate::services::IslamicAnswerService,
        request: crate::services::AskIslamicRequest,
    ) -> Result<serde_json::Value, ApiError> {
        self.brain_controller.answer_islamic(service, request).await
    }

    pub fn audit_records(&self) -> Vec<crate::models::BrainAuditRecord> {
        self.brain_controller.audit_records()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn classify_routes_through_mother_brain_layer() {
        let orchestrator = AiaOrchestrator::new(Arc::new(SemanticRouter::new()));
        let result = orchestrator
            .classify("Is music permissible in Islam?")
            .await
            .expect("classification");
        assert_eq!(
            result.routing_decision,
            "mother_brain>hybrid_rag>wasm_policy>evaluation"
        );
    }

    #[test]
    fn decision_routes_through_mother_brain_layer() {
        let orchestrator = AiaOrchestrator::new(Arc::new(SemanticRouter::new()));
        let request = DecisionRequest {
            question: "What is zakat?".to_string(),
            selected_module: "knowledge".to_string(),
            language: "en".to_string(),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
        };
        let response = orchestrator.decide(&request);
        let expected = decide(
            &request,
            &DefaultModuleClassifier,
            &DefaultSafetyClassifier,
            &EmptyRetriever,
            &StrictFormatter,
        );
        assert_eq!(response.module, expected.module);
        assert_eq!(response.language, expected.language);
        assert_eq!(response.review_status, expected.review_status);
    }

    #[test]
    fn unsafe_question_is_blocked_centrally() {
        let orchestrator = AiaOrchestrator::new(Arc::new(SemanticRouter::new()));
        let route = orchestrator.route(&BrainRouteRequest {
            message: "I want to harm myself".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert_eq!(route.selected_agent, "Safety/Escalation Agent");
        assert!(!route.can_generate);
        assert!(route.scholar_review_required);
        assert!(route
            .execution_trace
            .iter()
            .any(|step| step.step == "risk_detected"));
    }

    #[test]
    fn brain_trace_contains_full_execution_path() {
        let orchestrator = AiaOrchestrator::new(Arc::new(SemanticRouter::new()));
        let route = orchestrator.route(&BrainRouteRequest {
            message: "Explain Surah Al-Mulk".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        });
        assert!(route.execution_trace.len() >= 17);
        assert!(route
            .execution_trace
            .iter()
            .any(|step| step.step == "final_response_returned"));
    }
}
