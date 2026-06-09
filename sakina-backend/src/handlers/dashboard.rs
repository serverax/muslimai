use actix_web::{web, HttpRequest, HttpResponse};
use serde_json::json;
use sqlx::{PgPool, Row};

use crate::error::ApiError;

/// Real guardrail / safety-event feed for the dashboard.
///
/// Fails closed: requires an authenticated user (valid JWT/session) and only
/// returns real rows from `sakina_ai.safety_classifications`. No data is ever
/// fabricated — if no rows exist the response is an honest empty list.
pub async fn get_guardrails(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    // Authenticate first; unauthenticated callers get no dashboard data.
    let _user_id = crate::services::auth::authenticated_user_id(&req, pool.get_ref()).await?;

    let rows = sqlx::query(
        r#"
        SELECT
            sc.created_at::text AS timestamp,
            sc.request_id::text AS request_id,
            sc.user_id::text AS user_id,
            sc.safety_level AS safety_level,
            sc.islamic_sensitivity AS islamic_sensitivity,
            sc.classifier_version AS classifier_version
        FROM sakina_ai.safety_classifications sc
        ORDER BY sc.created_at DESC
        LIMIT 100
        "#,
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load guardrail events"))?;

    let events: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|row| {
            json!({
                "timestamp": row.get::<String, _>("timestamp"),
                "request_id": row.get::<String, _>("request_id"),
                "user_id": row.get::<Option<String>, _>("user_id"),
                "safety_level": row.get::<String, _>("safety_level"),
                "islamic_sensitivity": row.get::<String, _>("islamic_sensitivity"),
                "classifier_version": row.get::<String, _>("classifier_version"),
            })
        })
        .collect();

    Ok(HttpResponse::Ok().json(json!({
        "events": events,
        "source": "safety_classifications",
    })))
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::http::StatusCode;
    use actix_web::test::TestRequest;

    #[actix_rt::test]
    async fn unauthenticated_request_is_rejected() {
        // Fail closed: no JWT/session => no guardrail data.
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let req = TestRequest::default().to_http_request();
        let error = get_guardrails(req, web::Data::new(pool))
            .await
            .expect_err("missing auth must be rejected before any DB read");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
    }
}
