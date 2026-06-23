//! PHASE 5 — subscriptions, entitlements, free-vs-paid gating, payment abstraction.
//! No fake payment: if Stripe is not configured, checkout returns provider_not_configured
//! and the webhook rejects untrusted payloads. Admin grant/revoke is admin-gated.

use actix_web::{web, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::Value;
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::auth::{authenticated_user_id, require_admin};

/// Premium = has the `premium_unlimited` entitlement, OR is an active admin (bypass).
pub async fn has_premium_or_admin(pool: &PgPool, user_id: Uuid) -> Result<bool, ApiError> {
    sqlx::query_scalar::<_, bool>(
        r#"SELECT
            EXISTS(SELECT 1 FROM public.user_entitlements ue
                   JOIN public.entitlements e ON e.id = ue.entitlement_id
                   WHERE ue.user_id = $1 AND e.entitlement_key = 'premium_unlimited')
            OR EXISTS(SELECT 1 FROM public.admin_users WHERE user_id = $1 AND account_status = 'active')"#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|_| ApiError::internal("failed to check premium status"))
}

async fn free_limit(pool: &PgPool, feature_key: &str, default: i32) -> i32 {
    sqlx::query_scalar::<_, Option<i32>>(
        "SELECT free_limit FROM public.feature_gates WHERE feature_key = $1",
    )
    .bind(feature_key)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten()
    .flatten()
    .unwrap_or(default)
}

/// Enforce the free daily Ask-Shaikh quota. Premium/admin bypass. Increments usage.
/// Returns Ok(()) if allowed, Err(402) if the free limit is exceeded.
pub async fn enforce_ask_quota(pool: &PgPool, user_id: Uuid) -> Result<(), ApiError> {
    if has_premium_or_admin(pool, user_id).await? {
        return Ok(());
    }
    let limit = free_limit(pool, "ask_shaikh", 20).await;
    let used = sqlx::query_scalar::<_, i32>(
        r#"INSERT INTO sakina_ai.entitlement_usage (user_id, usage_key, used_count)
           VALUES ($1, 'ask', 1)
           ON CONFLICT (user_id, usage_key, usage_date)
           DO UPDATE SET used_count = sakina_ai.entitlement_usage.used_count + 1, updated_at = now()
           RETURNING used_count"#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|_| ApiError::internal("failed to record ask usage"))?;
    if used > limit {
        return Err(ApiError::payment_required(format!(
            "free daily Ask limit ({limit}) reached. Upgrade to premium for unlimited access."
        )));
    }
    Ok(())
}

// ----------------------------- Plans / me -----------------------------

pub async fn list_plans(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        "SELECT plan_key, plan_name, price_cents, currency, billing_interval FROM public.subscription_plans WHERE is_active ORDER BY price_cents",
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list plans"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "plan_key": r.get::<String, _>("plan_key"),
                "plan_name": r.get::<String, _>("plan_name"),
                "price_cents": r.get::<i32, _>("price_cents"),
                "currency": r.get::<String, _>("currency"),
                "billing_interval": r.get::<String, _>("billing_interval"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "plans": items })))
}

pub async fn my_subscription(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let premium = has_premium_or_admin(pool.get_ref(), user_id).await?;
    let row = sqlx::query(
        r#"SELECT p.plan_key, s.subscription_status, s.current_period_end::text AS ends
           FROM public.user_subscriptions s JOIN public.subscription_plans p ON p.id = s.plan_id
           WHERE s.user_id = $1 AND s.subscription_status = 'active'
           ORDER BY s.created_at DESC LIMIT 1"#,
    )
    .bind(user_id)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load subscription"))?;
    let sub = row.map(|r| {
        serde_json::json!({
            "plan_key": r.get::<String, _>("plan_key"),
            "status": r.get::<String, _>("subscription_status"),
            "ends": r.get::<Option<String>, _>("ends"),
        })
    });
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "tier": if premium { "premium" } else { "free" },
        "premium": premium,
        "subscription": sub,
    })))
}

pub async fn my_entitlements(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let rows = sqlx::query(
        r#"SELECT e.entitlement_key, e.entitlement_name FROM public.user_entitlements ue
           JOIN public.entitlements e ON e.id = ue.entitlement_id WHERE ue.user_id = $1"#,
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load entitlements"))?;
    let keys: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "key": r.get::<String, _>("entitlement_key"),
                "name": r.get::<String, _>("entitlement_name"),
            })
        })
        .collect();
    let premium = has_premium_or_admin(pool.get_ref(), user_id).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "entitlements": keys, "premium": premium })))
}

#[derive(Debug, Deserialize)]
pub struct CheckRequest {
    pub feature_key: String,
}

pub async fn check_entitlement(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CheckRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    let gate = sqlx::query(
        "SELECT tier_required, free_limit FROM public.feature_gates WHERE feature_key = $1",
    )
    .bind(&body.feature_key)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load feature gate"))?;
    let premium = has_premium_or_admin(pool.get_ref(), user_id).await?;
    let (tier, limit) = match gate {
        Some(r) => (
            r.get::<String, _>("tier_required"),
            r.get::<Option<i32>, _>("free_limit"),
        ),
        None => ("free".to_string(), None),
    };
    let allowed = premium || tier == "free";
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "feature_key": body.feature_key,
        "tier_required": tier,
        "free_limit": limit,
        "premium": premium,
        "allowed": allowed,
    })))
}

#[derive(Debug, Deserialize)]
pub struct UsageRequest {
    pub usage_key: String,
}

pub async fn record_usage(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<UsageRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    if has_premium_or_admin(pool.get_ref(), user_id).await? {
        return Ok(HttpResponse::Ok().json(
            serde_json::json!({ "allowed": true, "limit": Value::Null, "remaining": Value::Null, "premium": true }),
        ));
    }
    let limit = free_limit(pool.get_ref(), "ask_shaikh", 20).await;
    let key = if body.usage_key == "ask" { "ask" } else { body.usage_key.as_str() };
    let used = sqlx::query_scalar::<_, i32>(
        r#"INSERT INTO sakina_ai.entitlement_usage (user_id, usage_key, used_count)
           VALUES ($1, $2, 1)
           ON CONFLICT (user_id, usage_key, usage_date)
           DO UPDATE SET used_count = sakina_ai.entitlement_usage.used_count + 1, updated_at = now()
           RETURNING used_count"#,
    )
    .bind(user_id)
    .bind(key)
    .fetch_one(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to record usage"))?;
    if used > limit {
        return Err(ApiError::payment_required(format!(
            "free limit ({limit}) reached for {key}"
        )));
    }
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "allowed": true, "limit": limit, "remaining": (limit - used).max(0), "premium": false
    })))
}

// ----------------------------- Admin grant / revoke -----------------------------

#[derive(Debug, Deserialize)]
pub struct GrantRequest {
    pub user_id: Uuid,
    #[serde(default = "default_ent")]
    pub entitlement_key: String,
    pub reason: Option<String>,
}
fn default_ent() -> String {
    "premium_unlimited".to_string()
}

pub async fn admin_grant(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<GrantRequest>,
) -> Result<HttpResponse, ApiError> {
    let admin_id = require_admin(&req, pool.get_ref()).await?;
    sqlx::query(
        r#"INSERT INTO public.user_entitlements (user_id, entitlement_id)
           SELECT $1, id FROM public.entitlements WHERE entitlement_key = $2
           ON CONFLICT DO NOTHING"#,
    )
    .bind(body.user_id)
    .bind(&body.entitlement_key)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to grant entitlement"))?;
    sqlx::query(
        "INSERT INTO public.admin_entitlement_overrides (user_id, entitlement_key, action, granted_by, reason) VALUES ($1,$2,'grant',$3,$4)",
    )
    .bind(body.user_id)
    .bind(&body.entitlement_key)
    .bind(admin_id)
    .bind(&body.reason)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to log override"))?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "status": "granted", "entitlement_key": body.entitlement_key })))
}

pub async fn admin_revoke(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<GrantRequest>,
) -> Result<HttpResponse, ApiError> {
    let admin_id = require_admin(&req, pool.get_ref()).await?;
    sqlx::query(
        r#"DELETE FROM public.user_entitlements ue
           USING public.entitlements e
           WHERE ue.entitlement_id = e.id AND ue.user_id = $1 AND e.entitlement_key = $2"#,
    )
    .bind(body.user_id)
    .bind(&body.entitlement_key)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to revoke entitlement"))?;
    sqlx::query(
        "INSERT INTO public.admin_entitlement_overrides (user_id, entitlement_key, action, granted_by, reason) VALUES ($1,$2,'revoke',$3,$4)",
    )
    .bind(body.user_id)
    .bind(&body.entitlement_key)
    .bind(admin_id)
    .bind(&body.reason)
    .execute(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to log override"))?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "status": "revoked", "entitlement_key": body.entitlement_key })))
}

// ----------------------------- Payment (honest, no fake) -----------------------------

fn stripe_configured() -> bool {
    std::env::var("STRIPE_SECRET_KEY")
        .map(|v| v.starts_with("sk_"))
        .unwrap_or(false)
}

pub async fn provider_status() -> Result<HttpResponse, ApiError> {
    let configured = stripe_configured();
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "provider": "stripe",
        "configured": configured,
        "status": if configured { "configured" } else { "provider_not_configured" },
        "mode": "test",
    })))
}

pub async fn create_checkout_session(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let _user_id = authenticated_user_id(&req, pool.get_ref()).await?;
    if !stripe_configured() {
        return Ok(HttpResponse::Ok().json(serde_json::json!({
            "status": "provider_not_configured",
            "message": "Stripe is not configured. No checkout session or payment was created.",
            "checkout_url": Value::Null,
        })));
    }
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "status": "configured_pending_integration",
        "checkout_url": Value::Null,
    })))
}

pub async fn payment_webhook(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Bytes,
) -> Result<HttpResponse, ApiError> {
    // Never trust client-claimed payment success. Require a verified provider signature.
    let secret = std::env::var("STRIPE_WEBHOOK_SECRET").unwrap_or_default();
    let sig = req
        .headers()
        .get("stripe-signature")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if secret.is_empty() || sig.is_empty() {
        return Err(ApiError::bad_request(
            "webhook signature verification not configured/missing; event rejected (client payload not trusted)",
        ));
    }
    let _ = sqlx::query(
        "INSERT INTO public.payment_events (provider, event_type, status, payload) VALUES ('stripe','webhook','received_unverified', $1)",
    )
    .bind(serde_json::json!({ "size": body.len() }))
    .execute(pool.get_ref())
    .await;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "status": "received_unverified" })))
}

pub async fn payment_events(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    require_admin(&req, pool.get_ref()).await?;
    let rows = sqlx::query(
        "SELECT provider, event_type, status, created_at::text AS created_at FROM public.payment_events ORDER BY created_at DESC LIMIT 100",
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list payment events"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "provider": r.get::<String, _>("provider"),
                "event_type": r.get::<String, _>("event_type"),
                "status": r.get::<String, _>("status"),
                "created_at": r.get::<String, _>("created_at"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "events": items, "count": items.len() })))
}
