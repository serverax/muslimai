use actix_cors::Cors;
use actix_web::{middleware::Logger, web, App, HttpResponse, HttpServer};
use serde_json::json;
use sqlx::postgres::PgPoolOptions;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tracing::info;

use sakina_backend::{brand, handlers, middleware, services, telemetry};

async fn default_not_found() -> HttpResponse {
    sakina_backend::error::error_response(
        actix_web::http::StatusCode::NOT_FOUND,
        "not_found",
        "route not found",
    )
}

fn build_database_url() -> Result<String, String> {
    if let Ok(value) = std::env::var("DATABASE_URL") {
        let trimmed = value.trim().to_string();
        if !trimmed.is_empty() {
            return Ok(trimmed);
        }
    }

    let host = std::env::var("POSTGRES_HOST").ok();
    let port = std::env::var("POSTGRES_PORT").ok();
    let db = std::env::var("POSTGRES_DB").ok();
    let user = std::env::var("POSTGRES_USER").ok();
    let password = std::env::var("POSTGRES_PASSWORD").ok();

    match (host, port, db, user, password) {
        (Some(host), Some(port), Some(db), Some(user), Some(password))
            if !host.trim().is_empty()
                && !port.trim().is_empty()
                && !db.trim().is_empty()
                && !user.trim().is_empty()
                && !password.trim().is_empty() =>
        {
            Ok(format!(
                "postgres://{}:{}@{}:{}/{}",
                user.trim(),
                password.trim(),
                host.trim(),
                port.trim(),
                db.trim()
            ))
        }
        _ => Err(
            "DATABASE_URL is missing and the POSTGRES_* fallback variables are incomplete"
                .to_string(),
        ),
    }
}

fn database_configuration_ready() -> bool {
    build_database_url().is_ok()
}

fn env_value(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn env_flag(name: &str) -> bool {
    matches!(
        env_value(name).as_deref(),
        Some("1") | Some("true") | Some("TRUE") | Some("yes") | Some("on")
    )
}

fn strong_secret(name: &str) -> bool {
    env_value(name).is_some_and(|value| {
        value.len() >= 32
            && !value.to_ascii_lowercase().contains("demo")
            && !value.to_ascii_lowercase().contains("dummy")
            && !value.to_ascii_lowercase().contains("test")
    })
}

fn fake_mode_disabled() -> bool {
    !std::env::var("ALLOW_DEMO_MODE").is_ok()
        && !std::env::var("ALLOW_MOCK_AI").is_ok()
        && !std::env::var("ALLOW_MOCK_RAG").is_ok()
        && !std::env::var("ALLOW_MOCK_AUTH").is_ok()
        && !std::env::var("ALLOW_MOCK_PAYMENTS").is_ok()
        && !std::env::var("ALLOW_FAKE_CI_PASS").is_ok()
}

fn storage_status() -> &'static str {
    if env_flag("UPLOADS_ENABLED") {
        if env_value("OBJECT_STORAGE_URL").is_some() || env_value("S3_BUCKET").is_some() {
            "ok"
        } else {
            "missing"
        }
    } else {
        "configured_or_disabled_closed"
    }
}

fn payments_status() -> &'static str {
    if env_flag("PAYMENTS_ENABLED") {
        if env_value("PAYMENT_PROVIDER").is_some()
            && (env_value("PAYMENT_SECRET_REF").is_some()
                || env_value("STRIPE_SECRET_KEY").is_some())
        {
            "ok"
        } else {
            "missing"
        }
    } else {
        "configured_or_disabled_closed"
    }
}

async fn rls_enabled(pool: &sqlx::PgPool) -> bool {
    sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM pg_tables
        WHERE schemaname IN ('public','sakina_ai','audit','outbox')
          AND rowsecurity = false
        "#,
    )
    .fetch_one(pool)
    .await
    .map(|count| count == 0)
    .unwrap_or(false)
}

async fn qdrant_reachable() -> bool {
    let Some(base) = env_value("QDRANT_URL") else {
        return false;
    };
    let base = base.trim_end_matches('/');
    let url = format!("{base}/collections");
    reqwest::Client::new()
        .get(url)
        .timeout(std::time::Duration::from_secs(3))
        .send()
        .await
        .map(|response| response.status().is_success())
        .unwrap_or(false)
}

fn redis_endpoint_from_url(raw: &str) -> Option<(String, u16)> {
    let without_scheme = raw
        .trim()
        .strip_prefix("redis://")
        .or_else(|| raw.trim().strip_prefix("valkey://"))
        .unwrap_or(raw.trim());
    let without_auth = without_scheme
        .rsplit_once('@')
        .map(|(_, host)| host)
        .unwrap_or(without_scheme);
    let host_port = without_auth.split('/').next().unwrap_or_default();
    let (host, port) = host_port.rsplit_once(':')?;
    let port = port.parse::<u16>().ok()?;
    if host.trim().is_empty() {
        return None;
    }
    Some((host.to_string(), port))
}

async fn redis_reachable() -> bool {
    let Some(raw) = env_value("SAKINA_REDIS_URL")
        .or_else(|| env_value("VALKEY_URL"))
        .or_else(|| env_value("REDIS_URL"))
    else {
        return false;
    };
    let Some((host, port)) = redis_endpoint_from_url(&raw) else {
        return false;
    };
    let Ok(connect_result) = tokio::time::timeout(
        std::time::Duration::from_secs(3),
        tokio::net::TcpStream::connect((host.as_str(), port)),
    )
    .await
    else {
        return false;
    };
    let Ok(mut stream) = connect_result else {
        return false;
    };
    if stream.write_all(b"*1\r\n$4\r\nPING\r\n").await.is_err() {
        return false;
    }
    let mut buf = [0_u8; 16];
    match tokio::time::timeout(std::time::Duration::from_secs(3), stream.read(&mut buf)).await {
        Ok(Ok(read)) => std::str::from_utf8(&buf[..read])
            .map(|value| value.starts_with("+PONG"))
            .unwrap_or(false),
        _ => false,
    }
}

fn llm_disabled_closed() -> bool {
    matches!(
        env_value("SAKINA_LLM_ENABLED")
            .or_else(|| env_value("SAKINA_AI_ENABLED"))
            .as_deref(),
        Some("false") | Some("0") | Some("off")
    )
}

async fn llm_provider_status() -> &'static str {
    if llm_disabled_closed() {
        return "configured_or_disabled_closed";
    }
    if let Some(base) = env_value("SAKINA_LLM_GATEWAY_URL") {
        let base = base.trim_end_matches('/');
        let url = format!("{base}/ready");
        return reqwest::Client::new()
            .get(url)
            .timeout(std::time::Duration::from_secs(3))
            .send()
            .await
            .map(|response| {
                if response.status().is_success() {
                    "ok"
                } else {
                    "missing"
                }
            })
            .unwrap_or("missing");
    }
    let Some(base) = env_value("LLM_PROVIDER_URL") else {
        return "missing";
    };
    if base.contains("mock://") && !std::env::var("ALLOW_MOCK_PROD_OVERRIDE").is_ok() {
        return "missing";
    }
    let base = base.trim_end_matches('/');
    let url = format!("{base}/v1/models");
    reqwest::Client::new()
        .get(url)
        .timeout(std::time::Duration::from_secs(3))
        .send()
        .await
        .map(|response| {
            if response.status().is_success() {
                "ok"
            } else {
                "missing"
            }
        })
        .unwrap_or("missing")
}

async fn readiness_snapshot(pool: &sqlx::PgPool) -> serde_json::Value {
    let database_ok = pool.acquire().await.is_ok();
    let rls_ok = database_ok && rls_enabled(pool).await;
    let qdrant_ok = qdrant_reachable().await;
    let redis_ok = redis_reachable().await;
    let llm = llm_provider_status().await;
    let auth_ok = strong_secret("JWT_SECRET") || strong_secret("SAKINA_JWT_SECRET");
    let encryption_ok = strong_secret("ENCRYPTION_KEY") || strong_secret("SAKINA_ENCRYPTION_KEY");
    let storage = storage_status();
    let payments = payments_status();
    let fake_disabled = fake_mode_disabled();

    json!({
        "database": if database_ok { "ok" } else { "missing" },
        "rls": if rls_ok { "ok" } else { "missing" },
        "qdrant": if qdrant_ok { "ok" } else { "missing" },
        "redis_valkey": if redis_ok { "ok" } else { "missing" },
        "llm_provider": llm,
        "auth": if auth_ok { "ok" } else { "missing" },
        "encryption": if encryption_ok { "ok" } else { "missing" },
        "storage": storage,
        "payments": payments,
        "fake_mode": if fake_disabled { "disabled" } else { "enabled" },
        "environment": env_value("SAKINA_ENV").unwrap_or_else(|| "local".to_string()),
    })
}

fn readiness_is_ok(snapshot: &serde_json::Value) -> bool {
    snapshot["database"] == "ok"
        && snapshot["rls"] == "ok"
        && snapshot["qdrant"] == "ok"
        && snapshot["redis_valkey"] == "ok"
        && matches!(
            snapshot["llm_provider"].as_str(),
            Some("ok") | Some("configured_or_disabled_closed")
        )
        && snapshot["auth"] == "ok"
        && snapshot["encryption"] == "ok"
        && matches!(
            snapshot["storage"].as_str(),
            Some("ok") | Some("configured_or_disabled_closed")
        )
        && matches!(
            snapshot["payments"].as_str(),
            Some("ok") | Some("configured_or_disabled_closed")
        )
        && snapshot["fake_mode"] == "disabled"
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
    let db_config_ready = database_configuration_ready();
    let is_ready = db_reachable && waitlist_table_exists && db_config_ready;
    let status = if is_ready { "ready" } else { "not_ready" };

    let response = json!({
        "status": status,
        "service": "Project Sakina API",
        "checks": {
            "database_reachable": db_reachable,
            "waitlist_table_exists": waitlist_table_exists,
            "required_env_present": db_config_ready,
        },
        "missing_env_vars": if db_config_ready {
            Vec::<&str>::new()
        } else {
            vec!["DATABASE_URL or POSTGRES_*"]
        }
    });

    if is_ready {
        HttpResponse::Ok().json(response)
    } else {
        HttpResponse::ServiceUnavailable().json(response)
    }
}

async fn production_readiness_check(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let snapshot = readiness_snapshot(pool.get_ref()).await;
    let response = json!({
        "status": if readiness_is_ok(&snapshot) { "ready" } else { "not_ready" },
        "checks": snapshot,
    });

    if readiness_is_ok(&response["checks"]) {
        HttpResponse::Ok().json(response)
    } else {
        HttpResponse::ServiceUnavailable().json(response)
    }
}

async fn observability_check(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let audit_logs = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM public.audit_logs")
        .fetch_one(pool.get_ref())
        .await
        .unwrap_or(0);
    let brain_traces =
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM sakina_ai.brain_decision_traces")
            .fetch_one(pool.get_ref())
            .await
            .unwrap_or(0);
    let rag_traces =
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM sakina_ai.rag_retrieval_audit")
            .fetch_one(pool.get_ref())
            .await
            .unwrap_or(0);
    let safety_traces =
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM sakina_ai.safety_classifications")
            .fetch_one(pool.get_ref())
            .await
            .unwrap_or(0);

    HttpResponse::Ok().json(json!({
        "status": "ok",
        "structured_logs": "enabled",
        "request_id": "enabled",
        "audit_logs": audit_logs,
        "brain_traces": brain_traces,
        "rag_traces": rag_traces,
        "safety_traces": safety_traces,
        "sensitive_log_policy": "do_not_log_secret_values"
    }))
}

async fn validate_production_startup(pool: &sqlx::PgPool) -> std::io::Result<()> {
    if env_value("SAKINA_ENV").as_deref() != Some("production") {
        return Ok(());
    }

    let snapshot = readiness_snapshot(pool).await;
    if readiness_is_ok(&snapshot) {
        Ok(())
    } else {
        Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("production readiness validation failed: {snapshot}"),
        ))
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
    info!(
        "[{name}] {tagline}",
        name = brand::SAKINA.name,
        tagline = brand::SAKINA.tagline
    );
    info!(
        "[{name}] Vision: {vision}",
        name = brand::SAKINA.name,
        vision = brand::SAKINA.vision
    );
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
        info!("[{name}] Value: {value}", name = brand::SAKINA.name);
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

    info!(
        "[{name}] Starting Sakina API Server",
        name = brand::SAKINA.name
    );

    // Database connection
    let database_url = build_database_url().expect("valid database configuration is required");
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
    validate_production_startup(&pool).await?;

    // Phase 1 services — wired into handlers via app_data.
    let router = std::sync::Arc::new(services::SemanticRouter::new());
    let aia_orchestrator = services::AiaOrchestrator::new_with_pool(router.clone(), pool.clone());
    let guardrails = std::sync::Arc::new(services::Guardrails::new(0.85));
    let phase2_repo = services::Phase2Repository::new(pool.clone());
    let iman_journey_service = services::ImanJourneyService::new(pool.clone());
    let islamic_repo = services::IslamicKnowledgeRepository::new(pool.clone());
    let knowledge_graph_service = services::KnowledgeGraphService::new(pool.clone());
    let semantic_cache_service = services::SemanticCacheService::new(pool.clone());
    let context_compressor = services::ContextCompressionService::new();
    let router_data = web::Data::new(router.clone());
    let aia_orchestrator_data = web::Data::new(aia_orchestrator.clone());
    let guardrails_data = web::Data::new(guardrails.clone());
    let phase2_repo_data = web::Data::new(phase2_repo.clone());
    let iman_journey_service_data = web::Data::new(iman_journey_service.clone());
    let islamic_repo_data = web::Data::new(islamic_repo.clone());
    let knowledge_graph_service_data = web::Data::new(knowledge_graph_service.clone());
    let semantic_cache_service_data = web::Data::new(semantic_cache_service.clone());

    // Background worker: drain the outbox (marks chunk_indexed events Sent).
    let relay = services::OutboxRelay::new(pool.clone());
    tokio::spawn(async move {
        if let Err(e) = relay.relay_events().await {
            tracing::error!("outbox relay stopped: {e}");
        }
    });

    // RAG dependencies: Qdrant via REST + vLLM embeddings via HTTP (lazy — no
    // connection until a request actually uses them).
    let qdrant_url =
        std::env::var("QDRANT_URL").unwrap_or_else(|_| "http://localhost:6333".to_string());
    let qdrant_collection = std::env::var("QDRANT_COLLECTION")
        .unwrap_or_else(|_| "sakina_islamic_chunks_en".to_string());
    let vllm_url =
        std::env::var("VLLM_URL").unwrap_or_else(|_| "http://localhost:8000".to_string());
    tracing::info!("VLLM_URL configured as: {}", vllm_url);
    let qdrant = web::Data::new(services::QdrantVectorDB::new(
        &qdrant_url,
        &qdrant_collection,
    ));
    let embeddings = web::Data::new(services::EmbeddingsService::new(&vllm_url));
    let islamic_qdrant_collection = std::env::var("ISLAMIC_QDRANT_COLLECTION")
        .unwrap_or_else(|_| "sakina_islamic_chunks_en".to_string());
    let hybrid_rag_service = web::Data::new(services::HybridRagService::new(
        pool.clone(),
        services::EmbeddingsService::new(&vllm_url),
        services::QdrantVectorDB::new(&qdrant_url, &islamic_qdrant_collection),
        knowledge_graph_service.clone(),
        context_compressor.clone(),
    ));
    let islamic_answer_service = web::Data::new(services::IslamicAnswerService::new(
        islamic_repo.clone(),
        hybrid_rag_service.get_ref().clone(),
        semantic_cache_service.clone(),
    ));
    let memory_engine = web::Data::new(services::MemoryEngine::new(pool.clone()));
    let multimodal_service = web::Data::new(services::MultimodalService::new(pool.clone()));
    let mcp_registry = web::Data::new(services::McpConnectorRegistry::from_env());
    let sakina_llm_gateway = web::Data::new(services::SakinaLlmGateway::from_env());
    let distributed_client = web::Data::new(services::distributed::DistributedClient::new());
    let tafsir_service = web::Data::new(services::tafsir_ingestion::TafsirIngestionService::new(
        pool.clone(),
    ));
    let fatwa_service = web::Data::new(services::fatwa_verifier::FatwaVerifierService::new(
        pool.clone(),
    ));
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
            .app_data(aia_orchestrator_data.clone())
            .app_data(guardrails_data.clone())
            .app_data(phase2_repo_data.clone())
            .app_data(iman_journey_service_data.clone())
            .app_data(islamic_repo_data.clone())
            .app_data(knowledge_graph_service_data.clone())
            .app_data(semantic_cache_service_data.clone())
            .app_data(qdrant.clone())
            .app_data(embeddings.clone())
            .app_data(islamic_answer_service.clone())
            .app_data(hybrid_rag_service.clone())
            .app_data(memory_engine.clone())
            .app_data(multimodal_service.clone())
            .app_data(mcp_registry.clone())
            .app_data(sakina_llm_gateway.clone())
            .app_data(distributed_client.clone())
            .app_data(tafsir_service.clone())
            .app_data(fatwa_service.clone())
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
            .route("/health/ready", web::get().to(production_readiness_check))
            .route("/health/observability", web::get().to(observability_check))
            .route("/ready", web::get().to(readiness_check))
            .route("/readiness", web::get().to(readiness_check))
            .route("/metrics", web::get().to(handlers::ops::metrics))
            .service(
                web::scope("/auth")
                    .route("/register", web::post().to(handlers::phase2::register_user))
                    .route("/login", web::post().to(handlers::phase2::login))
                    .route("/refresh", web::post().to(handlers::phase2::refresh))
                    .route("/me", web::get().to(handlers::phase2::current_user))
                    .route("/logout", web::post().to(handlers::phase2::logout)),
            )
            .service(
                web::scope("/api/auth")
                    .route("/register", web::post().to(handlers::phase2::register_user))
                    .route("/login", web::post().to(handlers::phase2::login))
                    .route("/refresh", web::post().to(handlers::phase2::refresh))
                    .route("/me", web::get().to(handlers::phase2::current_user))
                    .route("/logout", web::post().to(handlers::phase2::logout)),
            )
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
                web::scope("/debug")
                    .route("/agents", web::get().to(handlers::brain::debug_agents))
                    .route("/route", web::post().to(handlers::brain::test_route)),
            )
            .route(
                "/api/debug/agents",
                web::get().to(handlers::brain::debug_agents),
            )
            .route(
                "/api/brain/agents",
                web::get().to(handlers::brain::debug_agents),
            )
            .route("/api/brain/health", web::get().to(handlers::brain::health))
            .route(
                "/api/brain/trace",
                web::post().to(handlers::brain::test_route),
            )
            .route(
                "/api/brain/audit/recent",
                web::get().to(handlers::brain::audit_recent),
            )
            .route(
                "/api/brain/traces/{trace_id}",
                web::get().to(handlers::brain_traces::get_trace),
            )
            .route("/api/chat", web::post().to(handlers::chat::core_chat))
            .route("/api/sakina/ask", web::post().to(handlers::sakina_ask::ask))
            .service(
                web::scope("/api/rules")
                    .route("/evaluate", web::post().to(handlers::rules::evaluate)),
            )
            .route(
                "/api/agent/feedback",
                web::post().to(handlers::agent_feedback::submit_feedback),
            )
            .route(
                "/api/agent/rollout/route",
                web::post().to(handlers::agent::rollout_route_probe),
            )
            .route(
                "/api/agent/rollout/validate",
                web::post().to(handlers::agent::rollout_validate_probe),
            )
            .route(
                "/api/test/route",
                web::post().to(handlers::brain::test_route),
            )
            .route(
                "/api/rag/search",
                web::post().to(handlers::rag::api_rag_search),
            )
            .route("/api/rag/query", web::post().to(handlers::rag::query_rag))
            .route(
                "/api/brain/route",
                web::post().to(handlers::brain::test_route),
            )
            .route(
                "/api/evaluation/check",
                web::post().to(handlers::evaluation::check),
            )
            .route(
                "/api/quran/tafsir/{source_id}/job",
                web::post().to(handlers::tafsir::start_tafsir_job),
            )
            .route(
                "/api/quran/tafsir/{source_id}/ingest",
                web::post().to(handlers::tafsir::ingest_tafsir_entry),
            )
            .route(
                "/api/fatwa/verify",
                web::post().to(handlers::fatwa::verify_fatwa),
            )
            .route("/api/cache/stats", web::get().to(handlers::cache::stats))
            .route("/api/cache/status", web::get().to(handlers::cache::stats))
            .route(
                "/api/connectors/status",
                web::get().to(handlers::connectors::status),
            )
            .route(
                "/api/model-providers/status",
                web::get().to(handlers::model_providers::status),
            )
            .route(
                "/api/kg/health",
                web::get().to(handlers::knowledge_graph::health),
            )
            .route(
                "/api/kg/entity",
                web::post().to(handlers::knowledge_graph::entity),
            )
            .route(
                "/api/knowledge-graph/health",
                web::get().to(handlers::knowledge_graph::health),
            )
            .route(
                "/api/knowledge-graph/search",
                web::post().to(handlers::knowledge_graph::entity),
            )
            .route(
                "/api/graph-rag/query",
                web::post().to(handlers::knowledge_graph::entity),
            )
            .route(
                "/api/user-learning/profile",
                web::get().to(handlers::user_learning::profile),
            )
            .route(
                "/api/user-learning/event",
                web::post().to(handlers::user_learning::event),
            )
            .route(
                "/api/user-learning/consent",
                web::post().to(handlers::user_learning::consent),
            )
            .route(
                "/api/user-learning/export",
                web::get().to(handlers::user_learning::export),
            )
            .route(
                "/api/user-learning/profile",
                web::delete().to(handlers::user_learning::delete_profile),
            )
            .route("/api/memory/write", web::post().to(handlers::memory::write))
            .route("/api/memory", web::get().to(handlers::memory::list))
            .route("/api/memory/read", web::get().to(handlers::memory::read))
            .route(
                "/api/memory/delete",
                web::delete().to(handlers::memory::delete),
            )
            .route(
                "/api/workspaces/{workspace_id}/memory",
                web::get().to(handlers::memory::list_workspace),
            )
            .route(
                "/api/multimodal/analyze",
                web::post().to(handlers::multimodal::analyze),
            )
            .route(
                "/api/multimodal/assets/{asset_id}",
                web::get().to(handlers::multimodal::get_asset),
            )
            .route(
                "/api/multimodal/assets/{asset_id}",
                web::delete().to(handlers::multimodal::delete_asset),
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
                    )
                    .route(
                        "/scholar-reviews/resolve",
                        web::post().to(handlers::phase2::resolve_scholar_review),
                    ),
            )
            .service(
                web::scope("/v1")
                    .route("/health", web::get().to(handlers::health::health_check))
                    .route("/ready", web::get().to(readiness_check))
                    .route("/readiness", web::get().to(readiness_check))
                    .route("/metrics", web::get().to(handlers::ops::metrics))
                    .route(
                        "/waitlist",
                        web::post().to(handlers::waitlist::create_waitlist_entry),
                    )
                    .route(
                        "/users/pubkey",
                        web::get().to(handlers::user::get_server_pubkey),
                    )
                    .service(
                        web::scope("/auth")
                            .route("/register", web::post().to(handlers::phase2::register_user))
                            .route("/login", web::post().to(handlers::phase2::login))
                            .route("/refresh", web::post().to(handlers::phase2::refresh))
                            .route("/me", web::get().to(handlers::phase2::current_user))
                            .route("/logout", web::post().to(handlers::phase2::logout))
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
                        web::scope("/account")
                            .route(
                                "/delete-request",
                                web::post().to(handlers::phase2::request_account_deletion),
                            )
                            .route(
                                "/export-request",
                                web::post().to(handlers::phase2::request_data_export),
                            ),
                    )
                    .configure(handlers::iman_journey::configure)
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
                        web::scope("/debug")
                            .route("/agents", web::get().to(handlers::brain::debug_agents))
                            .route("/route", web::post().to(handlers::brain::test_route)),
                    )
                    .route(
                        "/api/debug/agents",
                        web::get().to(handlers::brain::debug_agents),
                    )
                    .route(
                        "/api/brain/agents",
                        web::get().to(handlers::brain::debug_agents),
                    )
                    .route("/api/brain/health", web::get().to(handlers::brain::health))
                    .route(
                        "/api/brain/trace",
                        web::post().to(handlers::brain::test_route),
                    )
                    .route(
                        "/api/brain/audit/recent",
                        web::get().to(handlers::brain::audit_recent),
                    )
                    .route(
                        "/api/brain/traces/{trace_id}",
                        web::get().to(handlers::brain_traces::get_trace),
                    )
                    .service(
                        web::scope("/api/rules")
                            .route("/evaluate", web::post().to(handlers::rules::evaluate)),
                    )
                    .route("/api/chat", web::post().to(handlers::chat::core_chat))
                    .route("/api/sakina/ask", web::post().to(handlers::sakina_ask::ask))
                    .route(
                        "/api/test/route",
                        web::post().to(handlers::brain::test_route),
                    )
                    .route(
                        "/api/rag/search",
                        web::post().to(handlers::rag::api_rag_search),
                    )
                    .route(
                        "/api/evaluation/check",
                        web::post().to(handlers::evaluation::check),
                    )
                    .route("/api/cache/stats", web::get().to(handlers::cache::stats))
                    .route("/api/cache/status", web::get().to(handlers::cache::stats))
                    .route(
                        "/api/connectors/status",
                        web::get().to(handlers::connectors::status),
                    )
                    .route(
                        "/api/model-providers/status",
                        web::get().to(handlers::model_providers::status),
                    )
                    .route(
                        "/api/kg/health",
                        web::get().to(handlers::knowledge_graph::health),
                    )
                    .route(
                        "/api/knowledge-graph/health",
                        web::get().to(handlers::knowledge_graph::health),
                    )
                    .route(
                        "/api/knowledge-graph/search",
                        web::post().to(handlers::knowledge_graph::entity),
                    )
                    .route(
                        "/api/graph-rag/query",
                        web::post().to(handlers::knowledge_graph::entity),
                    )
                    .route(
                        "/api/user-learning/profile",
                        web::get().to(handlers::user_learning::profile),
                    )
                    .route(
                        "/api/user-learning/event",
                        web::post().to(handlers::user_learning::event),
                    )
                    .route(
                        "/api/user-learning/consent",
                        web::post().to(handlers::user_learning::consent),
                    )
                    .route(
                        "/api/user-learning/export",
                        web::get().to(handlers::user_learning::export),
                    )
                    .route(
                        "/api/user-learning/profile",
                        web::delete().to(handlers::user_learning::delete_profile),
                    )
                    .route("/api/memory", web::get().to(handlers::memory::list))
                    .route("/api/memory/write", web::post().to(handlers::memory::write))
                    .route("/api/memory/read", web::get().to(handlers::memory::read))
                    .route(
                        "/api/memory/delete",
                        web::delete().to(handlers::memory::delete),
                    )
                    .route(
                        "/api/workspaces/{workspace_id}/memory",
                        web::get().to(handlers::memory::list_workspace),
                    )
                    .route(
                        "/api/multimodal/analyze",
                        web::post().to(handlers::multimodal::analyze),
                    )
                    .route(
                        "/api/multimodal/assets/{asset_id}",
                        web::get().to(handlers::multimodal::get_asset),
                    )
                    .route(
                        "/api/multimodal/assets/{asset_id}",
                        web::delete().to(handlers::multimodal::delete_asset),
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
                        web::scope("/islamic")
                            .route("/sources", web::get().to(handlers::islamic::list_sources))
                            .route(
                                "/documents",
                                web::get().to(handlers::islamic::list_documents),
                            )
                            .route(
                                "/documents/{id}/chunks",
                                web::get().to(handlers::islamic::list_document_chunks),
                            )
                            .route("/search", web::get().to(handlers::islamic::search_local))
                            .route(
                                "/citations/{id}",
                                web::get().to(handlers::islamic::get_citation),
                            )
                            .route("/ask", web::post().to(handlers::islamic::ask))
                            .route(
                                "/qdrant/plan",
                                web::post().to(handlers::islamic::qdrant_plan),
                            )
                            .route(
                                "/ingestion/scaffolds",
                                web::get().to(handlers::islamic::ingestion_scaffolds),
                            ),
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
                                "/scholar-assignments",
                                web::post().to(handlers::phase2::assign_scholar_review),
                            )
                            .route(
                                "/scholar-reviews/resolve",
                                web::post().to(handlers::phase2::resolve_scholar_review),
                            )
                            .route(
                                "/wasm-events",
                                web::post().to(handlers::phase2::log_wasm_event),
                            ),
                    )
                    .service(
                        web::scope("/notifications")
                            .route("", web::get().to(handlers::phase2::list_notifications))
                            .route(
                                "/templates",
                                web::post().to(handlers::phase2::create_notification_template),
                            )
                            .route(
                                "/send",
                                web::post().to(handlers::phase2::enqueue_notification),
                            )
                            .route(
                                "/{notification_id}/read",
                                web::post().to(handlers::phase2::mark_notification_read),
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
            .default_service(web::route().to(default_not_found))
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
                    .route("/readiness", web::get().to(readiness_check))
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
                            .route("/readiness", web::get().to(readiness_check))
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
        let readiness_root = test::call_service(
            &app,
            test::TestRequest::get().uri("/readiness").to_request(),
        )
        .await;
        let ready_v1 =
            test::call_service(&app, test::TestRequest::get().uri("/v1/ready").to_request()).await;
        let readiness_v1 = test::call_service(
            &app,
            test::TestRequest::get().uri("/v1/readiness").to_request(),
        )
        .await;
        assert_eq!(ready_root.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(readiness_root.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(ready_v1.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(readiness_v1.status(), StatusCode::SERVICE_UNAVAILABLE);

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
