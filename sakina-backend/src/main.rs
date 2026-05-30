use actix_cors::Cors;
use actix_web::{middleware::Logger, web, App, HttpResponse, HttpServer};
use serde_json::json;
use sqlx::postgres::PgPoolOptions;
use tracing::info;

use sakina_backend::{brand, handlers, middleware, services, telemetry};

fn missing_required_env_vars() -> Vec<&'static str> {
    const REQUIRED_ENV_VARS: [&str; 1] = ["DATABASE_URL"];
    REQUIRED_ENV_VARS
        .iter()
        .copied()
        .filter(|key| {
            std::env::var(key)
                .ok()
                .map(|value| value.trim().is_empty())
                .unwrap_or(true)
        })
        .collect()
}

async fn readiness_check(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let db_reachable = pool.acquire().await.is_ok();
    let waitlist_table_exists = if db_reachable {
        sqlx::query_scalar::<_, Option<String>>("SELECT to_regclass('sakina_ai.waitlist')::text")
            .fetch_one(pool.get_ref())
            .await
            .ok()
            .flatten()
            .is_some()
    } else {
        false
    };
    let missing_env_vars = missing_required_env_vars();
    let is_ready = db_reachable && waitlist_table_exists && missing_env_vars.is_empty();
    let status = if is_ready { "ready" } else { "not_ready" };

    let response = json!({
        "status": status,
        "service": "Project Sakina API",
        "checks": {
            "database_reachable": db_reachable,
            "waitlist_table_exists": waitlist_table_exists,
            "required_env_present": missing_env_vars.is_empty(),
        },
        "missing_env_vars": missing_env_vars
    });

    if is_ready {
        HttpResponse::Ok().json(response)
    } else {
        HttpResponse::ServiceUnavailable().json(response)
    }
}

fn build_cors() -> Cors {
    let allowed_origins = std::env::var("CORS_ALLOWED_ORIGINS")
        .unwrap_or_else(|_| {
            "https://7jzi.com,https://www.7jzi.com,http://7jzi.com,http://www.7jzi.com".to_string()
        })
        .split(',')
        .map(str::trim)
        .filter(|origin| !origin.is_empty())
        .map(ToOwned::to_owned)
        .collect::<Vec<String>>();

    let mut cors = Cors::default()
        .allowed_methods(vec!["GET", "POST", "OPTIONS"])
        .allowed_headers(vec![
            actix_web::http::header::AUTHORIZATION,
            actix_web::http::header::CONTENT_TYPE,
            actix_web::http::header::ACCEPT,
            actix_web::http::header::HeaderName::from_static("x-sakina-user-id"),
        ])
        .max_age(3600);

    for origin in allowed_origins {
        cors = cors.allowed_origin(&origin);
    }
    cors
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    telemetry::init();

    // Project Sakina brand banner (single source of truth: src/brand.rs)
    let (motto_en, motto_ar) = brand::get_brand_motto();
    info!("[{}] {}", brand::SAKINA.name, brand::SAKINA.tagline);
    info!("[{}] Vision: {}", brand::SAKINA.name, brand::SAKINA.vision);
    info!(
        "[{}] Mission: {}",
        brand::SAKINA.name,
        brand::SAKINA.mission
    );
    info!(
        "[{}] Promise: {}",
        brand::SAKINA.name,
        brand::get_brand_promise()
    );
    info!(
        "[{}] Motto: {} / {}",
        brand::SAKINA.name,
        motto_en,
        motto_ar
    );
    for value in brand::SAKINA.values {
        info!("[{}] Value: {}", brand::SAKINA.name, value);
    }
    info!(
        "[{}] Theme primary={} accent={} bg={} text={} error={}",
        brand::SAKINA.name,
        brand::BRAND_COLORS.primary,
        brand::BRAND_COLORS.accent,
        brand::BRAND_COLORS.background,
        brand::BRAND_COLORS.text,
        brand::BRAND_COLORS.error
    );

    info!("[{}] Starting Sakina API Server", brand::SAKINA.name);

    // Database connection
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool_max_connections = std::env::var("DATABASE_MAX_CONNECTIONS")
        .ok()
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(20);
    let pool = PgPoolOptions::new()
        .max_connections(pool_max_connections)
        .acquire_timeout(std::time::Duration::from_secs(10))
        .idle_timeout(std::time::Duration::from_secs(300))
        .connect(&database_url)
        .await
        .expect("Failed to connect to database");

    info!("Connected to PostgreSQL");

    // Phase 1 services — wired into handlers via app_data.
    let router = std::sync::Arc::new(services::SemanticRouter::new());
    let guardrails = std::sync::Arc::new(services::Guardrails::new(0.85));
    let phase2_repo = services::Phase2Repository::new(pool.clone());
    let router_data = web::Data::new(router.clone());
    let guardrails_data = web::Data::new(guardrails.clone());
    let phase2_repo_data = web::Data::new(phase2_repo.clone());

    // Background worker: drain the outbox (marks chunk_indexed events Sent).
    let relay = services::OutboxRelay::new(pool.clone());
    tokio::spawn(async move {
        if let Err(e) = relay.relay_events().await {
            tracing::error!("outbox relay stopped: {}", e);
        }
    });

    // RAG dependencies: Qdrant via REST + vLLM embeddings via HTTP (lazy — no
    // connection until a request actually uses them).
    let qdrant_url =
        std::env::var("QDRANT_URL").unwrap_or_else(|_| "http://localhost:6333".to_string());
    let qdrant_collection =
        std::env::var("QDRANT_COLLECTION").unwrap_or_else(|_| "verified_knowledge".to_string());
    let vllm_url =
        std::env::var("VLLM_URL").unwrap_or_else(|_| "http://localhost:8000".to_string());
    let qdrant = web::Data::new(services::QdrantVectorDB::new(
        &qdrant_url,
        &qdrant_collection,
    ));
    let embeddings = web::Data::new(services::EmbeddingsService::new(&vllm_url));
    let waitlist_limiter = web::Data::new(handlers::waitlist::WaitlistRateLimiter::new(
        5,
        std::time::Duration::from_secs(60),
    ));
    // Start HTTP server
    info!("Starting HTTP server on 0.0.0.0:8080");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .app_data(router_data.clone())
            .app_data(guardrails_data.clone())
            .app_data(phase2_repo_data.clone())
            .app_data(qdrant.clone())
            .app_data(embeddings.clone())
            .app_data(waitlist_limiter.clone())
            .app_data(
                web::JsonConfig::default()
                    .limit(256 * 1024)
                    .error_handler(|err, _| {
                        actix_web::error::InternalError::from_response(
                            err,
                            sakina_backend::error::error_response(
                                actix_web::http::StatusCode::BAD_REQUEST,
                                "bad_request",
                                "invalid or oversized request payload",
                            ),
                        )
                        .into()
                    }),
            )
            .wrap(build_cors())
            .wrap(Logger::default())
            .wrap(middleware::AuditMiddleware)
            .route("/health", web::get().to(handlers::health::health_check))
            .route("/ready", web::get().to(readiness_check))
            .route("/metrics", web::get().to(handlers::ops::metrics))
            .route(
                "/waitlist",
                web::post().to(handlers::waitlist::create_waitlist_entry),
            )
            .service(
                web::scope("/modules")
                    .route("", web::get().to(handlers::modules::modules_status))
                    .route(
                        "/chat/status",
                        web::get().to(handlers::modules::chat_status),
                    )
                    .route(
                        "/quran/status",
                        web::get().to(handlers::modules::quran_status),
                    )
                    .route(
                        "/prayer/status",
                        web::get().to(handlers::modules::prayer_status),
                    )
                    .route(
                        "/community/status",
                        web::get().to(handlers::modules::community_status),
                    )
                    .route(
                        "/knowledge/status",
                        web::get().to(handlers::modules::knowledge_status),
                    ),
            )
            .service(
                web::scope("/chat")
                    .route(
                        "/conversations",
                        web::post().to(handlers::chat::create_conversation),
                    )
                    .route(
                        "/conversations/{id}",
                        web::get().to(handlers::chat::get_conversation),
                    )
                    .route(
                        "/conversations/{id}/messages",
                        web::post().to(handlers::chat::add_message),
                    ),
            )
            .service(
                web::scope("/v1")
                    .route("/health", web::get().to(handlers::health::health_check))
                    .route("/ready", web::get().to(readiness_check))
                    .route("/metrics", web::get().to(handlers::ops::metrics))
                    .route(
                        "/waitlist",
                        web::post().to(handlers::waitlist::create_waitlist_entry),
                    )
                    .route("/users/pubkey", web::get().to(handlers::user::get_server_pubkey))
                    .service(
                        web::scope("/auth")
                            .route("/register", web::post().to(handlers::phase2::register_user))
                            .route(
                                "/sessions",
                                web::post().to(handlers::phase2::create_session),
                            ),
                    )
                    .service(
                        web::scope("/profiles")
                            .route(
                                "/{user_id}",
                                web::put().to(handlers::phase2::upsert_profile),
                            )
                            .route(
                                "/{user_id}/family",
                                web::post().to(handlers::phase2::create_family_profile),
                            ),
                    )
                    .service(
                        web::scope("/subscriptions")
                            .route(
                                "/{user_id}/activate",
                                web::post().to(handlers::phase2::activate_subscription),
                            )
                            .route(
                                "/{user_id}/entitlements",
                                web::get().to(handlers::phase2::list_entitlements),
                            ),
                    )
                    .service(
                        web::scope("/modules")
                            .route("", web::get().to(handlers::modules::modules_status))
                            .route(
                                "/chat/status",
                                web::get().to(handlers::modules::chat_status),
                            )
                            .route(
                                "/quran/status",
                                web::get().to(handlers::modules::quran_status),
                            )
                            .route(
                                "/prayer/status",
                                web::get().to(handlers::modules::prayer_status),
                            )
                            .route(
                                "/community/status",
                                web::get().to(handlers::modules::community_status),
                            )
                            .route(
                                "/knowledge/status",
                                web::get().to(handlers::modules::knowledge_status),
                            )
                            .route(
                                "/quran/overview",
                                web::get().to(handlers::modules::quran_overview),
                            )
                            .route(
                                "/prayer/overview",
                                web::get().to(handlers::modules::prayer_overview),
                            )
                            .route(
                                "/knowledge/overview",
                                web::get().to(handlers::modules::knowledge_overview),
                            )
                            .route(
                                "/community/overview",
                                web::get().to(handlers::modules::community_overview),
                            ),
                    )
                    .service(
                        web::scope("/chat")
                            .route(
                                "/conversations",
                                web::post().to(handlers::chat::create_conversation),
                            )
                            .route(
                                "/conversations/{id}",
                                web::get().to(handlers::chat::get_conversation),
                            )
                            .route(
                                "/conversations/{id}/messages",
                                web::post().to(handlers::chat::add_message),
                            )
                            .route(
                                "/messages/{id}/feedback",
                                web::post().to(handlers::phase2::create_chat_feedback),
                            )
                            .route(
                                "/messages/{id}/report",
                                web::post().to(handlers::phase2::report_answer),
                            ),
                    )
                    .service(
                        web::scope("/rag")
                            .route("/status", web::get().to(handlers::rag::rag_status))
                            .route("/sources", web::get().to(handlers::rag::rag_sources))
                            .route(
                                "/sources/approved",
                                web::get().to(handlers::phase2::approved_rag_sources),
                            )
                            .route("/search", web::get().to(handlers::rag::rag_search))
                            .route("/decide", web::post().to(handlers::rag::rag_decide))
                            .route(
                                "/audit/retrieval",
                                web::post().to(handlers::phase2::log_rag_retrieval),
                            )
                            .route(
                                "/audit/citation",
                                web::post().to(handlers::phase2::log_citation_event),
                            )
                            .route("/query", web::post().to(handlers::rag::query_rag)),
                    )
                    .service(
                        web::scope("/safety")
                            .route(
                                "/classifications",
                                web::post().to(handlers::phase2::log_safety_classification),
                            )
                            .route(
                                "/mastermind-decisions",
                                web::post().to(handlers::phase2::log_mastermind_decision),
                            )
                            .route(
                                "/scholar-review-queue",
                                web::post().to(handlers::phase2::enqueue_scholar_review),
                            )
                            .route(
                                "/wasm-events",
                                web::post().to(handlers::phase2::log_wasm_event),
                            ),
                    )
                    .service(
                        web::scope("/admin")
                            .route(
                                "/roles",
                                web::post().to(handlers::phase2::upsert_admin_role),
                            )
                            .route(
                                "/audit-actions",
                                web::post().to(handlers::phase2::log_admin_action),
                            )
                            .route(
                                "/source-approval-queue",
                                web::get().to(handlers::phase2::source_approval_queue),
                            )
                            .route(
                                "/source-approval-queue",
                                web::post().to(handlers::phase2::create_source_approval_item),
                            )
                            .route(
                                "/scholars",
                                web::post().to(handlers::phase2::create_scholar_account),
                            )
                            .route(
                                "/scholar-assignments",
                                web::post().to(handlers::phase2::assign_scholar_review),
                            ),
                    )
                    .service(
                        web::scope("/notifications")
                            .route(
                                "/templates",
                                web::post().to(handlers::phase2::create_notification_template),
                            )
                            .route(
                                "/send",
                                web::post().to(handlers::phase2::enqueue_notification),
                            )
                            .route(
                                "/device-tokens",
                                web::post().to(handlers::phase2::upsert_device_token),
                            ),
                    )
                    .service(web::scope("/support").route(
                        "/tickets",
                        web::post().to(handlers::phase2::create_support_ticket),
                    ))
                    .service(
                        web::scope("/support")
                            .route(
                                "/tickets/{ticket_id}",
                                web::get().to(handlers::phase2::get_support_ticket),
                            )
                            .route(
                                "/tickets/{ticket_id}/messages",
                                web::post().to(handlers::phase2::append_support_ticket_message),
                            ),
                    )
                    .service(
                        web::scope("/audit")
                            .route("/logs", web::post().to(handlers::phase2::create_audit_log)),
                    )
                    .service(web::scope("/security").route(
                        "/logs",
                        web::post().to(handlers::phase2::create_security_log),
                    ))
                    .service(
                        web::scope("/events")
                            .route("/app", web::post().to(handlers::phase2::create_app_event))
                            .route("/chat", web::post().to(handlers::phase2::create_chat_event))
                            .route("/rag", web::post().to(handlers::phase2::create_rag_event))
                            .route(
                                "/admin",
                                web::post().to(handlers::phase2::create_admin_event),
                            ),
                    )
                    .route(
                        "/classify",
                        web::post().to(handlers::classify::classify_intent),
                    )
                    .service(
                        web::scope("/sync")
                            .route(
                                "/backup/{user_id}",
                                web::post().to(handlers::sync::upload_backup),
                            )
                            .route(
                                "/backup/{user_id}",
                                web::get().to(handlers::sync::download_backup),
                            ),
                    )
                    .service(web::scope("/dashboard").route(
                        "/guardrails",
                        web::get().to(handlers::dashboard::get_guardrails),
                    )),
            )
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{body::to_bytes, http::StatusCode, test};

    #[actix_rt::test]
    async fn route_aliases_are_wired_for_root_and_v1() {
        // Safe for tests: readiness now only requires DATABASE_URL presence.
        std::env::set_var("DATABASE_URL", "postgres://test:test@localhost/test");
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");

        let app =
            test::init_service(
                App::new()
                    .app_data(web::Data::new(pool))
                    .app_data(web::Data::new(
                        handlers::waitlist::WaitlistRateLimiter::new(
                            50,
                            std::time::Duration::from_secs(60),
                        ),
                    ))
                    .app_data(web::JsonConfig::default().limit(256 * 1024).error_handler(
                        |err, _| {
                            actix_web::error::InternalError::from_response(
                                err,
                                sakina_backend::error::error_response(
                                    actix_web::http::StatusCode::BAD_REQUEST,
                                    "bad_request",
                                    "invalid or oversized request payload",
                                ),
                            )
                            .into()
                        },
                    ))
                    .route("/health", web::get().to(handlers::health::health_check))
                    .route("/ready", web::get().to(readiness_check))
                    .route("/metrics", web::get().to(handlers::ops::metrics))
                    .route(
                        "/waitlist",
                        web::post().to(handlers::waitlist::create_waitlist_entry),
                    )
                    .service(
                        web::scope("/modules")
                            .route("", web::get().to(handlers::modules::modules_status))
                            .route(
                                "/chat/status",
                                web::get().to(handlers::modules::chat_status),
                            )
                            .route(
                                "/quran/status",
                                web::get().to(handlers::modules::quran_status),
                            )
                            .route(
                                "/prayer/status",
                                web::get().to(handlers::modules::prayer_status),
                            )
                            .route(
                                "/community/status",
                                web::get().to(handlers::modules::community_status),
                            )
                            .route(
                                "/knowledge/status",
                                web::get().to(handlers::modules::knowledge_status),
                            ),
                    )
                    .service(
                        web::scope("/chat")
                            .route(
                                "/conversations",
                                web::post().to(handlers::chat::create_conversation),
                            )
                            .route(
                                "/conversations/{id}",
                                web::get().to(handlers::chat::get_conversation),
                            )
                            .route(
                                "/conversations/{id}/messages",
                                web::post().to(handlers::chat::add_message),
                            ),
                    )
                    .service(
                        web::scope("/v1")
                            .route("/health", web::get().to(handlers::health::health_check))
                            .route("/ready", web::get().to(readiness_check))
                            .route("/metrics", web::get().to(handlers::ops::metrics))
                            .route(
                                "/waitlist",
                                web::post().to(handlers::waitlist::create_waitlist_entry),
                            )
                            .service(
                                web::scope("/modules")
                                    .route("", web::get().to(handlers::modules::modules_status))
                                    .route(
                                        "/chat/status",
                                        web::get().to(handlers::modules::chat_status),
                                    )
                                    .route(
                                        "/quran/status",
                                        web::get().to(handlers::modules::quran_status),
                                    )
                                    .route(
                                        "/prayer/status",
                                        web::get().to(handlers::modules::prayer_status),
                                    )
                                    .route(
                                        "/community/status",
                                        web::get().to(handlers::modules::community_status),
                                    )
                                    .route(
                                        "/knowledge/status",
                                        web::get().to(handlers::modules::knowledge_status),
                                    ),
                            )
                            .service(
                                web::scope("/chat")
                                    .route(
                                        "/conversations",
                                        web::post().to(handlers::chat::create_conversation),
                                    )
                                    .route(
                                        "/conversations/{id}",
                                        web::get().to(handlers::chat::get_conversation),
                                    )
                                    .route(
                                        "/conversations/{id}/messages",
                                        web::post().to(handlers::chat::add_message),
                                    ),
                            ),
                    ),
            )
            .await;

        let health_root =
            test::call_service(&app, test::TestRequest::get().uri("/health").to_request()).await;
        let health_v1 = test::call_service(
            &app,
            test::TestRequest::get().uri("/v1/health").to_request(),
        )
        .await;
        assert_eq!(health_root.status(), StatusCode::OK);
        assert_eq!(health_v1.status(), StatusCode::OK);

        let metrics_root =
            test::call_service(&app, test::TestRequest::get().uri("/metrics").to_request()).await;
        let metrics_v1 = test::call_service(
            &app,
            test::TestRequest::get().uri("/v1/metrics").to_request(),
        )
        .await;
        assert_eq!(metrics_root.status(), StatusCode::OK);
        assert_eq!(metrics_v1.status(), StatusCode::OK);
        let metrics_body = to_bytes(metrics_root.into_body())
            .await
            .expect("metrics body");
        let metrics_text = String::from_utf8(metrics_body.to_vec()).expect("utf8");
        assert!(metrics_text.contains("sakina_backend_up 1"));

        let ready_root =
            test::call_service(&app, test::TestRequest::get().uri("/ready").to_request()).await;
        let ready_v1 =
            test::call_service(&app, test::TestRequest::get().uri("/v1/ready").to_request()).await;
        assert_eq!(ready_root.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(ready_v1.status(), StatusCode::SERVICE_UNAVAILABLE);

        let waitlist_bad_root = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/waitlist")
                .set_json(json!({"name":"x","email":"bad-email"}))
                .to_request(),
        )
        .await;
        let waitlist_bad_v1 = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/v1/waitlist")
                .set_json(json!({"name":"x","email":"bad-email"}))
                .to_request(),
        )
        .await;
        assert_eq!(waitlist_bad_root.status(), StatusCode::BAD_REQUEST);
        assert_eq!(waitlist_bad_v1.status(), StatusCode::BAD_REQUEST);

        let waitlist_bad_body = to_bytes(waitlist_bad_root.into_body())
            .await
            .expect("waitlist bad request body");
        let waitlist_bad_text = String::from_utf8(waitlist_bad_body.to_vec()).expect("utf8");
        assert!(waitlist_bad_text.contains("\"error\""));
        assert!(waitlist_bad_text.contains("\"code\":\"bad_request\""));

        let malformed_payload = "{\"name\":\"x\",";
        let parse_error = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/v1/waitlist")
                .insert_header(("content-type", "application/json"))
                .set_payload(malformed_payload)
                .to_request(),
        )
        .await;
        assert_eq!(parse_error.status(), StatusCode::BAD_REQUEST);
        let parse_body = to_bytes(parse_error.into_body())
            .await
            .expect("json parse error body");
        let parse_text = String::from_utf8(parse_body.to_vec()).expect("utf8");
        assert!(parse_text.contains("\"error\""));
        assert!(parse_text.contains("\"code\":\"bad_request\""));
        assert!(parse_text.contains("invalid or oversized request payload"));

        let modules_root =
            test::call_service(&app, test::TestRequest::get().uri("/modules").to_request()).await;
        let modules_v1 = test::call_service(
            &app,
            test::TestRequest::get().uri("/v1/modules").to_request(),
        )
        .await;
        assert_eq!(modules_root.status(), StatusCode::OK);
        assert_eq!(modules_v1.status(), StatusCode::OK);

        let chat_status_root = test::call_service(
            &app,
            test::TestRequest::get()
                .uri("/modules/chat/status")
                .to_request(),
        )
        .await;
        let chat_status_v1 = test::call_service(
            &app,
            test::TestRequest::get()
                .uri("/v1/modules/chat/status")
                .to_request(),
        )
        .await;
        assert_eq!(chat_status_root.status(), StatusCode::OK);
        assert_eq!(chat_status_v1.status(), StatusCode::OK);
    }
}
