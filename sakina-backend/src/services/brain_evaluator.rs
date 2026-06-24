use crate::models::{
    BrainEvaluationReport, BrainRouteResponse, EvaluationCheckRequest, EvaluationCheckResponse,
};
use sqlx::PgPool;

#[derive(Debug, Clone, Default)]
pub struct BrainResponseEvaluator {
    pool: Option<PgPool>,
}

impl BrainResponseEvaluator {
    pub fn new() -> Self {
        Self { pool: None }
    }

    pub fn with_pool(pool: PgPool) -> Self {
        Self { pool: Some(pool) }
    }

    pub fn evaluate_value(
        &self,
        answer: &serde_json::Value,
        route: &BrainRouteResponse,
    ) -> BrainEvaluationReport {
        let answer_text = answer
            .get("answer")
            .and_then(|value| value.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let citations_present = answer
            .get("citations")
            .and_then(|value| value.as_array())
            .map(|items| !items.is_empty())
            .unwrap_or(false);
        let generated_from_verified_sources = answer
            .get("generated_from_verified_sources")
            .and_then(|value| value.as_bool())
            .unwrap_or(citations_present);
        let language_ok = answer
            .get("language")
            .and_then(|value| value.as_str())
            .map(|value| value.eq_ignore_ascii_case(&route.language))
            .unwrap_or(true);
        let escalation_needed =
            route.risk_level == "critical" || route.selected_agent == "Safety/Escalation Agent";
        let tone_ok = !answer_text.is_empty();
        let grounded = generated_from_verified_sources || route.rag_required;
        let evaluation_score = match (tone_ok, grounded, citations_present, language_ok) {
            (true, true, true, true) => 0.98,
            (true, true, _, true) => 0.91,
            (true, false, _, true) => 0.74,
            _ => 0.48,
        };
        let review_result = if escalation_needed {
            "FAIL".to_string()
        } else if evaluation_score >= 0.80 {
            "PASS".to_string()
        } else {
            "FAIL".to_string()
        };
        let reason = if escalation_needed {
            "route requires escalation".to_string()
        } else if !grounded {
            "answer is not sufficiently grounded in verified Islamic sources".to_string()
        } else if !language_ok {
            "answer language does not match detected user language".to_string()
        } else {
            "answer passed evaluation".to_string()
        };

        BrainEvaluationReport {
            evaluation_score,
            review_result,
            reason,
            citations_present,
            grounded_in_islamic_sources: grounded,
            escalation_needed,
            tone_ok,
            language_ok,
        }
    }

    pub fn evaluate_check(&self, request: &EvaluationCheckRequest) -> EvaluationCheckResponse {
        let answer_present = !request.answer.trim().is_empty();
        let citation_present = !request.citations.is_empty();
        let grounding_present = request
            .grounded_in_islamic_sources
            .unwrap_or(citation_present);
        let language_match = request.language.trim().eq_ignore_ascii_case("en")
            || request.language.trim().eq_ignore_ascii_case("ar");
        let escalation_needed = request
            .safety_level
            .as_deref()
            .map(|value| matches!(value.to_ascii_lowercase().as_str(), "critical" | "high"))
            .unwrap_or(false);
        let evaluation_score = match (
            answer_present,
            citation_present,
            grounding_present,
            language_match,
            escalation_needed,
        ) {
            (true, true, true, true, false) => 0.97,
            (true, true, true, false, false) => 0.72,
            (true, true, false, _, false) => 0.71,
            _ => 0.32,
        };
        let review_result =
            if answer_present && evaluation_score >= 0.80 && language_match && !escalation_needed {
                "PASS".to_string()
            } else {
                "FAIL".to_string()
            };
        let reason = if escalation_needed {
            "safety escalation required".to_string()
        } else if !answer_present {
            "answer text is required for verified delivery".to_string()
        } else if !citation_present {
            "citations are required for verified delivery".to_string()
        } else if !grounding_present {
            "answer is not grounded in verified Islamic sources".to_string()
        } else if !language_match {
            "answer language does not match requested language".to_string()
        } else {
            "answer passed evaluation".to_string()
        };

        EvaluationCheckResponse {
            evaluation_score,
            review_result,
            reason,
            citation_present,
            grounding_present,
            language_match,
            escalation_needed,
        }
    }

    pub fn record_check(
        &self,
        request: &EvaluationCheckRequest,
        response: &EvaluationCheckResponse,
    ) {
        if let Some(pool) = self.pool.clone() {
            let payload = serde_json::json!({
                "answer": request.answer,
                "citations": request.citations,
                "language": request.language,
                "response": response,
            });
            let request_id = uuid::Uuid::new_v4().to_string();
            let response = response.clone();
            let pool_clone = pool.clone();
            tokio::spawn(async move {
                let _ = sqlx::query(
                    r#"
                    INSERT INTO sakina_ai.brain_evaluation_results (
                        request_id, evaluation_score, review_result, reason, payload
                    )
                    VALUES ($1, $2, $3, $4, $5)
                    "#,
                )
                .bind(request_id)
                .bind(response.evaluation_score)
                .bind(&response.review_result)
                .bind(&response.reason)
                .bind(payload)
                .execute(&pool_clone)
                .await;
            });
        }
    }

    pub fn record_answer_evaluation(
        &self,
        request_id: &str,
        route: &BrainRouteResponse,
        report: &BrainEvaluationReport,
    ) {
        if let Some(pool) = self.pool.clone() {
            let payload = serde_json::json!({
                "route": route,
                "report": report,
            });
            let request_id = request_id.to_string();
            let report = report.clone();
            tokio::spawn(async move {
                let _ = sqlx::query(
                    r#"
                    INSERT INTO sakina_ai.brain_evaluation_results (
                        request_id, evaluation_score, review_result, reason, payload
                    )
                    VALUES ($1, $2, $3, $4, $5)
                    "#,
                )
                .bind(request_id)
                .bind(report.evaluation_score)
                .bind(&report.review_result)
                .bind(&report.reason)
                .bind(payload)
                .execute(&pool)
                .await;
            });
        }
    }
}
