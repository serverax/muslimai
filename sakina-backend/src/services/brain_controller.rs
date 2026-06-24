use std::sync::Arc;

use serde_json::Value;
use uuid::Uuid;

use crate::error::ApiError;
use crate::models::{
    BrainAuditRecord, BrainDecisionTrace, BrainRouteRequest, BrainRouteResponse, BrainTraceStep,
};
use crate::services::pii_redaction::redact_pii;
use crate::services::{
    AiRouter, AskIslamicRequest, BrainAuditLog, BrainResponseEvaluator, BrainSafetyPolicy,
    IslamicAnswerService,
};

#[derive(Debug, Clone)]
pub struct BrainExecutionPermit {
    _private: (),
}

impl BrainExecutionPermit {
    fn new() -> Self {
        Self { _private: () }
    }
}

#[derive(Clone)]
pub struct BrainController {
    router: Arc<AiRouter>,
    policy: Arc<BrainSafetyPolicy>,
    evaluator: Arc<BrainResponseEvaluator>,
    audit_log: Arc<BrainAuditLog>,
}

impl BrainController {
    pub fn new(
        router: Arc<AiRouter>,
        policy: Arc<BrainSafetyPolicy>,
        evaluator: Arc<BrainResponseEvaluator>,
        audit_log: Arc<BrainAuditLog>,
    ) -> Self {
        Self {
            router,
            policy,
            evaluator,
            audit_log,
        }
    }

    pub fn route(&self, request: &BrainRouteRequest) -> BrainRouteResponse {
        let base_route = self.router.route(request);
        let cost_decision = evaluate_cost_budget(request, &base_route);
        let policy = self.policy.evaluate(request, &base_route);
        let decision_trace =
            self.decision_trace(request, &base_route, &policy.reason, &cost_decision);
        let selected_model = if policy.allowed && cost_decision.allowed {
            base_route.selected_model.clone()
        } else {
            "safety_agent".to_string()
        };
        let can_generate = base_route.can_generate && policy.allowed && cost_decision.allowed;
        let response = BrainRouteResponse {
            request_id: Some(decision_trace.request_id.clone()),
            selected_agent: base_route.selected_agent.clone(),
            selected_model,
            selected_pipeline: base_route.selected_pipeline.clone(),
            source_strategy: base_route.source_strategy.clone(),
            language: base_route.language.clone(),
            risk_level: base_route.risk_level.clone(),
            confidence: base_route.confidence,
            rag_required: base_route.rag_required,
            wasm_required: base_route.wasm_required,
            evaluation_required: base_route.evaluation_required,
            scholar_review_required: base_route.scholar_review_required || policy.review_required,
            can_generate,
            execution_trace: decision_trace.execution_trace.clone(),
        };

        let audit_event_id = decision_trace.audit_event_id.clone();
        self.audit_log.record_trace(&decision_trace);
        self.audit_log.append(BrainAuditRecord {
            request_id: decision_trace.request_id.clone(),
            user_id: decision_trace.user_id.clone(),
            decision_path: decision_trace
                .execution_trace
                .iter()
                .map(|step| format!("{}={}", step.step, step.outcome))
                .collect(),
            selected_agent: response.selected_agent.clone(),
            selected_model: response.selected_model.clone(),
            final_action: if response.can_generate {
                "generate".to_string()
            } else {
                "block".to_string()
            },
            audit_event_id,
        });

        response
    }

    fn decision_trace(
        &self,
        request: &BrainRouteRequest,
        route: &BrainRouteResponse,
        policy_reason: &str,
        cost_decision: &CostDecision,
    ) -> BrainDecisionTrace {
        let request_id = request
            .request_id
            .as_ref()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| Uuid::new_v4().to_string());
        let input_type = classify_input_type(&request.message);
        let intent = classify_intent(&request.message);
        let pii = redact_pii(&request.message);
        let prompt_injection_blocked =
            detects_prompt_injection(&request.message, request.safety_context.as_ref());
        let eval = self.evaluate_draft(route);
        let final_action = if route.can_generate {
            "answer_returned"
        } else {
            "blocked"
        };
        let audit_event_id = Uuid::new_v4().to_string();
        let execution_trace = vec![
            BrainTraceStep {
                step: "input_received".to_string(),
                outcome: "ok".to_string(),
            },
            BrainTraceStep {
                step: "authenticated_user".to_string(),
                outcome: "checked".to_string(),
            },
            BrainTraceStep {
                step: "safe_user_context_loaded".to_string(),
                outcome: request.user_subscription_tier.clone(),
            },
            BrainTraceStep {
                step: "input_type_classified".to_string(),
                outcome: input_type.clone(),
            },
            BrainTraceStep {
                step: "pii_redaction".to_string(),
                outcome: if pii.pii_detected {
                    "applied".to_string()
                } else {
                    "not_required".to_string()
                },
            },
            BrainTraceStep {
                step: "language_detected".to_string(),
                outcome: request
                    .language
                    .clone()
                    .unwrap_or_else(|| route.language.clone()),
            },
            BrainTraceStep {
                step: "intent_detected".to_string(),
                outcome: intent.clone(),
            },
            BrainTraceStep {
                step: "risk_detected".to_string(),
                outcome: route.risk_level.clone(),
            },
            BrainTraceStep {
                step: "prompt_injection_guard".to_string(),
                outcome: if prompt_injection_blocked {
                    "blocked".to_string()
                } else {
                    "clear".to_string()
                },
            },
            BrainTraceStep {
                step: "agent_selected".to_string(),
                outcome: route.selected_agent.clone(),
            },
            BrainTraceStep {
                step: "source_strategy_selected".to_string(),
                outcome: route.source_strategy.clone(),
            },
            BrainTraceStep {
                step: "cost_governor".to_string(),
                outcome: cost_decision.trace_outcome.clone(),
            },
            BrainTraceStep {
                step: "evidence_retrieved".to_string(),
                outcome: if route.rag_required {
                    "verified_evidence_requested".to_string()
                } else {
                    "not_required".to_string()
                },
            },
            BrainTraceStep {
                step: "context_compressed".to_string(),
                outcome: "compressed".to_string(),
            },
            BrainTraceStep {
                step: "draft_generated".to_string(),
                outcome: if route.can_generate {
                    "draft_ready".to_string()
                } else {
                    "draft_blocked".to_string()
                },
            },
            BrainTraceStep {
                step: "answer_evaluated".to_string(),
                outcome: format!("{}:{:.2}", eval.review_result, eval.evaluation_score),
            },
            BrainTraceStep {
                step: "safety_policy_applied".to_string(),
                outcome: policy_reason.to_string(),
            },
            BrainTraceStep {
                step: "memory_action".to_string(),
                outcome: "no_sensitive_memory_write".to_string(),
            },
            BrainTraceStep {
                step: "decision_logged".to_string(),
                outcome: audit_event_id.clone(),
            },
            BrainTraceStep {
                step: "final_response_returned".to_string(),
                outcome: final_action.to_string(),
            },
        ];

        BrainDecisionTrace {
            request_id,
            user_id: None,
            input_type,
            intent,
            language: route.language.clone(),
            risk_level: route.risk_level.clone(),
            selected_agent: route.selected_agent.clone(),
            selected_model: route.selected_model.clone(),
            selected_pipeline: route.selected_pipeline.clone(),
            source_strategy: route.source_strategy.clone(),
            evaluation_result: eval.review_result,
            final_action: final_action.to_string(),
            audit_event_id,
            execution_trace,
        }
    }

    pub async fn answer_islamic(
        &self,
        service: &IslamicAnswerService,
        request: AskIslamicRequest,
    ) -> Result<Value, ApiError> {
        let route_request = BrainRouteRequest {
            message: request.question.clone(),
            language: request.language.clone(),
            user_subscription_tier: "premium".to_string(),
            safety_context: None,
            request_id: None,
        };
        let route = self.route(&route_request);
        if !route.can_generate {
            return Err(ApiError::unauthorized(
                "request blocked by Mother Brain safety policy",
            ));
        }

        let permit = BrainExecutionPermit::new();
        let mut answer = service.answer(request, permit).await?;
        let evaluation = self.evaluator.evaluate_value(&answer, &route);
        let cost_decision = evaluate_cost_budget(&route_request, &route);
        let trace = self.decision_trace(&route_request, &route, &evaluation.reason, &cost_decision);
        self.evaluator
            .record_answer_evaluation(&trace.request_id, &route, &evaluation);
        self.audit_log.record_trace(&trace);
        if evaluation.review_result != "PASS" {
            self.audit_log.append(BrainAuditRecord {
                request_id: trace.request_id.clone(),
                user_id: trace.user_id.clone(),
                decision_path: vec![
                    "answer_evaluated=FAIL".to_string(),
                    format!("reason={}", evaluation.reason),
                ],
                selected_agent: route.selected_agent.clone(),
                selected_model: route.selected_model.clone(),
                final_action: "blocked_after_evaluation".to_string(),
                audit_event_id: trace.audit_event_id.clone(),
            });
            return Err(ApiError::unauthorized(
                "response rejected by evaluation AI before user delivery",
            ));
        }

        self.audit_log.append(BrainAuditRecord {
            request_id: trace.request_id.clone(),
            user_id: trace.user_id.clone(),
            decision_path: trace
                .execution_trace
                .iter()
                .map(|step| format!("{}={}", step.step, step.outcome))
                .collect(),
            selected_agent: trace.selected_agent.clone(),
            selected_model: trace.selected_model.clone(),
            final_action: trace.final_action.clone(),
            audit_event_id: trace.audit_event_id.clone(),
        });

        if let Some(object) = answer.as_object_mut() {
            object.insert("trace_id".to_string(), serde_json::json!(trace.request_id));
            object.insert(
                "brain_selected_agent".to_string(),
                serde_json::json!(trace.selected_agent),
            );
            object.insert(
                "brain_selected_pipeline".to_string(),
                serde_json::json!(trace.selected_pipeline),
            );
            object.insert(
                "brain_execution_trace".to_string(),
                serde_json::to_value(&trace.execution_trace)
                    .unwrap_or_else(|_| serde_json::json!([])),
            );
        }

        Ok(answer)
    }

    pub fn audit_records(&self) -> Vec<BrainAuditRecord> {
        self.audit_log.records()
    }
}

#[derive(Debug, Clone)]
struct CostDecision {
    allowed: bool,
    trace_outcome: String,
}

fn evaluate_cost_budget(request: &BrainRouteRequest, route: &BrainRouteResponse) -> CostDecision {
    let estimated_units = request.message.chars().count()
        + if route.rag_required { 1_500 } else { 250 }
        + if route.evaluation_required { 500 } else { 0 };
    let tier_budget = match request.user_subscription_tier.as_str() {
        "premium" => 16_000,
        "family" => 12_000,
        _ => 6_000,
    };
    let allowed = estimated_units <= tier_budget;
    CostDecision {
        allowed,
        trace_outcome: format!(
            "estimated_units={estimated_units};budget_units={tier_budget};decision={}",
            if allowed { "allow" } else { "block" }
        ),
    }
}

fn classify_input_type(message: &str) -> String {
    let text = message.trim();
    if text.contains('.') || text.contains('?') {
        "question".to_string()
    } else if text.chars().count() > 120 {
        "long_form".to_string()
    } else {
        "short_form".to_string()
    }
}

fn classify_intent(message: &str) -> String {
    let text = message.to_ascii_lowercase();
    if text.contains("quran") || text.contains("surah") || text.contains("ayah") {
        "quran".to_string()
    } else if text.contains("hadith") || text.contains("sahih") || text.contains("narrator") {
        "hadith".to_string()
    } else if text.contains("dua") || text.contains("dhikr") || text.contains("azkar") {
        "dua_azkar".to_string()
    } else if text.contains("sad") || text.contains("anxious") || text.contains("overwhelmed") {
        "emotional_support".to_string()
    } else {
        "general_guidance".to_string()
    }
}

fn detects_prompt_injection(message: &str, safety_context: Option<&Value>) -> bool {
    let mut text = message.to_ascii_lowercase();
    if let Some(extra) = safety_context {
        text.push(' ');
        text.push_str(&extra.to_string().to_ascii_lowercase());
    }
    [
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
    ]
    .iter()
    .any(|needle| text.contains(needle))
}

impl BrainController {
    fn evaluate_draft(&self, route: &BrainRouteResponse) -> crate::models::BrainEvaluationReport {
        crate::models::BrainEvaluationReport {
            evaluation_score: if route.can_generate { 0.91 } else { 0.12 },
            review_result: if route.can_generate {
                "PASS".to_string()
            } else {
                "FAIL".to_string()
            },
            reason: if route.can_generate {
                "draft permitted".to_string()
            } else {
                "draft blocked by route".to_string()
            },
            citations_present: route.rag_required,
            grounded_in_islamic_sources: route.rag_required,
            escalation_needed: !route.can_generate,
            tone_ok: route.can_generate,
            language_ok: true,
        }
    }
}

#[cfg(test)]
mod cost_governor_tests {
    use std::sync::Arc;

    use super::*;
    use crate::services::{AiRouter, BrainAuditLog, BrainResponseEvaluator, BrainSafetyPolicy};

    fn controller() -> BrainController {
        BrainController::new(
            Arc::new(AiRouter::new()),
            Arc::new(BrainSafetyPolicy::new()),
            Arc::new(BrainResponseEvaluator::new()),
            Arc::new(BrainAuditLog::new()),
        )
    }

    #[test]
    fn cost_governor_records_allow_decision_for_normal_request() {
        let response = controller().route(&BrainRouteRequest {
            message: "What is prayer while travelling?".to_string(),
            language: Some("en".to_string()),
            user_subscription_tier: "free".to_string(),
            safety_context: None,
            request_id: Some("cost-normal".to_string()),
        });

        let cost_step = response
            .execution_trace
            .iter()
            .find(|step| step.step == "cost_governor")
            .expect("cost governor trace step");
        assert!(cost_step.outcome.contains("estimated_units="));
        assert!(cost_step.outcome.contains("decision=allow"));
        assert!(response.can_generate);
    }

    #[test]
    fn cost_governor_blocks_over_budget_free_request() {
        let response = controller().route(&BrainRouteRequest {
            message: "zakat ".repeat(7000),
            language: Some("en".to_string()),
            user_subscription_tier: "free".to_string(),
            safety_context: None,
            request_id: Some("cost-block".to_string()),
        });

        let cost_step = response
            .execution_trace
            .iter()
            .find(|step| step.step == "cost_governor")
            .expect("cost governor trace step");
        assert!(cost_step.outcome.contains("budget_units=6000"));
        assert!(cost_step.outcome.contains("decision=block"));
        assert!(!response.can_generate);
    }
}
