//! PHASE 2 — Dua library (public read) + bookmarks + reminders (login required,
//! user-isolated at the application layer per SAK-006 decision).

use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::auth::authenticated_user_id;

// --------------------------- Dua library (public) ---------------------------

#[derive(Debug, Deserialize)]
pub struct DuaQuery {
    pub category: Option<String>,
    pub q: Option<String>,
}

pub async fn list_duas(
    pool: web::Data<PgPool>,
    query: web::Query<DuaQuery>,
) -> Result<HttpResponse, ApiError> {
    let category = query.category.clone();
    let search = query.q.clone();
    let rows = sqlx::query(
        r#"
        SELECT id::text AS id, category, title, arabic, transliteration, translation, source, tags
        FROM sakina_ai.duas
        WHERE ($1::text IS NULL OR category = $1)
          AND ($2::text IS NULL OR
               (title ILIKE '%'||$2||'%' OR translation ILIKE '%'||$2||'%' OR tags ILIKE '%'||$2||'%'))
        ORDER BY category, title
        LIMIT 200
        "#,
    )
    .bind(category)
    .bind(search)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list duas"))?;

    let items: Vec<serde_json::Value> = rows.into_iter().map(dua_json).collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "duas": items, "count": items.len() })))
}

pub async fn dua_detail(
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let row = sqlx::query(
        r#"SELECT id::text AS id, category, title, arabic, transliteration, translation, source, tags
           FROM sakina_ai.duas WHERE id = $1"#,
    )
    .bind(path.into_inner())
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load dua"))?;
    match row {
        Some(r) => Ok(HttpResponse::Ok().json(dua_json(r))),
        None => Err(ApiError::not_found("dua not found")),
    }
}

fn dua_json(row: sqlx::postgres::PgRow) -> serde_json::Value {
    serde_json::json!({
        "id": row.get::<String, _>("id"),
        "category": row.get::<String, _>("category"),
        "title": row.get::<String, _>("title"),
        "arabic": row.get::<String, _>("arabic"),
        "transliteration": row.get::<Option<String>, _>("transliteration"),
        "translation": row.get::<String, _>("translation"),
        "source": row.get::<String, _>("source"),
        "tags": row.get::<String, _>("tags"),
    })
}

// --------------------------- Bookmarks (auth) ------------------------------

#[derive(Debug, Deserialize)]
pub struct BookmarkRequest {
    pub item_type: String,
    pub item_ref: String,
    pub label: Option<String>,
}

pub async fn add_bookmark(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<BookmarkRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let id = sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO sakina_ai.bookmarks (user_id, item_type, item_ref, label)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id, item_type, item_ref) DO UPDATE SET label = EXCLUDED.label
        RETURNING id
        "#,
    )
    .bind(user_id)
    .bind(&body.item_type)
    .bind(&body.item_ref)
    .bind(&body.label)
    .fetch_one(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to add bookmark"))?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id.to_string() })))
}

pub async fn list_bookmarks(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let rows = sqlx::query(
        r#"SELECT id::text AS id, item_type, item_ref, label, created_at::text AS created_at
           FROM sakina_ai.bookmarks WHERE user_id = $1 ORDER BY created_at DESC LIMIT 500"#,
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list bookmarks"))?;
    let items: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "id": r.get::<String, _>("id"),
                "item_type": r.get::<String, _>("item_type"),
                "item_ref": r.get::<String, _>("item_ref"),
                "label": r.get::<Option<String>, _>("label"),
                "created_at": r.get::<String, _>("created_at"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "bookmarks": items, "count": items.len() })))
}

pub async fn delete_bookmark(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let affected = sqlx::query("DELETE FROM sakina_ai.bookmarks WHERE id = $1 AND user_id = $2")
        .bind(path.into_inner())
        .bind(user_id)
        .execute(pool.get_ref())
        .await
        .map_err(|_| ApiError::internal("failed to delete bookmark"))?
        .rows_affected();
    if affected == 0 {
        return Err(ApiError::not_found("bookmark not found"));
    }
    Ok(HttpResponse::Ok().json(serde_json::json!({ "deleted": affected })))
}

// --------------------------- Reminders (auth) ------------------------------

#[derive(Debug, Deserialize)]
pub struct ReminderRequest {
    pub title: String,
    pub reminder_type: Option<String>,
    pub schedule_rule: Option<String>,
}

pub async fn add_reminder(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<ReminderRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let id = sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO sakina_ai.reminders (user_id, title, reminder_type, schedule_rule)
        VALUES ($1, $2, COALESCE($3,'custom'), $4)
        RETURNING id
        "#,
    )
    .bind(user_id)
    .bind(&body.title)
    .bind(&body.reminder_type)
    .bind(&body.schedule_rule)
    .fetch_one(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to add reminder"))?;
    Ok(HttpResponse::Created().json(serde_json::json!({
        "id": id.to_string(),
        "note": "stored as a reminder rule. Local notification firing is handled on-device and is not yet implemented."
    })))
}

pub async fn list_reminders(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let rows = sqlx::query(
        r#"SELECT id::text AS id, title, reminder_type, schedule_rule, enabled, created_at::text AS created_at
           FROM sakina_ai.reminders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 200"#,
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list reminders"))?;
    let items: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "id": r.get::<String, _>("id"),
                "title": r.get::<String, _>("title"),
                "reminder_type": r.get::<String, _>("reminder_type"),
                "schedule_rule": r.get::<Option<String>, _>("schedule_rule"),
                "enabled": r.get::<bool, _>("enabled"),
                "created_at": r.get::<String, _>("created_at"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "reminders": items, "count": items.len() })))
}

pub async fn delete_reminder(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let affected = sqlx::query("DELETE FROM sakina_ai.reminders WHERE id = $1 AND user_id = $2")
        .bind(path.into_inner())
        .bind(user_id)
        .execute(pool.get_ref())
        .await
        .map_err(|_| ApiError::internal("failed to delete reminder"))?
        .rows_affected();
    if affected == 0 {
        return Err(ApiError::not_found("reminder not found"));
    }
    Ok(HttpResponse::Ok().json(serde_json::json!({ "deleted": affected })))
}
