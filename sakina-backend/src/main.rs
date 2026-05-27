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
    let citations = std::sync::Arc::new(services::CitationEngine::new(pool.clone()));
    let router_data = web::Data::new(router.clone());
    let guardrails_data = web::Data::new(guardrails.clone());
    let citations_data = web::Data::new(citations.clone());

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
            .app_data(citations_data.clone())
            .app_data(qdrant.clone())
            .app_data(embeddings.clone())
            .app_data(waitlist_limiter.clone())
            .app_data(
                web::JsonConfig::default()
                    .limit(256 * 1024)
                    .error_handler(|err, _| {
                        actix_web::error::InternalError::from_response(
                            err,
                            actix_web::HttpResponse::BadRequest().json(serde_json::json!({
                                "error": "invalid or oversized request payload"
                            })),
                        )
                        .into()
                    }),
            )
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
                web::scope("/v1")
                    .route("/health", web::get().to(handlers::health::health_check))
                    .route("/ready", web::get().to(readiness_check))
                    .route("/metrics", web::get().to(handlers::ops::metrics))
                    .route(
                        "/waitlist",
                        web::post().to(handlers::waitlist::create_waitlist_entry),
                    )
                    .service(
                        web::scope("/users")
                            .route("", web::post().to(handlers::user::create_user))
                            .route("/pubkey", web::get().to(handlers::user::get_server_pubkey))
                            .route("/{user_id}", web::get().to(handlers::user::get_user)),
                    )
                    .service(
                        web::scope("/rag")
                            .route("/query", web::post().to(handlers::rag::query_rag)),
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

        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(pool))
                .app_data(web::Data::new(
                    handlers::waitlist::WaitlistRateLimiter::new(
                        50,
                        std::time::Duration::from_secs(60),
                    ),
                ))
                .route("/health", web::get().to(handlers::health::health_check))
                .route("/ready", web::get().to(readiness_check))
                .route("/metrics", web::get().to(handlers::ops::metrics))
                .route(
                    "/waitlist",
                    web::post().to(handlers::waitlist::create_waitlist_entry),
                )
                .service(
                    web::scope("/v1")
                        .route("/health", web::get().to(handlers::health::health_check))
                        .route("/ready", web::get().to(readiness_check))
                        .route("/metrics", web::get().to(handlers::ops::metrics))
                        .route(
                            "/waitlist",
                            web::post().to(handlers::waitlist::create_waitlist_entry),
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
    }
}
