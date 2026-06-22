//! SAK-011: per-IP request rate limiting for abuse-sensitive routes.
//!
//! A single in-memory sliding-window limiter shared across workers (registered as
//! app_data). The app-wide `rate_limit_mw` middleware picks a bucket + budget by
//! request path: auth (login/register), ask, and admin surfaces are throttled;
//! everything else is unlimited. Abuse-safe: returns HTTP 429 with a generic body.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use actix_web::body::MessageBody;
use actix_web::dev::{ServiceRequest, ServiceResponse};
use actix_web::middleware::Next;
use actix_web::{web, HttpRequest};

use crate::error::ApiError;

#[derive(Default)]
pub struct RateLimiter {
    hits: Mutex<HashMap<String, Vec<Instant>>>,
}

impl RateLimiter {
    pub fn new() -> Self {
        Self {
            hits: Mutex::new(HashMap::new()),
        }
    }

    /// Returns true if this key is within `max` hits over `window`, recording the hit.
    pub fn is_allowed(&self, key: &str, max: usize, window: Duration) -> bool {
        let now = Instant::now();
        let mut map = match self.hits.lock() {
            Ok(g) => g,
            Err(p) => p.into_inner(),
        };
        let entries = map.entry(key.to_string()).or_default();
        entries.retain(|t| now.duration_since(*t) <= window);
        if entries.len() >= max {
            return false;
        }
        entries.push(now);
        true
    }
}

/// Client identity for limiting: X-Forwarded-For first hop, else peer IP.
fn client_key(req: &HttpRequest) -> String {
    req.headers()
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.split(',').next())
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .or_else(|| req.peer_addr().map(|a| a.ip().to_string()))
        .unwrap_or_else(|| "unknown".to_string())
}

/// (bucket, max_requests, window) for a path, or None to skip limiting.
fn budget_for(path: &str) -> Option<(&'static str, usize, Duration)> {
    let p = path;
    if p.ends_with("/auth/login") || p.ends_with("/auth/register") {
        Some(("auth", 10, Duration::from_secs(60)))
    } else if p.ends_with("/auth/refresh") {
        Some(("refresh", 30, Duration::from_secs(60)))
    } else if p.ends_with("/api/sakina/ask") || p.ends_with("/api/chat") {
        Some(("ask", 30, Duration::from_secs(60)))
    } else if p.starts_with("/admin") || p.contains("/v1/safety") {
        Some(("admin", 60, Duration::from_secs(60)))
    } else {
        None
    }
}

/// App-wide rate-limit middleware. Picks a budget by path; 429 when exceeded.
pub async fn rate_limit_mw(
    req: ServiceRequest,
    next: Next<impl MessageBody + 'static>,
) -> Result<ServiceResponse<impl MessageBody>, actix_web::Error> {
    if let Some((bucket, max, window)) = budget_for(req.path()) {
        if let Some(limiter) = req.app_data::<web::Data<RateLimiter>>() {
            let key = format!("{}|{}", bucket, client_key(req.request()));
            if !limiter.is_allowed(&key, max, window) {
                return Err(ApiError::too_many_requests(
                    "too many requests, please slow down and try again shortly",
                )
                .into());
            }
        }
    }
    next.call(req).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn limiter_triggers_after_max_and_resets_after_window() {
        let rl = RateLimiter::new();
        let w = Duration::from_millis(80);
        assert!(rl.is_allowed("k", 3, w));
        assert!(rl.is_allowed("k", 3, w));
        assert!(rl.is_allowed("k", 3, w));
        assert!(!rl.is_allowed("k", 3, w));
        assert!(rl.is_allowed("other", 3, w));
        std::thread::sleep(Duration::from_millis(100));
        assert!(rl.is_allowed("k", 3, w));
    }
}
