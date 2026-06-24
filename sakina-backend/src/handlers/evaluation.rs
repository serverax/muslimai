use actix_web::{web, HttpResponse};
use uuid::Uuid;

use crate::models::{EvaluationCheckRequest, EvaluationCheckResponse};
use crate::services::BrainResponseEvaluator;

async fn citation_exists(pool: &sqlx::PgPool, citation: &str) -> Result<bool, sqlx::Error> {
    let citation = citation.trim();
    if citation.is_empty() {
        return Ok(false);
    }
    if let Ok(chunk_id) = Uuid::parse_str(citation) {
        return sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS (
                SELECT 1
                FROM sakina_ai.islamic_chunks c
                JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
                JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
                WHERE c.id = $1
                  AND c.review_status IN ('verified', 'approved')
                  AND d.review_status IN ('verified', 'approved')
                  AND s.review_status IN ('verified', 'approved')
            )
            "#,
        )
        .bind(chunk_id)
        .fetch_one(pool)
        .await;
    }

    sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS (
            SELECT 1
            FROM sakina_ai.islamic_chunks c
            JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE c.citation_text = $1
              AND c.review_status IN ('verified', 'approved')
              AND d.review_status IN ('verified', 'approved')
              AND s.review_status IN ('verified', 'approved')
        )
        OR EXISTS (
            SELECT 1
            FROM sakina_ai.knowledge_graph_entities e
            WHERE e.citation = $1
              AND e.reliability_level IN ('verified', 'approved', 'high')
        )
        "#,
    )
    .bind(citation)
    .fetch_one(pool)
    .await
}

async fn all_citations_exist(
    pool: &sqlx::PgPool,
    citations: &[String],
) -> Result<bool, sqlx::Error> {
    if citations.is_empty() {
        return Ok(false);
    }
    for citation in citations {
        if !citation_exists(pool, citation).await? {
            return Ok(false);
        }
    }
    Ok(true)
}

pub async fn check(
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<EvaluationCheckRequest>,
) -> HttpResponse {
    let evaluator = BrainResponseEvaluator::with_pool(pool.get_ref().clone());
    let request = payload.into_inner();
    let mut result: EvaluationCheckResponse = evaluator.evaluate_check(&request);
    match all_citations_exist(pool.get_ref(), &request.citations).await {
        Ok(true) => {}
        Ok(false) => {
            result.evaluation_score = result.evaluation_score.min(0.32);
            result.review_result = "FAIL".to_string();
            result.reason =
                "citation validator rejected missing or unverified source references".to_string();
            result.citation_present = false;
            result.grounding_present = false;
        }
        Err(_) => {
            result.evaluation_score = result.evaluation_score.min(0.32);
            result.review_result = "FAIL".to_string();
            result.reason = "citation validator could not verify source references".to_string();
            result.citation_present = false;
            result.grounding_present = false;
        }
    }
    evaluator.record_check(&request, &result);
    HttpResponse::Ok().json(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[actix_rt::test]
    async fn evaluation_check_passes_for_grounded_answer() {
        let evaluator = BrainResponseEvaluator::new();
        let body = evaluator.evaluate_check(&EvaluationCheckRequest {
            answer: "Grounded answer".to_string(),
            citations: vec!["Quran 2:153".to_string()],
            language: "en".to_string(),
            grounded_in_islamic_sources: Some(true),
            safety_level: Some("safe".to_string()),
            tone: Some("calm".to_string()),
        });
        assert_eq!(body.review_result, "PASS");
    }

    #[actix_rt::test]
    async fn evaluation_check_fails_without_citations() {
        let evaluator = BrainResponseEvaluator::new();
        let body = evaluator.evaluate_check(&EvaluationCheckRequest {
            answer: "Unverified answer".to_string(),
            citations: vec![],
            language: "en".to_string(),
            grounded_in_islamic_sources: Some(false),
            safety_level: Some("safe".to_string()),
            tone: Some("calm".to_string()),
        });
        assert_eq!(body.review_result, "FAIL");
    }
}
