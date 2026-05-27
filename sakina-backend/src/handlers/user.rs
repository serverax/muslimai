use actix_web::{web, HttpResponse};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

pub async fn create_user(
    _pool: web::Data<PgPool>,
    _body: web::Json<serde_json::Value>,
) -> HttpResponse {
    HttpResponse::NotImplemented().json(json!({
        "error": "user account creation is disabled until auth/profile phase is implemented"
    }))
}

pub async fn get_user(_pool: web::Data<PgPool>, user_id: web::Path<Uuid>) -> HttpResponse {
    HttpResponse::NotImplemented().json(json!({
        "id": user_id.into_inner(),
        "error": "user profile retrieval is disabled until auth/profile phase is implemented"
    }))
}

pub async fn get_server_pubkey() -> HttpResponse {
    match std::env::var("SAKINA_SERVER_PUBKEY") {
        Ok(pub_key) if !pub_key.trim().is_empty() => HttpResponse::Ok().json(json!({
            "pub_key": pub_key
        })),
        _ => HttpResponse::ServiceUnavailable().json(json!({
            "error": "server public key is not configured"
        })),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::http::StatusCode;

    #[actix_rt::test]
    async fn pubkey_endpoint_returns_service_unavailable_when_unset() {
        std::env::remove_var("SAKINA_SERVER_PUBKEY");
        let response = get_server_pubkey().await;
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[actix_rt::test]
    async fn pubkey_endpoint_returns_value_when_set() {
        std::env::set_var("SAKINA_SERVER_PUBKEY", "test-pub-key");
        let response = get_server_pubkey().await;
        assert_eq!(response.status(), StatusCode::OK);
    }
}
