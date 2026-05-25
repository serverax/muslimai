use actix_web::{web, App, HttpServer, middleware::Logger};
use sqlx::postgres::PgPool;
use tracing::info;

use sakina_backend::{brand, handlers, middleware, services, telemetry};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    telemetry::init();

    // Project Sakina brand banner (single source of truth: src/brand.rs)
    let (motto_en, motto_ar) = brand::get_brand_motto();
    info!("[{}] {}", brand::SAKINA.name, brand::SAKINA.tagline);
    info!("[{}] Vision: {}", brand::SAKINA.name, brand::SAKINA.vision);
    info!("[{}] Mission: {}", brand::SAKINA.name, brand::SAKINA.mission);
    info!("[{}] Promise: {}", brand::SAKINA.name, brand::get_brand_promise());
    info!("[{}] Motto: {} / {}", brand::SAKINA.name, motto_en, motto_ar);
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
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://sakina_user:sakina_password@localhost:5432/sakina".to_string());

    let pool = PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to database");

    info!("Connected to PostgreSQL");

    // Phase 1 services — wired into handlers via app_data.
    let router = std::sync::Arc::new(services::SemanticRouter::new());
    let guardrails = std::sync::Arc::new(services::Guardrails::new(0.85));
    let citations = std::sync::Arc::new(services::CitationEngine::new(pool.clone()));

    // Background worker: drain the outbox (marks chunk_indexed events Sent).
    let relay = services::OutboxRelay::new(pool.clone());
    tokio::spawn(async move {
        if let Err(e) = relay.relay_events().await {
            tracing::error!("outbox relay stopped: {}", e);
        }
    });

    // RAG dependencies: Qdrant via REST + vLLM embeddings via HTTP (lazy — no
    // connection until a request actually uses them).
    let qdrant = web::Data::new(services::QdrantVectorDB::new(
        "http://localhost:6333",
        "verified_knowledge",
    ));
    let embeddings =
        web::Data::new(services::EmbeddingsService::new("http://localhost:8000"));

    // Start HTTP server
    info!("Starting HTTP server on 0.0.0.0:8080");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .app_data(web::Data::new(router.clone()))
            .app_data(web::Data::new(guardrails.clone()))
            .app_data(web::Data::new(citations.clone()))
            .app_data(qdrant.clone())
            .app_data(embeddings.clone())
            .wrap(Logger::default())
            .wrap(middleware::AuditMiddleware)
            .service(
                web::scope("/v1")
                    .route("/health", web::get().to(handlers::health::health_check))
                    .service(
                        web::scope("/users")
                            .route("", web::post().to(handlers::user::create_user))
                            .route("/{user_id}", web::get().to(handlers::user::get_user))
                    )
                    .service(
                        web::scope("/rag")
                            .route("/query", web::post().to(handlers::rag::query_rag))
                    )
                    .route("/classify", web::post().to(handlers::classify::classify_intent))
                    .service(
                        web::scope("/sync")
                            .route("/backup", web::post().to(handlers::sync::upload_backup))
                            .route("/backup/{user_id}", web::get().to(handlers::sync::download_backup))
                    )
                    .service(
                        web::scope("/dashboard")
                            .route("/guardrails", web::get().to(handlers::dashboard::get_guardrails))
                    )
            )
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
