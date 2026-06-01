use actix_web::{http::StatusCode, test, web, App};
use sakina_backend::handlers::iman_journey;
use sakina_backend::services::ImanJourneyService;
use sqlx::PgPool;
use uuid::Uuid;

async fn maybe_pool() -> Option<PgPool> {
    let database_url = std::env::var("DATABASE_URL").ok()?;
    PgPool::connect(&database_url).await.ok()
}

async fn migrate(pool: &PgPool) -> bool {
    sqlx::raw_sql(include_str!(
        "../db/20260529_phase3_full_product_schema_revision2.sql"
    ))
    .execute(pool)
    .await
    .is_ok()
        && sqlx::raw_sql(include_str!("../db/20260601_phase20_islamic_knowledge_schema.sql"))
            .execute(pool)
            .await
            .is_ok()
        && sqlx::raw_sql(include_str!("../db/20260602_phase21_daily_iman_journey.sql"))
            .execute(pool)
            .await
            .is_ok()
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

#[actix_rt::test]
async fn phase21_core_flow_enforces_fallback_privacy_and_scope() {
    let Some(pool) = maybe_pool().await else {
        eprintln!("DATABASE_URL not set; skipping phase21 iman journey contract test");
        return;
    };
    if !migrate(&pool).await {
        eprintln!("required migrations failed; skipping phase21 iman journey contract test");
        return;
    }

    let user_a = create_user(&pool, "a").await;
    let user_b = create_user(&pool, "b").await;
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
            .insert_header(("x-sakina-user-id", user_a.to_string()))
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
            .insert_header(("x-sakina-user-id", user_a.to_string()))
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
            .insert_header(("x-sakina-user-id", user_a.to_string()))
            .set_json(serde_json::json!({ "dua_text": "Ease in my obligations" }))
            .to_request(),
    )
    .await;
    assert_eq!(add_dua_resp.status(), StatusCode::CREATED);

    let list_dua_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/v1/dua-list/{user_a}"))
            .insert_header(("x-sakina-user-id", user_a.to_string()))
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
            .insert_header(("x-sakina-user-id", user_b.to_string()))
            .to_request(),
    )
    .await;
    assert_eq!(unauthorized_resp.status(), StatusCode::UNAUTHORIZED);
}
