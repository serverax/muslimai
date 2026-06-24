use actix_web::HttpResponse;

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
#[allow(clippy::await_holding_lock)]
mod tests {
    use super::*;
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
}
