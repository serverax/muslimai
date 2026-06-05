use actix_web::HttpRequest;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use hmac::{Hmac, Mac};
use serde_json::json;
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
type HmacSha256 = Hmac<Sha256>;

pub fn bearer_token(req: &HttpRequest) -> Result<&str, ApiError> {
    let header = req
        .headers()
        .get(actix_web::http::header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .ok_or_else(|| ApiError::unauthorized("authorization bearer token is required"))?;

    let token = header
        .strip_prefix("Bearer ")
        .or_else(|| header.strip_prefix("bearer "))
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError::unauthorized("authorization bearer token is required"))?;

    Ok(token)
}

fn test_user_header(req: &HttpRequest) -> Option<Uuid> {
    if !cfg!(test) {
        return None;
    }

    req.headers()
        .get("x-sakina-user-id")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| Uuid::parse_str(value).ok())
}

pub fn session_token_hash(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    format!("{:x}", digest)
}

fn jwt_secret() -> Result<String, ApiError> {
    if let Ok(value) = std::env::var("JWT_SECRET").or_else(|_| std::env::var("SAKINA_JWT_SECRET")) {
        let value = value.trim().to_string();
        if value.len() >= 32 {
            return Ok(value);
        }
    }

    if cfg!(test) {
        return Ok("sakina-test-jwt-secret-minimum-32-bytes".to_string());
    }

    Err(ApiError::service_unavailable(
        "JWT_SECRET or SAKINA_JWT_SECRET with at least 32 characters is required",
    ))
}

fn sign(data: &str, secret: &str) -> Result<String, ApiError> {
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
        .map_err(|_| ApiError::internal("failed to initialize JWT signer"))?;
    mac.update(data.as_bytes());
    Ok(URL_SAFE_NO_PAD.encode(mac.finalize().into_bytes()))
}

pub fn issue_jwt(
    user_id: Uuid,
    ttl_seconds: i64,
) -> Result<(String, chrono::DateTime<chrono::Utc>), ApiError> {
    let secret = jwt_secret()?;
    let now = chrono::Utc::now();
    let expires_at = now + chrono::Duration::seconds(ttl_seconds);
    let header = URL_SAFE_NO_PAD.encode(r#"{"alg":"HS256","typ":"JWT"}"#);
    let payload = URL_SAFE_NO_PAD.encode(
        json!({
            "sub": user_id.to_string(),
            "iat": now.timestamp(),
            "exp": expires_at.timestamp(),
            "jti": Uuid::new_v4().to_string(),
            "iss": "sakina-api",
            "aud": "sakina-mobile"
        })
        .to_string(),
    );
    let signing_input = format!("{header}.{payload}");
    let signature = sign(&signing_input, &secret)?;
    Ok((format!("{signing_input}.{signature}"), expires_at))
}

pub fn validate_jwt(token: &str) -> Result<Uuid, ApiError> {
    let secret = jwt_secret()?;
    let parts = token.split('.').collect::<Vec<_>>();
    if parts.len() != 3 {
        return Err(ApiError::unauthorized("invalid JWT"));
    }
    let signing_input = format!("{}.{}", parts[0], parts[1]);
    let expected = sign(&signing_input, &secret)?;
    if expected != parts[2] {
        return Err(ApiError::unauthorized("invalid JWT signature"));
    }
    let payload_bytes = URL_SAFE_NO_PAD
        .decode(parts[1])
        .map_err(|_| ApiError::unauthorized("invalid JWT payload"))?;
    let payload: serde_json::Value = serde_json::from_slice(&payload_bytes)
        .map_err(|_| ApiError::unauthorized("invalid JWT payload"))?;
    let exp = payload["exp"]
        .as_i64()
        .ok_or_else(|| ApiError::unauthorized("JWT exp is required"))?;
    if exp <= chrono::Utc::now().timestamp() {
        return Err(ApiError::unauthorized("expired JWT"));
    }
    let sub = payload["sub"]
        .as_str()
        .ok_or_else(|| ApiError::unauthorized("JWT sub is required"))?;
    Uuid::parse_str(sub).map_err(|_| ApiError::unauthorized("invalid JWT subject"))
}

pub async fn authenticated_user_id(req: &HttpRequest, pool: &PgPool) -> Result<Uuid, ApiError> {
    let token = match bearer_token(req) {
        Ok(token) => token,
        Err(err) => {
            if let Some(user_id) = test_user_header(req) {
                return Ok(user_id);
            }
            return Err(err);
        }
    };
    let jwt_user_id = validate_jwt(token)?;
    let token_hash = session_token_hash(token);

    let row = sqlx::query(
        r#"
        SELECT user_id
        FROM public.auth_sessions
        WHERE session_token_hash = $1
          AND expires_at > now()
          AND revoked_at IS NULL
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(token_hash)
    .fetch_optional(pool)
    .await
    .map_err(|_| ApiError::internal("failed to load authenticated session"))?;

    let Some(row) = row else {
        return Err(ApiError::unauthorized("invalid or expired session token"));
    };

    let session_user_id: Uuid = row.get("user_id");
    if session_user_id != jwt_user_id {
        return Err(ApiError::unauthorized("JWT/session subject mismatch"));
    }
    Ok(session_user_id)
}

pub async fn ensure_user_scope(
    req: &HttpRequest,
    pool: &PgPool,
    requested_user_id: Uuid,
) -> Result<Uuid, ApiError> {
    let authenticated_user_id = authenticated_user_id(req, pool).await?;
    if authenticated_user_id != requested_user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    Ok(authenticated_user_id)
}
