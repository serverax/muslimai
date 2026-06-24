use actix_web::{web, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use crate::error::error_response;

#[derive(Debug, Deserialize)]
pub struct WaitlistRequest {
    pub name: String,
    pub email: String,
    pub preferred_language: Option<String>,
    pub platform: Option<String>,
    pub message: Option<String>,
    pub source: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct WaitlistResponse {
    pub status: &'static str,
    pub message: &'static str,
}

pub struct WaitlistRateLimiter {
    window: Duration,
    max_requests: usize,
    requests_by_key: Mutex<HashMap<String, Vec<Instant>>>,
}

impl WaitlistRateLimiter {
    pub fn new(max_requests: usize, window: Duration) -> Self {
        Self {
            window,
            max_requests,
            requests_by_key: Mutex::new(HashMap::new()),
        }
    }

    pub fn is_allowed(&self, key: &str) -> bool {
        let now = Instant::now();
        let mut map = self
            .requests_by_key
            .lock()
            .expect("waitlist rate limiter lock poisoned");
        let entries = map.entry(key.to_string()).or_default();
        entries.retain(|t| now.duration_since(*t) <= self.window);
        if entries.len() >= self.max_requests {
            return false;
        }
        entries.push(now);
        true
    }
}

fn requester_key(req: &HttpRequest) -> String {
    req.headers()
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.split(',').next())
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .or_else(|| req.peer_addr().map(|a| a.ip().to_string()))
        .unwrap_or_else(|| "unknown".to_string())
}

fn is_valid_email(email: &str) -> bool {
    let email = email.trim();
    if email.is_empty() || email.contains(' ') {
        return false;
    }
    let mut parts = email.split('@');
    let local = parts.next().unwrap_or_default();
    let domain = parts.next().unwrap_or_default();
    parts.next().is_none() && !local.is_empty() && domain.contains('.')
}

pub async fn create_waitlist_entry(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    limiter: web::Data<WaitlistRateLimiter>,
    payload: web::Json<WaitlistRequest>,
) -> HttpResponse {
    let key = requester_key(&req);
    if !limiter.is_allowed(&key) {
        return error_response(
            actix_web::http::StatusCode::TOO_MANY_REQUESTS,
            "rate_limited",
            "too many requests, please try again later",
        );
    }

    let req = payload.into_inner();
    const MAX_NAME_LEN: usize = 120;
    const MAX_EMAIL_LEN: usize = 320;
    const MAX_LANGUAGE_LEN: usize = 16;
    const MAX_PLATFORM_LEN: usize = 32;
    const MAX_MESSAGE_LEN: usize = 2000;
    const MAX_SOURCE_LEN: usize = 120;

    if req.name.trim().is_empty() || req.email.trim().is_empty() {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "name and email are required",
        );
    }
    if !is_valid_email(&req.email) {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "email is invalid",
        );
    }
    if req.name.trim().len() > MAX_NAME_LEN
        || req.email.trim().len() > MAX_EMAIL_LEN
        || req
            .preferred_language
            .as_deref()
            .map(|v| v.trim().len() > MAX_LANGUAGE_LEN)
            .unwrap_or(false)
        || req
            .platform
            .as_deref()
            .map(|v| v.trim().len() > MAX_PLATFORM_LEN)
            .unwrap_or(false)
        || req
            .message
            .as_deref()
            .map(|v| v.trim().len() > MAX_MESSAGE_LEN)
            .unwrap_or(false)
        || req
            .source
            .as_deref()
            .map(|v| v.trim().len() > MAX_SOURCE_LEN)
            .unwrap_or(false)
    {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "one or more fields exceeded maximum allowed length",
        );
    }

    let query = r#"
        INSERT INTO sakina_ai.waitlist
            (name, email, preferred_language, platform, message, source)
        VALUES
            ($1, $2, $3, $4, $5, COALESCE($6, '7jzi.com'))
        ON CONFLICT (email) DO UPDATE
        SET
            name = EXCLUDED.name,
            preferred_language = EXCLUDED.preferred_language,
            platform = EXCLUDED.platform,
            message = EXCLUDED.message,
            source = EXCLUDED.source
    "#;

    let result = sqlx::query(query)
        .bind(req.name.trim())
        .bind(req.email.trim().to_lowercase())
        .bind(req.preferred_language.as_deref())
        .bind(req.platform.as_deref())
        .bind(req.message.as_deref())
        .bind(req.source.as_deref())
        .execute(pool.get_ref())
        .await;

    match result {
        Ok(_) => HttpResponse::Ok().json(WaitlistResponse {
            status: "ok",
            message: "waitlist entry saved",
        }),
        Err(err) => {
            tracing::error!("waitlist insert failed: {}", err);
            error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to save waitlist entry",
            )
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{body::to_bytes, test::TestRequest};
    use sqlx::{PgPool, Row};
    use uuid::Uuid;

    fn test_limiter() -> web::Data<WaitlistRateLimiter> {
        web::Data::new(WaitlistRateLimiter::new(50, Duration::from_secs(60)))
    }

    async fn ensure_waitlist_schema(pool: &PgPool) {
        sqlx::query("CREATE SCHEMA IF NOT EXISTS sakina_ai")
            .execute(pool)
            .await
            .expect("create waitlist schema");
        let table_ddl = r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.waitlist (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                preferred_language TEXT,
                platform TEXT,
                message TEXT,
                source TEXT DEFAULT '7jzi.com',
                status TEXT DEFAULT 'new',
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
        "#;
        sqlx::query(table_ddl)
            .execute(pool)
            .await
            .expect("create waitlist table");
    }

    async fn required_pool() -> PgPool {
        let database_url = std::env::var("DATABASE_URL")
            .expect("DATABASE_URL is required for waitlist DB integration tests");
        PgPool::connect(&database_url)
            .await
            .expect("connect waitlist DB integration pool")
    }

    #[actix_rt::test]
    async fn invalid_email_returns_bad_request() {
        let pool = PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = create_waitlist_entry(
            TestRequest::default().to_http_request(),
            web::Data::new(pool),
            test_limiter(),
            web::Json(WaitlistRequest {
                name: "A".to_string(),
                email: "not-an-email".to_string(),
                preferred_language: None,
                platform: None,
                message: None,
                source: None,
            }),
        )
        .await;
        assert_eq!(response.status(), actix_web::http::StatusCode::BAD_REQUEST);
        let body = to_bytes(response.into_body()).await.expect("body bytes");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"bad_request\""));
        assert!(text.contains("email is invalid"));
    }

    #[actix_rt::test]
    async fn insert_and_duplicate_email_are_clean() {
        let pool = required_pool().await;
        ensure_waitlist_schema(&pool).await;
        let email = format!("waitlist-{}@example.com", Uuid::new_v4());

        let base_request = WaitlistRequest {
            name: "Sakina User".to_string(),
            email: email.clone(),
            preferred_language: Some("en".to_string()),
            platform: Some("web".to_string()),
            message: Some("keep me posted".to_string()),
            source: None,
        };

        let first = create_waitlist_entry(
            TestRequest::default().to_http_request(),
            web::Data::new(pool.clone()),
            test_limiter(),
            web::Json(base_request),
        )
        .await;
        assert_eq!(first.status(), actix_web::http::StatusCode::OK);

        let second = create_waitlist_entry(
            TestRequest::default().to_http_request(),
            web::Data::new(pool.clone()),
            test_limiter(),
            web::Json(WaitlistRequest {
                name: "Sakina User Updated".to_string(),
                email: email.clone(),
                preferred_language: Some("ar".to_string()),
                platform: Some("ios".to_string()),
                message: Some("updated".to_string()),
                source: Some("7jzi.com".to_string()),
            }),
        )
        .await;
        assert_eq!(second.status(), actix_web::http::StatusCode::OK);

        let row = sqlx::query(
            "SELECT email, source, status FROM sakina_ai.waitlist WHERE email = $1 LIMIT 1",
        )
        .bind(email)
        .fetch_one(&pool)
        .await
        .expect("fetch inserted row");
        let source: Option<String> = row.get("source");
        let status: Option<String> = row.get("status");
        assert_eq!(source.as_deref(), Some("7jzi.com"));
        assert_eq!(status.as_deref(), Some("new"));
    }

    #[actix_rt::test]
    async fn invalid_body_returns_bad_request() {
        let pool = PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = create_waitlist_entry(
            TestRequest::default().to_http_request(),
            web::Data::new(pool),
            test_limiter(),
            web::Json(WaitlistRequest {
                name: "   ".to_string(),
                email: "user@example.com".to_string(),
                preferred_language: None,
                platform: None,
                message: None,
                source: None,
            }),
        )
        .await;
        assert_eq!(response.status(), actix_web::http::StatusCode::BAD_REQUEST);
        let body = to_bytes(response.into_body()).await.expect("body bytes");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("name and email are required"));
    }

    #[test]
    fn limiter_blocks_after_threshold() {
        let limiter = WaitlistRateLimiter::new(1, Duration::from_secs(60));
        assert!(limiter.is_allowed("127.0.0.1"));
        assert!(!limiter.is_allowed("127.0.0.1"));
    }
}
