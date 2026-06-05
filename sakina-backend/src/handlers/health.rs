use crate::brand::SAKINA;
use actix_web::{web, HttpResponse};
use serde_json::json;
use sqlx::PgPool;

pub async fn health_check(pool: web::Data<PgPool>) -> HttpResponse {
    let db_status = pool.acquire().await.is_ok();
    let db_label = if db_status {
        "connected"
    } else {
        "disconnected"
    };

    HttpResponse::Ok().json(json!({
        "status": "healthy",
        "service": "Project Sakina API",
        "version": "1.0.0",
        "brand": SAKINA.name,
        "tagline": SAKINA.tagline,
        "db": db_label,
        "database": db_label,
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "values": [
            "Integrity",
            "Privacy",
            "Excellence",
            "Accessibility",
            "Community"
        ]
    }))
}
