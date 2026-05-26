use crate::models::User;
use actix_web::{web, HttpResponse};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

pub async fn create_user(
    _pool: web::Data<PgPool>,
    body: web::Json<serde_json::Value>,
) -> HttpResponse {
    let user_id = Uuid::new_v4();
    let pub_key = body.get("pub_key").and_then(|v| v.as_str()).unwrap_or("");
    let madhhab = body
        .get("madhhab_preference")
        .and_then(|v| v.as_str())
        .unwrap_or("hanafi");

    // TODO: Insert into database
    let _ = User {
        id: user_id,
        pub_key: pub_key.to_string(),
        madhhab_preference: madhhab.to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
    };

    HttpResponse::Created().json(json!({
        "id": user_id,
        "pub_key": pub_key,
        "madhhab_preference": madhhab,
        "created_at": chrono::Utc::now().to_rfc3339()
    }))
}

pub async fn get_user(_pool: web::Data<PgPool>, user_id: web::Path<Uuid>) -> HttpResponse {
    HttpResponse::Ok().json(json!({
        "id": user_id.into_inner(),
        "message": "User handler stub"
    }))
}
