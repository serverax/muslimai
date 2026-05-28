//! API error type: converts service errors (`Box<dyn Error>`) into HTTP 500
//! JSON responses. Used by handlers that return `Result<_, ApiError>`.

use actix_web::{http::StatusCode, HttpResponse, ResponseError};
use std::fmt;

#[derive(Debug, Clone)]
pub struct ApiError {
    pub code: &'static str,
    pub message: String,
    pub status: StatusCode,
}

impl ApiError {
    pub fn internal(message: impl Into<String>) -> Self {
        Self {
            code: "internal_error",
            message: message.into(),
            status: StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    pub fn unauthorized(message: impl Into<String>) -> Self {
        Self {
            code: "unauthorized",
            message: message.into(),
            status: StatusCode::UNAUTHORIZED,
        }
    }

    pub fn bad_request(message: impl Into<String>) -> Self {
        Self {
            code: "bad_request",
            message: message.into(),
            status: StatusCode::BAD_REQUEST,
        }
    }

    pub fn not_found(message: impl Into<String>) -> Self {
        Self {
            code: "not_found",
            message: message.into(),
            status: StatusCode::NOT_FOUND,
        }
    }

    pub fn not_implemented(message: impl Into<String>) -> Self {
        Self {
            code: "not_implemented",
            message: message.into(),
            status: StatusCode::NOT_IMPLEMENTED,
        }
    }

    pub fn service_unavailable(message: impl Into<String>) -> Self {
        Self {
            code: "service_unavailable",
            message: message.into(),
            status: StatusCode::SERVICE_UNAVAILABLE,
        }
    }
}

pub fn error_response(
    status: StatusCode,
    code: &'static str,
    message: impl Into<String>,
) -> HttpResponse {
    HttpResponse::build(status).json(serde_json::json!({
        "error": {
            "code": code,
            "message": message.into()
        }
    }))
}

impl fmt::Display for ApiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl ResponseError for ApiError {
    fn status_code(&self) -> StatusCode {
        self.status
    }

    fn error_response(&self) -> HttpResponse {
        error_response(self.status, self.code, self.message.clone())
    }
}

impl From<Box<dyn std::error::Error>> for ApiError {
    fn from(e: Box<dyn std::error::Error>) -> Self {
        tracing::error!("internal service error: {}", e);
        ApiError::internal("internal server error")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;

    #[actix_rt::test]
    async fn error_response_uses_consistent_contract_shape() {
        let response = error_response(StatusCode::BAD_REQUEST, "bad_request", "invalid payload");
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let body = to_bytes(response.into_body()).await.expect("response body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"bad_request\""));
        assert!(text.contains("\"message\":\"invalid payload\""));
    }
}
