use std::{
    collections::{HashMap, VecDeque},
    sync::{Mutex, OnceLock},
    time::{Duration, Instant},
};

use actix_web::{HttpMessage, HttpRequest};
use uuid::Uuid;

use crate::error::ApiError;

type RequestHistory = HashMap<String, VecDeque<Instant>>;

fn history() -> &'static Mutex<RequestHistory> {
    static STORE: OnceLock<Mutex<RequestHistory>> = OnceLock::new();
    STORE.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn enforce_rate_limit(
    req: &HttpRequest,
    route_key: &str,
    max_requests: usize,
    window: Duration,
) -> Result<(), ApiError> {
    let identity = identity_key(req, route_key);
    let now = Instant::now();
    let mut guard = history()
        .lock()
        .map_err(|_| ApiError::internal("rate limiter lock poisoned"))?;
    let bucket = guard.entry(identity).or_default();
    while let Some(oldest) = bucket.front() {
        if now.duration_since(*oldest) > window {
            bucket.pop_front();
        } else {
            break;
        }
    }

    if bucket.len() >= max_requests {
        return Err(ApiError::too_many_requests(
            "too many requests, please retry shortly",
        ));
    }

    bucket.push_back(now);
    Ok(())
}

fn identity_key(req: &HttpRequest, route_key: &str) -> String {
    if let Some(id) = req.extensions().get::<Uuid>() {
        return format!("{route_key}:user:{id}");
    }

    if let Some(header_id) = req
        .headers()
        .get("x-sakina-user-id")
        .and_then(|h| h.to_str().ok())
    {
        return format!("{route_key}:header:{header_id}");
    }

    if let Some(addr) = req.peer_addr() {
        return format!("{route_key}:ip:{addr}");
    }

    format!("{route_key}:anonymous")
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::test::TestRequest;

    #[test]
    fn allows_requests_within_window() {
        let req = TestRequest::default().to_http_request();
        assert!(enforce_rate_limit(&req, "test_ok", 2, Duration::from_secs(60)).is_ok());
        assert!(enforce_rate_limit(&req, "test_ok", 2, Duration::from_secs(60)).is_ok());
    }

    #[test]
    fn blocks_when_limit_is_exceeded() {
        let req = TestRequest::default().to_http_request();
        assert!(enforce_rate_limit(&req, "test_block", 1, Duration::from_secs(60)).is_ok());
        let blocked = enforce_rate_limit(&req, "test_block", 1, Duration::from_secs(60));
        assert!(blocked.is_err());
    }
}
