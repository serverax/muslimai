use actix_web::{web, HttpResponse};
use serde::{Deserialize, Serialize};

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

pub async fn create_waitlist_entry(
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<WaitlistRequest>,
) -> HttpResponse {
    let req = payload.into_inner();

    if req.name.trim().is_empty() || req.email.trim().is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "name and email are required"
        }));
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
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "failed to save waitlist entry"
            }))
        }
    }
}
