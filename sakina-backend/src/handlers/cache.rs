use actix_web::{web, HttpResponse};

use crate::services::SemanticCacheService;

pub async fn stats(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let service = SemanticCacheService::new(pool.get_ref().clone());
    match service.stats().await {
        Ok(stats) => HttpResponse::Ok().json(serde_json::json!({
            "enabled": stats.enabled,
            "status": "ok",
            "entries": stats.total_entries,
            "hits": stats.total_hits,
        })),
        Err(_) => HttpResponse::Ok().json(serde_json::json!({
            "enabled": false,
            "status": "degraded",
            "reason": "semantic cache table unavailable",
            "entries": 0,
            "hits": 0
        })),
    }
}
