use actix_web::{middleware::Logger, web, App, HttpResponse, HttpServer};
use sqlx::postgres::PgPoolOptions;
use tracing::info;

use sakina_backend::{brand, handlers, middleware, services, telemetry};

async fn readiness_check(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let db_status = pool.acquire().await.is_ok();
    if db_status {
        HttpResponse::Ok().json(serde_json::json!({
            "status": "ready",
            "service": "Project Sakina API"
        }))
    } else {
        HttpResponse::ServiceUnavailable().json(serde_json::json!({
            "status": "not_ready",
            "service": "Project Sakina API"
        }))
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
            .service(
                web::scope("/v1")
                    .route("/health", web::get().to(handlers::health::health_check))
                    .route("/ready", web::get().to(readiness_check))
                    .service(
                        web::scope("/users")
                            .route("", web::post().to(handlers::user::create_user))
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
