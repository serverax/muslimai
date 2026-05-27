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
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<WaitlistRequest>,
) -> HttpResponse {
    let req = payload.into_inner();

    if req.name.trim().is_empty() || req.email.trim().is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "name and email are required"
        }));
    }
    if !is_valid_email(&req.email) {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "email is invalid"
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

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;
    use sqlx::{PgPool, Row};
    use uuid::Uuid;

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

    async fn maybe_pool() -> Option<PgPool> {
        let database_url = match std::env::var("DATABASE_URL") {
            Ok(v) if !v.trim().is_empty() => v,
            _ => return None,
        };
        PgPool::connect(&database_url).await.ok()
    }

    #[actix_rt::test]
    async fn invalid_email_returns_bad_request() {
        let pool = PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = create_waitlist_entry(
            web::Data::new(pool),
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
    }

    #[actix_rt::test]
    async fn insert_and_duplicate_email_are_clean() {
        let Some(pool) = maybe_pool().await else {
            eprintln!("DATABASE_URL not set; skipping DB-backed waitlist test");
            return;
        };
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

        let first =
            create_waitlist_entry(web::Data::new(pool.clone()), web::Json(base_request)).await;
        assert_eq!(first.status(), actix_web::http::StatusCode::OK);

        let second = create_waitlist_entry(
            web::Data::new(pool.clone()),
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
            web::Data::new(pool),
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
}
