//! PHASE 6H — mobile app feature flags (owner/admin controlled).

use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::{json, Value};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::auth::{authenticated_user_id, require_admin};
use crate::handlers::subscription::has_premium_or_admin;

#[derive(Debug, Deserialize)]
pub struct UpdateFeatureRequest {
    pub title_en: Option<String>,
    pub title_ar: Option<String>,
    pub description_en: Option<String>,
    pub description_ar: Option<String>,
    pub category: Option<String>,
    pub icon_key: Option<String>,
    pub enabled: Option<bool>,
    pub requires_login: Option<bool>,
    pub requires_premium: Option<bool>,
    pub admin_only: Option<bool>,
    pub scholar_only: Option<bool>,
    pub coming_soon: Option<bool>,
    pub maintenance_mode: Option<bool>,
    pub display_order: Option<i32>,
    pub app_store_visible: Option<bool>,
    pub local_test_visible: Option<bool>,
}

fn feature_row_to_json(row: &sqlx::postgres::PgRow, include_admin_fields: bool) -> Value {
    let mut obj = json!({
        "feature_key": row.get::<String, _>("feature_key"),
        "title_en": row.get::<String, _>("title_en"),
        "title_ar": row.get::<String, _>("title_ar"),
        "description_en": row.get::<String, _>("description_en"),
        "description_ar": row.get::<String, _>("description_ar"),
        "category": row.get::<String, _>("category"),
        "icon_key": row.get::<String, _>("icon_key"),
        "enabled": row.get::<bool, _>("enabled"),
        "requires_login": row.get::<bool, _>("requires_login"),
        "requires_premium": row.get::<bool, _>("requires_premium"),
        "admin_only": row.get::<bool, _>("admin_only"),
        "scholar_only": row.get::<bool, _>("scholar_only"),
        "coming_soon": row.get::<bool, _>("coming_soon"),
        "maintenance_mode": row.get::<bool, _>("maintenance_mode"),
        "display_order": row.get::<i32, _>("display_order"),
    });
    if include_admin_fields {
        if let Some(map) = obj.as_object_mut() {
            map.insert("id".to_string(), json!(row.get::<Uuid, _>("id").to_string()));
            map.insert(
                "app_store_visible".to_string(),
                json!(row.get::<bool, _>("app_store_visible")),
            );
            map.insert(
                "local_test_visible".to_string(),
                json!(row.get::<bool, _>("local_test_visible")),
            );
            map.insert(
                "updated_at".to_string(),
                json!(row.get::<chrono::DateTime<chrono::Utc>, _>("updated_at").to_rfc3339()),
            );
        }
    }
    obj
}

async fn fetch_all_features(pool: &PgPool) -> Result<Vec<Value>, ApiError> {
    let rows = sqlx::query(
        r#"SELECT id, feature_key, title_en, title_ar, description_en, description_ar,
                  category, icon_key, enabled, requires_login, requires_premium,
                  admin_only, scholar_only, coming_soon, maintenance_mode, display_order,
                  app_store_visible, local_test_visible, updated_at
           FROM public.app_feature_flags
           ORDER BY display_order, feature_key"#,
    )
    .fetch_all(pool)
    .await
    .map_err(|_| ApiError::internal("failed to load app feature flags"))?;
    Ok(rows
        .iter()
        .map(|r| feature_row_to_json(r, true))
        .collect())
}

async fn is_admin(pool: &PgPool, user_id: Uuid) -> bool {
    sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM public.admin_users WHERE user_id = $1 AND account_status = 'active')",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .unwrap_or(false)
}

async fn is_scholar(pool: &PgPool, user_id: Uuid) -> bool {
    sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM public.scholar_accounts WHERE user_id = $1 AND account_status = 'active')",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .unwrap_or(false)
}

/// Public mobile config — filters by visibility and role when authenticated.
pub async fn list_public_features(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await.ok();
    let admin = if let Some(uid) = user_id {
        is_admin(pool.get_ref(), uid).await
    } else {
        false
    };
    let scholar = if let Some(uid) = user_id {
        is_scholar(pool.get_ref(), uid).await
    } else {
        false
    };
    let premium = if let Some(uid) = user_id {
        has_premium_or_admin(pool.get_ref(), uid).await.unwrap_or(false)
    } else {
        false
    };

    let rows = sqlx::query(
        r#"SELECT feature_key, title_en, title_ar, description_en, description_ar,
                  category, icon_key, enabled, requires_login, requires_premium,
                  admin_only, scholar_only, coming_soon, maintenance_mode, display_order
           FROM public.app_feature_flags
           WHERE local_test_visible = true OR app_store_visible = true
           ORDER BY display_order, feature_key"#,
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load features"))?;

    let mut items: Vec<Value> = Vec::new();
    for row in &rows {
        let admin_only: bool = row.get("admin_only");
        let scholar_only: bool = row.get("scholar_only");
        if admin_only && !admin {
            continue;
        }
        if scholar_only && !scholar && !admin {
            continue;
        }
        let mut item = feature_row_to_json(row, false);
        if let Some(map) = item.as_object_mut() {
            map.insert("user_has_premium".to_string(), json!(premium));
            map.insert("user_logged_in".to_string(), json!(user_id.is_some()));
        }
        items.push(item);
    }

    Ok(HttpResponse::Ok().json(json!({
        "features": items,
        "count": items.len(),
    })))
}

pub async fn list_admin_features(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let _admin_id = require_admin(&req, pool.get_ref()).await?;
    let items = fetch_all_features(pool.get_ref()).await?;
    Ok(HttpResponse::Ok().json(json!({
        "features": items,
        "count": items.len(),
    })))
}

pub async fn update_feature(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<String>,
    body: web::Json<UpdateFeatureRequest>,
) -> Result<HttpResponse, ApiError> {
    let _admin_id = require_admin(&req, pool.get_ref()).await?;
    let feature_key = path.into_inner();

    let updated = sqlx::query(
        r#"UPDATE public.app_feature_flags SET
            title_en = COALESCE($2, title_en),
            title_ar = COALESCE($3, title_ar),
            description_en = COALESCE($4, description_en),
            description_ar = COALESCE($5, description_ar),
            category = COALESCE($6, category),
            icon_key = COALESCE($7, icon_key),
            enabled = COALESCE($8, enabled),
            requires_login = COALESCE($9, requires_login),
            requires_premium = COALESCE($10, requires_premium),
            admin_only = COALESCE($11, admin_only),
            scholar_only = COALESCE($12, scholar_only),
            coming_soon = COALESCE($13, coming_soon),
            maintenance_mode = COALESCE($14, maintenance_mode),
            display_order = COALESCE($15, display_order),
            app_store_visible = COALESCE($16, app_store_visible),
            local_test_visible = COALESCE($17, local_test_visible),
            updated_at = now()
        WHERE feature_key = $1
        RETURNING id, feature_key, title_en, title_ar, description_en, description_ar,
                  category, icon_key, enabled, requires_login, requires_premium,
                  admin_only, scholar_only, coming_soon, maintenance_mode, display_order,
                  app_store_visible, local_test_visible, updated_at"#,
    )
    .bind(&feature_key)
    .bind(&body.title_en)
    .bind(&body.title_ar)
    .bind(&body.description_en)
    .bind(&body.description_ar)
    .bind(&body.category)
    .bind(&body.icon_key)
    .bind(body.enabled)
    .bind(body.requires_login)
    .bind(body.requires_premium)
    .bind(body.admin_only)
    .bind(body.scholar_only)
    .bind(body.coming_soon)
    .bind(body.maintenance_mode)
    .bind(body.display_order)
    .bind(body.app_store_visible)
    .bind(body.local_test_visible)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to update feature"))?;

    let Some(row) = updated else {
        return Err(ApiError::not_found("feature not found"));
    };
    Ok(HttpResponse::Ok().json(feature_row_to_json(&row, true)))
}

pub async fn reset_defaults(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let _admin_id = require_admin(&req, pool.get_ref()).await?;
    sqlx::query("DELETE FROM public.app_feature_flags")
        .execute(pool.get_ref())
        .await
        .map_err(|_| ApiError::internal("failed to reset features"))?;

    sqlx::raw_sql(include_str!("../../db/seeds/app_feature_flags_defaults.sql"))
        .execute(pool.get_ref())
        .await
        .map_err(|_| ApiError::internal("failed to reseed features"))?;

    let items = fetch_all_features(pool.get_ref()).await?;
    Ok(HttpResponse::Ok().json(json!({
        "status": "reset",
        "features": items,
        "count": items.len(),
    })))
}

pub async fn app_status(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let _admin_id = require_admin(&req, pool.get_ref()).await?;
    let row = sqlx::query(
        r#"SELECT
            COUNT(*)::int AS total,
            COUNT(*) FILTER (WHERE enabled)::int AS enabled,
            COUNT(*) FILTER (WHERE NOT enabled)::int AS disabled,
            COUNT(*) FILTER (WHERE requires_premium)::int AS premium,
            COUNT(*) FILTER (WHERE requires_login)::int AS login_required,
            COUNT(*) FILTER (WHERE coming_soon)::int AS coming_soon,
            COUNT(*) FILTER (WHERE maintenance_mode)::int AS maintenance
           FROM public.app_feature_flags"#,
    )
    .fetch_one(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load app status"))?;

    let env = std::env::var("SAKINA_ENV")
        .unwrap_or_else(|_| "local".to_string());

    Ok(HttpResponse::Ok().json(json!({
        "app_mode": env,
        "total_features": row.get::<i32, _>("total"),
        "enabled_features": row.get::<i32, _>("enabled"),
        "disabled_features": row.get::<i32, _>("disabled"),
        "premium_features": row.get::<i32, _>("premium"),
        "login_required_features": row.get::<i32, _>("login_required"),
        "coming_soon_features": row.get::<i32, _>("coming_soon"),
        "maintenance_features": row.get::<i32, _>("maintenance"),
    })))
}
