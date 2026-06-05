use actix_web::{http::StatusCode, test, web, App};
use sakina_backend::handlers::iman_journey;
use sakina_backend::services::ImanJourneyService;
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

async fn required_pool() -> PgPool {
    let database_url =
        std::env::var("DATABASE_URL").expect("DATABASE_URL is required for phase21 DB test");
    PgPool::connect(&database_url)
        .await
        .expect("connect phase21 DB integration pool")
}

async fn migrate(pool: &PgPool) {
    sqlx::raw_sql(include_str!(
        "../db/20260529_phase3_full_product_schema_revision2.sql"
    ))
    .execute(pool)
    .await
    .expect("apply phase3 schema");
    sqlx::raw_sql(include_str!(
        "../db/20260602_phase21_daily_iman_journey.sql"
    ))
    .execute(pool)
    .await
    .expect("apply phase21 schema");
}

async fn create_user(pool: &PgPool, seed: &str) -> Uuid {
    sqlx::query_scalar(
        r#"
        INSERT INTO public.users (email, auth_provider, is_active)
        VALUES ($1, 'phase21_test', true)
        RETURNING id
        "#,
    )
    .bind(format!("phase21-{seed}-{}@example.com", Uuid::new_v4()))
    .fetch_one(pool)
    .await
    .expect("insert test user")
}

fn token_hash(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    format!("{:x}", digest)
}

async fn create_session(pool: &PgPool, user_id: Uuid, _seed: &str) -> String {
    std::env::set_var(
        "SAKINA_JWT_SECRET",
        "sakina-integration-test-jwt-secret-32-byte-minimum",
    );
    let token = sakina_backend::services::auth::issue_jwt(user_id, 3600)
        .expect("issue phase21 test JWT")
        .0;
    sqlx::query(
        r#"
        INSERT INTO public.auth_sessions (user_id, session_token_hash, expires_at)
        VALUES ($1, $2, now() + interval '1 hour')
        "#,
    )
    .bind(user_id)
    .bind(token_hash(&token))
    .execute(pool)
    .await
    .expect("insert phase21 test auth session");
    token
}

#[actix_rt::test]
async fn phase21_core_flow_enforces_fallback_privacy_and_scope() {
    let pool = required_pool().await;
    migrate(&pool).await;

    let user_a = create_user(&pool, "a").await;
    let user_b = create_user(&pool, "b").await;
    let token_a = create_session(&pool, user_a, "a").await;
    let token_b = create_session(&pool, user_b, "b").await;
    let service = ImanJourneyService::new(pool.clone());
    let app = test::init_service(
        App::new()
            .app_data(web::Data::new(service))
            .service(web::scope("/v1").configure(iman_journey::configure)),
    )
    .await;

    let privacy_resp = test::call_service(
        &app,
        test::TestRequest::put()
            .uri(&format!("/v1/iman-journey/{user_a}/privacy"))
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .set_json(serde_json::json!({
                "personalization_enabled": true,
                "reminders_enabled": true,
                "store_journey_enabled": true
            }))
            .to_request(),
    )
    .await;
    assert_eq!(privacy_resp.status(), StatusCode::OK);

    let upsert_resp = test::call_service(
        &app,
        test::TestRequest::put()
            .uri(&format!("/v1/iman-journey/{user_a}"))
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .set_json(serde_json::json!({
                "today_focus": "Guard the tongue",
                "continue_yesterday_topic": "Sabr in speech",
                "progress": {
                    "prayer": 4,
                    "quran": 2,
                    "dhikr": 35
                },
                "family_reminder": {
                    "consent_granted": false,
                    "reminder_text": "Reminder should not leak without consent",
                    "notify_family": true
                },
                "ask_sakina_today_context": "Keep family interactions gentle.",
                "tomorrow_follow_up": "Review after Fajr",
                "religious_reminder_text": "This should be blocked without evidence",
                "religious_confidence_score": 0.2,
                "evidence_bundle": []
            }))
            .to_request(),
    )
    .await;
    assert_eq!(upsert_resp.status(), StatusCode::OK);
    let upsert_json: serde_json::Value = test::read_body_json(upsert_resp).await;
    assert_eq!(
        upsert_json["religious_reminder"]["safe_fallback"]["reason"],
        "insufficient_evidence"
    );
    assert_eq!(
        upsert_json["religious_reminder"]["evidence_bundle"]
            .as_array()
            .expect("evidence bundle")
            .len(),
        0
    );
    assert_eq!(
        upsert_json["family_reminder"]["reminder_text"],
        serde_json::Value::Null
    );
    assert_eq!(upsert_json["privacy_settings"]["reminders_enabled"], true);

    let add_dua_resp = test::call_service(
        &app,
        test::TestRequest::post()
            .uri(&format!("/v1/dua-list/{user_a}"))
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .set_json(serde_json::json!({ "dua_text": "Ease in my obligations" }))
            .to_request(),
    )
    .await;
    assert_eq!(add_dua_resp.status(), StatusCode::CREATED);

    let list_dua_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/v1/dua-list/{user_a}"))
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .to_request(),
    )
    .await;
    assert_eq!(list_dua_resp.status(), StatusCode::OK);
    let dua_json: serde_json::Value = test::read_body_json(list_dua_resp).await;
    assert_eq!(
        dua_json["items"].as_array().expect("dua items").len(),
        1,
        "dua list is user scoped"
    );

    let unauthorized_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/v1/iman-journey/{user_a}"))
            .insert_header(("Authorization", format!("Bearer {token_b}")))
            .to_request(),
    )
    .await;
    assert_eq!(unauthorized_resp.status(), StatusCode::UNAUTHORIZED);
}
