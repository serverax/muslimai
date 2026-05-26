use crate::error::ApiError;
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub pub_key: String,
    pub madhhab_preference: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
struct UserRow {
    id: Uuid,
    pub_key: String,
    madhhab_preference: Option<String>,
    created_at: chrono::NaiveDateTime,
}

pub async fn create_user(
    pool: web::Data<PgPool>,
    body: web::Json<CreateUserRequest>,
) -> Result<HttpResponse, ApiError> {
    if body.pub_key.trim().is_empty() {
        return Err(ApiError::bad_request("pub_key is required"));
    }

    let madhhab = body
        .madhhab_preference
        .as_deref()
        .unwrap_or("hanafi")
        .trim();
    if !matches!(
        madhhab,
        "hanafi" | "maliki" | "shafii" | "hanbali" | "jafari"
    ) {
        return Err(ApiError::bad_request(
            "madhhab_preference must be one of hanafi, maliki, shafii, hanbali, jafari",
        ));
    }

    let user: UserRow = sqlx::query_as(
        "INSERT INTO public.users (pub_key, madhhab_preference) \
         VALUES ($1, $2) \
         ON CONFLICT (pub_key) DO UPDATE \
         SET madhhab_preference = EXCLUDED.madhhab_preference \
         RETURNING id, pub_key, madhhab_preference, created_at",
    )
    .bind(body.pub_key.trim())
    .bind(madhhab)
    .fetch_one(pool.get_ref())
    .await
    .map_err(|e| {
        tracing::error!("create_user failed: {}", e);
        ApiError::internal("failed to create user")
    })?;

    Ok(HttpResponse::Created().json(user_json(user)))
}

pub async fn get_user(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    user_id: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let requested_user_id = user_id.into_inner();
    let authenticated_user_id = req
        .extensions()
        .get::<Uuid>()
        .copied()
        .ok_or_else(|| ApiError::unauthorized("missing authenticated user identity"))?;
    if authenticated_user_id != requested_user_id {
        return Err(ApiError::forbidden(
            "requested user_id does not match authenticated identity",
        ));
    }

    let user = sqlx::query_as::<_, UserRow>(
        "SELECT id, pub_key, madhhab_preference, created_at \
         FROM public.users WHERE id = $1",
    )
    .bind(requested_user_id)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|e| {
        tracing::error!("get_user failed: {}", e);
        ApiError::internal("failed to fetch user")
    })?;

    match user {
        Some(user) => Ok(HttpResponse::Ok().json(user_json(user))),
        None => Ok(HttpResponse::NotFound().json(json!({
            "error": "user not found"
        }))),
    }
}

pub async fn get_server_pubkey() -> HttpResponse {
    let pub_key = std::env::var("SAKINA_SERVER_PUBLIC_KEY").unwrap_or_default();
    HttpResponse::Ok().json(json!({ "pub_key": pub_key }))
}

fn user_json(user: UserRow) -> serde_json::Value {
    json!({
        "id": user.id,
        "pub_key": user.pub_key,
        "madhhab_preference": user.madhhab_preference.unwrap_or_else(|| "hanafi".to_string()),
        "created_at": user.created_at.and_utc().to_rfc3339()
    })
}
