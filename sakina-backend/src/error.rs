//! API error type: converts service errors (`Box<dyn Error>`) into HTTP 500
//! JSON responses. Used by handlers that return `Result<_, ApiError>`.

use actix_web::{http::StatusCode, HttpResponse, ResponseError};
use std::fmt;

#[derive(Debug)]
pub struct ApiError(pub String);

impl fmt::Display for ApiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl ResponseError for ApiError {
    fn status_code(&self) -> StatusCode {
        StatusCode::INTERNAL_SERVER_ERROR
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code()).json(serde_json::json!({ "error": self.0 }))
    }
}

impl From<Box<dyn std::error::Error>> for ApiError {
    fn from(e: Box<dyn std::error::Error>) -> Self {
        ApiError(e.to_string())
    }
}
