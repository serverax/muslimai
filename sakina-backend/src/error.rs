//! API error type: converts service errors (`Box<dyn Error>`) into HTTP 500
//! JSON responses. Used by handlers that return `Result<_, ApiError>`.

use actix_web::{http::StatusCode, HttpResponse, ResponseError};
use std::fmt;

#[derive(Debug)]
pub struct ApiError {
    message: String,
    status: StatusCode,
}

impl ApiError {
    pub fn internal<M: Into<String>>(message: M) -> Self {
        Self {
            message: message.into(),
            status: StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    pub fn bad_request<M: Into<String>>(message: M) -> Self {
        Self {
            message: message.into(),
            status: StatusCode::BAD_REQUEST,
        }
    }

    pub fn unauthorized<M: Into<String>>(message: M) -> Self {
        Self {
            message: message.into(),
            status: StatusCode::UNAUTHORIZED,
        }
    }

    pub fn forbidden<M: Into<String>>(message: M) -> Self {
        Self {
            message: message.into(),
            status: StatusCode::FORBIDDEN,
        }
    }

    pub fn too_many_requests<M: Into<String>>(message: M) -> Self {
        Self {
            message: message.into(),
            status: StatusCode::TOO_MANY_REQUESTS,
        }
    }

    pub fn service_unavailable<M: Into<String>>(message: M) -> Self {
        Self {
            message: message.into(),
            status: StatusCode::SERVICE_UNAVAILABLE,
        }
    }
}

impl fmt::Display for ApiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl ResponseError for ApiError {
    fn status_code(&self) -> StatusCode {
        self.status
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code()).json(serde_json::json!({
            "error": self.message
        }))
    }
}

impl From<Box<dyn std::error::Error>> for ApiError {
    fn from(e: Box<dyn std::error::Error>) -> Self {
        tracing::error!("internal error: {}", e);
        ApiError::internal("internal server error")
    }
}
