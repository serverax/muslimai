use actix_web::{web, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;

pub async fn create_user(
    _pool: web::Data<PgPool>,
    _body: web::Json<serde_json::Value>,
) -> HttpResponse {
    crate::error::error_response(
        actix_web::http::StatusCode::NOT_IMPLEMENTED,
        "not_implemented",
        "user account creation is disabled until auth/profile phase is implemented",
    )
}

pub async fn get_user(_pool: web::Data<PgPool>, user_id: web::Path<Uuid>) -> HttpResponse {
    crate::error::error_response(
        actix_web::http::StatusCode::NOT_IMPLEMENTED,
        "not_implemented",
        format!(
            "user profile retrieval is disabled until auth/profile phase is implemented (user_id={})",
            user_id.into_inner()
        ),
    )
}

pub async fn get_server_pubkey() -> HttpResponse {
    match std::env::var("SAKINA_SERVER_PUBKEY") {
        Ok(pub_key) if !pub_key.trim().is_empty() => {
            HttpResponse::Ok().json(serde_json::json!({ "pub_key": pub_key }))
        }
        _ => crate::error::error_response(
            actix_web::http::StatusCode::SERVICE_UNAVAILABLE,
            "service_unavailable",
            "server public key is not configured",
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;
    use actix_web::http::StatusCode;

    #[actix_rt::test]
    async fn pubkey_endpoint_returns_service_unavailable_when_unset() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::remove_var("SAKINA_SERVER_PUBKEY");
        let response = get_server_pubkey().await;
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[actix_rt::test]
    async fn pubkey_endpoint_returns_value_when_set() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_SERVER_PUBKEY", "test-pub-key");
        let response = get_server_pubkey().await;
        assert_eq!(response.status(), StatusCode::OK);
        std::env::remove_var("SAKINA_SERVER_PUBKEY");
    }

    #[actix_rt::test]
    async fn create_user_returns_not_implemented_error_contract() {
        let pool =
            PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid").expect("pool");
        let response = create_user(
            web::Data::new(pool),
            web::Json(serde_json::json!({"pub_key":"x"})),
        )
        .await;
        assert_eq!(response.status(), StatusCode::NOT_IMPLEMENTED);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"not_implemented\""));
    }
}
