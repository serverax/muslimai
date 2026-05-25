use actix_web::HttpResponse;
use serde_json::json;

pub async fn get_guardrails() -> HttpResponse {
    HttpResponse::Ok().json(json!([
        {
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "query": "example",
            "trigger_reason": "SIMILARITY_THRESHOLD_FAILED",
            "user_id": null
        }
    ]))
}
