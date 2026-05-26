use crate::brand::SAKINA;
use actix_web::{web, HttpResponse};
use serde_json::json;
use sqlx::PgPool;
use tokio::join;

use crate::services::{EmbeddingsService, LlmService, QdrantVectorDB};

pub async fn health_check(
    pool: web::Data<PgPool>,
    qdrant: web::Data<QdrantVectorDB>,
    embeddings: web::Data<EmbeddingsService>,
    llm: web::Data<LlmService>,
) -> HttpResponse {
    let db_status = pool.acquire().await.is_ok();
    let (qdrant_status, embeddings_status, llm_status) = join!(
        qdrant.health_check(),
        embeddings.health_check(),
        llm.health_check()
    );

    HttpResponse::Ok().json(json!({
        "status": "healthy",
        "service": "Project Sakina API",
        "version": "1.0.0",
        "brand": SAKINA.name,
        "tagline": SAKINA.tagline,
        "database": if db_status { "ok" } else { "error" },
        "qdrant": if qdrant_status { "ok" } else { "error" },
        "embeddings": if embeddings_status { "ok" } else { "error" },
        "llm": if llm_status { "ok" } else { "error" },
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

pub async fn readiness_check(
    pool: web::Data<PgPool>,
    qdrant: web::Data<QdrantVectorDB>,
    embeddings: web::Data<EmbeddingsService>,
    llm: web::Data<LlmService>,
) -> HttpResponse {
    let db_status = pool.acquire().await.is_ok();
    let (qdrant_status, embeddings_status, llm_status) = join!(
        qdrant.health_check(),
        embeddings.health_check(),
        llm.health_check()
    );
    let ready = db_status && qdrant_status && embeddings_status && llm_status;

    if ready {
        HttpResponse::Ok().json(json!({
            "status": "ready",
            "service": "sakinaai-api",
            "database": "connected",
            "qdrant": "connected",
            "embeddings": "connected",
            "llm": "connected",
            "timestamp": chrono::Utc::now().to_rfc3339()
        }))
    } else {
        HttpResponse::ServiceUnavailable().json(json!({
            "status": "not_ready",
            "service": "sakinaai-api",
            "database": if db_status { "connected" } else { "unavailable" },
            "qdrant": if qdrant_status { "connected" } else { "unavailable" },
            "embeddings": if embeddings_status { "connected" } else { "unavailable" },
            "llm": if llm_status { "connected" } else { "unavailable" },
            "timestamp": chrono::Utc::now().to_rfc3339()
        }))
    }
}
