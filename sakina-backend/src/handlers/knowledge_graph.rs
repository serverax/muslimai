use actix_web::{web, HttpResponse};

use crate::error::ApiError;
use crate::models::KnowledgeGraphHealthResponse;
use crate::services::KnowledgeGraphService;

#[derive(Debug, serde::Deserialize)]
pub struct KnowledgeGraphLookupRequest {
    pub query: String,
}

pub async fn health(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let entities_table = sqlx::query_scalar::<_, Option<String>>(
        "SELECT to_regclass('sakina_ai.knowledge_graph_entities')::text",
    )
    .fetch_one(pool.get_ref())
    .await
    .ok()
    .flatten()
    .is_some();
    let edges_table = sqlx::query_scalar::<_, Option<String>>(
        "SELECT to_regclass('sakina_ai.knowledge_graph_edges')::text",
    )
    .fetch_one(pool.get_ref())
    .await
    .ok()
    .flatten()
    .is_some();

    let ready = entities_table && edges_table;
    HttpResponse::Ok().json(KnowledgeGraphHealthResponse {
        status: if ready {
            "ok".to_string()
        } else {
            "not_ready".to_string()
        },
        entities_table,
        edges_table,
        ready,
    })
}

pub async fn entity(
    service: web::Data<KnowledgeGraphService>,
    payload: web::Json<KnowledgeGraphLookupRequest>,
) -> Result<HttpResponse, ApiError> {
    if payload.query.trim().is_empty() {
        return Err(ApiError::bad_request("query cannot be empty"));
    }
    let result = service.lookup(payload.query.trim()).await?;
    Ok(HttpResponse::Ok().json(result))
}
