//! PHASE 4 — guides (public), new-muslim, kids learning/quiz (+ login progress),
//! masjid-nearby (honest provider fallback), and user preferences (login).

use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::Value;
use sqlx::{PgPool, Row};

use crate::error::ApiError;
use crate::services::auth::authenticated_user_id;

// ----------------------------- Guides (public) -----------------------------

fn guide_json(r: sqlx::postgres::PgRow) -> Value {
    serde_json::json!({
        "slug": r.get::<String, _>("slug"),
        "title": r.get::<String, _>("title"),
        "category": r.get::<String, _>("category"),
        "steps": r.get::<String, _>("body").lines().collect::<Vec<_>>(),
        "body": r.get::<String, _>("body"),
        "source_reference": r.get::<String, _>("source_reference"),
    })
}

pub async fn guide_by_slug(
    pool: web::Data<PgPool>,
    path: web::Path<String>,
) -> Result<HttpResponse, ApiError> {
    let row = sqlx::query(
        "SELECT slug, title, category, body, source_reference FROM sakina_ai.guides WHERE slug = $1",
    )
    .bind(path.into_inner())
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load guide"))?;
    match row {
        Some(r) => Ok(HttpResponse::Ok().json(guide_json(r))),
        None => Err(ApiError::not_found("guide not found")),
    }
}

pub async fn new_muslim_steps(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let row = sqlx::query(
        "SELECT slug, title, category, body, source_reference FROM sakina_ai.guides WHERE slug = 'new-muslim'",
    )
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load new muslim guide"))?;
    match row {
        Some(r) => Ok(HttpResponse::Ok().json(guide_json(r))),
        None => Err(ApiError::not_found("new muslim guide not seeded")),
    }
}

// ----------------------------- Kids -----------------------------

pub async fn kids_lessons(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        "SELECT title, age_band, body, source_reference FROM sakina_ai.kids_lessons ORDER BY title",
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load kids lessons"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "title": r.get::<String, _>("title"),
                "age_band": r.get::<String, _>("age_band"),
                "body": r.get::<String, _>("body"),
                "source_reference": r.get::<String, _>("source_reference"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "lessons": items, "count": items.len() })))
}

pub async fn kids_quiz(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        "SELECT id::text AS id, question, options, correct_index, explanation, source_reference FROM sakina_ai.kids_quiz ORDER BY created_at",
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load kids quiz"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "id": r.get::<String, _>("id"),
                "question": r.get::<String, _>("question"),
                "options": r.get::<Value, _>("options"),
                "correct_index": r.get::<i32, _>("correct_index"),
                "explanation": r.get::<String, _>("explanation"),
                "source_reference": r.get::<String, _>("source_reference"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "questions": items, "count": items.len() })))
}

#[derive(Debug, Deserialize)]
pub struct ProgressRequest {
    pub activity: String,
    pub score: i32,
    pub total: i32,
}

pub async fn kids_save_progress(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<ProgressRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let id = sqlx::query_scalar::<_, uuid::Uuid>(
        "INSERT INTO sakina_ai.kids_progress (user_id, activity, score, total) VALUES ($1,$2,$3,$4) RETURNING id",
    )
    .bind(user_id)
    .bind(&body.activity)
    .bind(body.score)
    .bind(body.total)
    .fetch_one(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to save kids progress"))?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id.to_string() })))
}

pub async fn kids_list_progress(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let rows = sqlx::query(
        "SELECT activity, score, total, created_at::text AS created_at FROM sakina_ai.kids_progress WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100",
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list kids progress"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "activity": r.get::<String, _>("activity"),
                "score": r.get::<i32, _>("score"),
                "total": r.get::<i32, _>("total"),
                "created_at": r.get::<String, _>("created_at"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "progress": items, "count": items.len() })))
}

// ----------------------------- Masjid nearby (honest fallback) -----------------------------

#[derive(Debug, Deserialize)]
pub struct MasjidQuery {
    pub lat: Option<f64>,
    pub lng: Option<f64>,
}

pub async fn masjid_nearby(q: web::Query<MasjidQuery>) -> Result<HttpResponse, ApiError> {
    // No fake masjid data. If no external maps provider key is configured, return
    // a clear provider_not_configured status (honest fallback).
    let configured = std::env::var("MASJID_PROVIDER_KEY")
        .map(|v| !v.trim().is_empty())
        .unwrap_or(false);
    if !configured {
        return Ok(HttpResponse::Ok().json(serde_json::json!({
            "status": "provider_not_configured",
            "message": "Masjid search needs an external maps provider key (MASJID_PROVIDER_KEY). No results are fabricated.",
            "results": [],
            "query": { "lat": q.lat, "lng": q.lng }
        })));
    }
    // Provider configured but live integration is a later phase; be honest.
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "status": "provider_configured_integration_pending",
        "results": [],
        "query": { "lat": q.lat, "lng": q.lng }
    })))
}

// ----------------------------- User preferences (login) -----------------------------

#[derive(Debug, Deserialize)]
pub struct PrefRequest {
    pub key: String,
    pub value: String,
}

pub async fn set_preference(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<PrefRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    sqlx::query(
        r#"INSERT INTO sakina_ai.user_preferences_kv (user_id, pref_key, pref_value)
           VALUES ($1,$2,$3)
           ON CONFLICT (user_id, pref_key) DO UPDATE SET pref_value = EXCLUDED.pref_value, updated_at = now()"#,
    )
    .bind(user_id)
    .bind(&body.key)
    .bind(&body.value)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to save preference"))?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "status": "saved" })))
}

pub async fn list_preferences(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let rows = sqlx::query(
        "SELECT pref_key, pref_value FROM sakina_ai.user_preferences_kv WHERE user_id = $1 ORDER BY pref_key",
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load preferences"))?;
    let map: serde_json::Map<String, Value> = rows
        .into_iter()
        .map(|r| (r.get::<String, _>("pref_key"), Value::String(r.get::<String, _>("pref_value"))))
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "preferences": map })))
}
