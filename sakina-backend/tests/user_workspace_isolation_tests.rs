use actix_web::{http::StatusCode, test, web, App};
use sakina_backend::handlers::{brain_traces, chat, memory};
use sakina_backend::services::{auth, MemoryEngine, SemanticCacheEntry, SemanticCacheService};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

async fn required_pool() -> PgPool {
    let database_url =
        std::env::var("DATABASE_URL").expect("DATABASE_URL is required for user isolation tests");
    PgPool::connect(&database_url)
        .await
        .expect("connect user isolation DB pool")
}

async fn migrate(pool: &PgPool) {
    sqlx::raw_sql(
        r#"
        CREATE SCHEMA IF NOT EXISTS sakina_ai;
        CREATE OR REPLACE FUNCTION sakina_ai.current_user_id() RETURNS UUID LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('sakina.current_user_id', true), '')::uuid $$;
        CREATE OR REPLACE FUNCTION sakina_ai.rls_service_role() RETURNS BOOLEAN LANGUAGE sql STABLE AS $$ SELECT COALESCE(current_setting('sakina.service_role', true), '') = 'on' OR current_user IN ('sakina_user', 'postgres', 'sakina_staging_user', 'sakina') $$;
        "#
    )
    .execute(pool)
    .await
    .expect("setup rls helpers");

    sqlx::raw_sql(include_str!(
        "../db/20260529_phase3_full_product_schema_revision2.sql"
    ))
    .execute(pool)
    .await
    .expect("apply phase3 schema");
    sqlx::raw_sql(include_str!(
        "../db/migrations/014_brain_knowledge_graph.sql"
    ))
    .execute(pool)
    .await
    .expect("apply brain graph schema");
    sqlx::raw_sql(include_str!(
        "../db/migrations/015_user_memory_multimodal.sql"
    ))
    .execute(pool)
    .await
    .expect("apply memory multimodal schema");
    sqlx::raw_sql(include_str!("../db/migrations/016_password_auth.sql"))
        .execute(pool)
        .await
        .expect("apply password auth schema");
    sqlx::raw_sql(include_str!("../db/migrations/017_rls_user_isolation.sql"))
        .execute(pool)
        .await
        .expect("apply RLS schema");
    sqlx::raw_sql(include_str!(
        "../db/migrations/020_workspace_learning_core.sql"
    ))
    .execute(pool)
    .await
    .expect("apply workspace learning schema");
}

async fn create_user(pool: &PgPool, seed: &str) -> Uuid {
    sqlx::query_scalar(
        r#"
        INSERT INTO public.users (email, auth_provider, is_active)
        VALUES ($1, 'workspace_isolation_test', true)
        RETURNING id
        "#,
    )
    .bind(format!(
        "workspace-isolation-{seed}-{}@example.com",
        Uuid::new_v4()
    ))
    .fetch_one(pool)
    .await
    .expect("insert isolation test user")
}

async fn ensure_workspace(pool: &PgPool, user_id: Uuid) -> Uuid {
    sqlx::query_scalar("SELECT sakina_ai.ensure_default_workspace($1)")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .expect("ensure default workspace")
}

fn token_hash(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    format!("{:x}", digest)
}

async fn create_session(pool: &PgPool, user_id: Uuid) -> String {
    std::env::set_var(
        "SAKINA_JWT_SECRET",
        "sakina-integration-test-jwt-secret-32-byte-minimum",
    );
    let token = auth::issue_jwt(user_id, 3600).expect("issue test JWT").0;
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
    .expect("insert test auth session");
    token
}

async fn users_and_tokens(pool: &PgPool) -> (Uuid, Uuid, String, String, Uuid, Uuid) {
    migrate(pool).await;
    let user_a = create_user(pool, "a").await;
    let user_b = create_user(pool, "b").await;
    let workspace_a = ensure_workspace(pool, user_a).await;
    let workspace_b = ensure_workspace(pool, user_b).await;
    let token_a = create_session(pool, user_a).await;
    let token_b = create_session(pool, user_b).await;
    (user_a, user_b, token_a, token_b, workspace_a, workspace_b)
}

#[actix_rt::test]
async fn user_isolation_test_user_cannot_read_other_user_chat() {
    let pool = required_pool().await;
    let (user_a, _user_b, token_a, token_b, _workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    let conversation_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO sakina_ai.conversations (user_id, title)
        VALUES ($1, 'Private User A chat')
        RETURNING id
        "#,
    )
    .bind(user_a)
    .fetch_one(&pool)
    .await
    .expect("insert private conversation");
    sqlx::query(
        "INSERT INTO sakina_ai.messages (conversation_id, user_id, role, content) VALUES ($1, $2, 'user', 'User A private message')",
    )
    .bind(conversation_id)
    .bind(user_a)
    .execute(&pool)
    .await
    .expect("insert private message");

    let app = test::init_service(App::new().app_data(web::Data::new(pool.clone())).route(
        "/api/chat/conversations/{conversation_id}",
        web::get().to(chat::get_conversation),
    ))
    .await;

    let user_a_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/api/chat/conversations/{conversation_id}"))
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .to_request(),
    )
    .await;
    assert_eq!(user_a_resp.status(), StatusCode::OK);

    let user_b_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/api/chat/conversations/{conversation_id}"))
            .insert_header(("Authorization", format!("Bearer {token_b}")))
            .to_request(),
    )
    .await;
    assert_eq!(user_b_resp.status(), StatusCode::NOT_FOUND);
}

#[actix_rt::test]
async fn user_isolation_test_user_cannot_read_other_user_memory() {
    let pool = required_pool().await;
    let (user_a, _user_b, token_a, token_b, workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.user_memory_entries (
            user_id, workspace_id, memory_key, memory_type, sensitivity_level,
            encrypted_payload, nonce, consent_required, consent_granted, allowed
        )
        VALUES ($1, $2, 'answer_style', 'preference', 'safe', decode('01','hex'), decode('02','hex'), false, true, true)
        "#,
    )
    .bind(user_a)
    .bind(workspace_a)
    .execute(&pool)
    .await
    .expect("insert private memory");

    let engine = MemoryEngine::new(pool.clone());
    let app = test::init_service(
        App::new()
            .app_data(web::Data::new(engine))
            .route("/api/memory", web::get().to(memory::list))
            .route(
                "/api/workspaces/{workspace_id}/memory",
                web::get().to(memory::list_workspace),
            ),
    )
    .await;

    let owner_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri("/api/memory")
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .to_request(),
    )
    .await;
    assert_eq!(owner_resp.status(), StatusCode::OK);

    let cross_user_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/api/workspaces/{workspace_a}/memory"))
            .insert_header(("Authorization", format!("Bearer {token_b}")))
            .to_request(),
    )
    .await;
    assert_eq!(cross_user_resp.status(), StatusCode::NOT_FOUND);
}

#[actix_rt::test]
async fn user_isolation_test_user_cannot_read_other_user_files() {
    let pool = required_pool().await;
    let (user_a, user_b, _token_a, _token_b, workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    let asset_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO sakina_ai.multimodal_assets (
            user_id, workspace_id, asset_type, original_name, storage_scope,
            redacted_text, extracted_text, safety_level, status
        )
        VALUES ($1, $2, 'document', 'private-user-a.pdf', 'user', '', 'private text', 'safe', 'analyzed')
        RETURNING id
        "#,
    )
    .bind(user_a)
    .bind(workspace_a)
    .fetch_one(&pool)
    .await
    .expect("insert private asset");

    let service = sakina_backend::services::MultimodalService::new(pool.clone());
    assert!(service
        .get_asset(user_a, asset_id)
        .await
        .expect("owner asset lookup")
        .is_some());
    assert!(service
        .get_asset(user_b, asset_id)
        .await
        .expect("cross-user asset lookup")
        .is_none());
}

#[actix_rt::test]
async fn user_isolation_test_user_cannot_read_other_user_brain_trace() {
    let pool = required_pool().await;
    let (user_a, _user_b, token_a, token_b, workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    let trace_id = format!("trace-{}", Uuid::new_v4());
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.brain_decision_traces (
            request_id, user_id, workspace_id, input_type, intent, language, risk_level,
            selected_agent, selected_model, selected_pipeline, source_strategy,
            evaluation_result, final_action, audit_event_id, execution_trace
        )
        VALUES ($1, $2, $3, 'chat', 'islamic_support', 'en', 'low',
                'brain', 'local_verified_retrieval', 'hybrid_rag',
                'verified_sources', 'approved', 'respond', $4, '[]'::jsonb)
        "#,
    )
    .bind(&trace_id)
    .bind(user_a.to_string())
    .bind(workspace_a)
    .bind(format!("audit-{trace_id}"))
    .execute(&pool)
    .await
    .expect("insert private brain trace");

    let app = test::init_service(App::new().app_data(web::Data::new(pool.clone())).route(
        "/api/brain/traces/{trace_id}",
        web::get().to(brain_traces::get_trace),
    ))
    .await;

    let owner_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/api/brain/traces/{trace_id}"))
            .insert_header(("Authorization", format!("Bearer {token_a}")))
            .to_request(),
    )
    .await;
    assert_eq!(owner_resp.status(), StatusCode::OK);

    let cross_user_resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/api/brain/traces/{trace_id}"))
            .insert_header(("Authorization", format!("Bearer {token_b}")))
            .to_request(),
    )
    .await;
    assert_eq!(cross_user_resp.status(), StatusCode::NOT_FOUND);
}

#[actix_rt::test]
async fn user_isolation_test_user_cannot_use_other_user_workspace_id() {
    let pool = required_pool().await;
    let (_user_a, _user_b, _token_a, token_b, workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    let engine = MemoryEngine::new(pool.clone());
    let app = test::init_service(App::new().app_data(web::Data::new(engine)).route(
        "/api/workspaces/{workspace_id}/memory",
        web::get().to(memory::list_workspace),
    ))
    .await;

    let resp = test::call_service(
        &app,
        test::TestRequest::get()
            .uri(&format!("/api/workspaces/{workspace_a}/memory"))
            .insert_header(("Authorization", format!("Bearer {token_b}")))
            .to_request(),
    )
    .await;
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);
}

#[actix_rt::test]
async fn user_isolation_test_cache_does_not_leak_private_user_answer() {
    let pool = required_pool().await;
    let (user_a, user_b, _token_a, _token_b, workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    let service = SemanticCacheService::new(pool.clone());
    let entry = SemanticCacheEntry {
        cache_key: format!("private-cache-{}", Uuid::new_v4()),
        user_id: Some(user_a),
        workspace_id: Some(workspace_a),
        language: "en".to_string(),
        intent: "private_memory_answer".to_string(),
        safety_level: "safe".to_string(),
        source_version: "test-source-v1".to_string(),
        hit_count: 0,
        payload: serde_json::json!({"answer":"User A private cached answer"}),
    };
    service.upsert(&entry).await.expect("insert private cache");

    assert!(service
        .lookup(&entry.cache_key, Some(user_a))
        .await
        .expect("owner cache lookup")
        .is_some());
    assert!(service
        .lookup(&entry.cache_key, Some(user_b))
        .await
        .expect("cross-user cache lookup")
        .is_none());
}

#[actix_rt::test]
async fn user_isolation_test_mobile_memory_sync_is_user_scoped() {
    let pool = required_pool().await;
    let (user_a, user_b, _token_a, _token_b, workspace_a, _workspace_b) =
        users_and_tokens(&pool).await;
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.mobile_memory_sync (
            user_id, workspace_id, device_id, local_context_hash, allowed_summary
        )
        VALUES ($1, $2, 'device-a', $3, $4)
        "#,
    )
    .bind(user_a)
    .bind(workspace_a)
    .bind(format!("hash-{}", Uuid::new_v4()))
    .bind(serde_json::json!({"preferred_language":"ar"}))
    .execute(&pool)
    .await
    .expect("insert mobile memory sync row");

    let owner_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM sakina_ai.mobile_memory_sync WHERE user_id = $1")
            .bind(user_a)
            .fetch_one(&pool)
            .await
            .expect("owner mobile memory count");
    let cross_user_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM sakina_ai.mobile_memory_sync WHERE user_id = $1")
            .bind(user_b)
            .fetch_one(&pool)
            .await
            .expect("cross user mobile memory count");

    assert!(owner_count > 0);
    assert_eq!(cross_user_count, 0);
}
