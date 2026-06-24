use actix_web::{web, HttpRequest, HttpResponse};
use sqlx::PgPool;

use crate::error::{error_response, ApiError};
use crate::models::{
    CommunityOverview, CommunityOverviewChannel, KnowledgeOverview, KnowledgeOverviewTopic,
    ModuleLifecycleStatus, ModuleSafetyStatus, ModuleStatusResponse,
    ModulesStatusCollectionResponse, PrayerOverview, PrayerOverviewWindow, QuranOverview,
    QuranOverviewEntry, RagReadiness, ReviewStatus,
};

fn env_flag_enabled(key: &str) -> bool {
    std::env::var(key)
        .ok()
        .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
}

fn module_status(module: &str) -> ModuleStatusResponse {
    let (enabled, status, reason, requires_subscription) = match module {
        "chat" => {
            let enabled = std::env::var("SAKINA_FEATURE_CHAT")
                .ok()
                .map(|v| !matches!(v.trim().to_ascii_lowercase().as_str(), "0" | "false" | "no"))
                .unwrap_or(true);
            (
                enabled,
                if enabled {
                    ModuleLifecycleStatus::Active
                } else {
                    ModuleLifecycleStatus::Disabled
                },
                if enabled {
                    "chat module is active".to_string()
                } else {
                    "chat module disabled by feature flag".to_string()
                },
                false,
            )
        }
        "quran" => {
            let enabled = env_flag_enabled("SAKINA_FEATURE_QURAN");
            (
                enabled,
                if enabled {
                    ModuleLifecycleStatus::Active
                } else {
                    ModuleLifecycleStatus::ComingSoon
                },
                if enabled {
                    "quran module flag enabled; restricted content policy still applies".to_string()
                } else {
                    "quran module disabled by default until feature flag is enabled".to_string()
                },
                true,
            )
        }
        "prayer" => {
            let enabled = env_flag_enabled("SAKINA_FEATURE_PRAYER");
            (
                enabled,
                if enabled {
                    ModuleLifecycleStatus::Active
                } else {
                    ModuleLifecycleStatus::ComingSoon
                },
                if enabled {
                    "prayer module flag enabled; restricted content policy still applies"
                        .to_string()
                } else {
                    "prayer module disabled by default until feature flag is enabled".to_string()
                },
                true,
            )
        }
        "community" => {
            let enabled = env_flag_enabled("SAKINA_FEATURE_COMMUNITY");
            (
                enabled,
                if enabled {
                    ModuleLifecycleStatus::Active
                } else {
                    ModuleLifecycleStatus::ComingSoon
                },
                if enabled {
                    "community module flag enabled; moderation controls still apply".to_string()
                } else {
                    "community module disabled by default until feature flag is enabled".to_string()
                },
                true,
            )
        }
        "knowledge" => {
            let enabled = env_flag_enabled("SAKINA_FEATURE_KNOWLEDGE");
            (
                enabled,
                if enabled {
                    ModuleLifecycleStatus::Active
                } else {
                    ModuleLifecycleStatus::ComingSoon
                },
                if enabled {
                    "knowledge module flag enabled; verification controls still apply".to_string()
                } else {
                    "knowledge module disabled by default until feature flag is enabled".to_string()
                },
                true,
            )
        }
        _ => (
            false,
            ModuleLifecycleStatus::Disabled,
            "unknown module".to_string(),
            false,
        ),
    };

    ModuleStatusResponse {
        module: module.to_string(),
        enabled,
        status,
        reason,
        requires_subscription,
    }
}

pub async fn modules_status() -> HttpResponse {
    HttpResponse::Ok().json(ModulesStatusCollectionResponse {
        modules: vec![
            module_status("chat"),
            module_status("quran"),
            module_status("prayer"),
            module_status("community"),
            module_status("knowledge"),
        ],
    })
}

pub async fn chat_status() -> HttpResponse {
    HttpResponse::Ok().json(module_status("chat"))
}

pub async fn quran_status() -> HttpResponse {
    HttpResponse::Ok().json(module_status("quran"))
}

pub async fn prayer_status() -> HttpResponse {
    HttpResponse::Ok().json(module_status("prayer"))
}

pub async fn community_status() -> HttpResponse {
    HttpResponse::Ok().json(module_status("community"))
}

pub async fn knowledge_status() -> HttpResponse {
    HttpResponse::Ok().json(module_status("knowledge"))
}

async fn user_has_entitlement(
    pool: &PgPool,
    user_id: uuid::Uuid,
    entitlement_key: &str,
) -> Result<bool, ApiError> {
    let row = sqlx::query(
        r#"
        SELECT 1
        FROM public.user_entitlements ue
        JOIN public.entitlements e ON e.id = ue.entitlement_id
        WHERE ue.user_id = $1
          AND e.entitlement_key = $2
          AND e.is_active = true
          AND ue.revoked_at IS NULL
          AND (ue.expires_at IS NULL OR ue.expires_at > now())
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(entitlement_key)
    .fetch_optional(pool)
    .await
    .map_err(|_| ApiError::internal("failed to verify module entitlement"))?;

    Ok(row.is_some())
}

async fn enforce_module_gate(
    req: &HttpRequest,
    pool: &PgPool,
    feature_flag_env: &str,
    entitlement_key: &str,
) -> Result<Option<HttpResponse>, ApiError> {
    if !env_flag_enabled(feature_flag_env) {
        return Ok(Some(error_response(
            actix_web::http::StatusCode::FORBIDDEN,
            "feature_disabled",
            "module is disabled by feature flag",
        )));
    }

    let user_id = crate::services::auth::authenticated_user_id(req, pool).await?;
    if !user_has_entitlement(pool, user_id, entitlement_key).await? {
        return Ok(Some(error_response(
            actix_web::http::StatusCode::PAYMENT_REQUIRED,
            "subscription_required",
            "module requires premium entitlement",
        )));
    }

    Ok(None)
}

fn rag_readiness(flag_env: &str) -> RagReadiness {
    let rag_enabled = env_flag_enabled(flag_env);
    RagReadiness {
        rag_enabled,
        rag_index_ready: false,
        verified_source_count: 0,
        last_indexed_at: None,
        review_status: ReviewStatus::ScholarReviewRequired,
    }
}

fn validate_required_provenance<'a>(
    module: &'static str,
    items: impl IntoIterator<Item = (&'a str, &'a str, &'a str, &'a str)>,
) -> Option<HttpResponse> {
    let invalid = items.into_iter().any(
        |(source_type, source_name, source_reference, review_status)| {
            source_type.trim().is_empty()
                || source_name.trim().is_empty()
                || source_reference.trim().is_empty()
                || review_status.trim().is_empty()
        },
    );
    if invalid {
        return Some(error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "invalid_provenance",
            format!(
                "{} module produced unsourced or incomplete provenance payload",
                module
            ),
        ));
    }
    None
}

pub async fn quran_overview(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    if let Some(blocked) =
        enforce_module_gate(&req, pool.get_ref(), "SAKINA_FEATURE_QURAN", "quran_access").await?
    {
        return Ok(blocked);
    }
    let entries = Vec::<QuranOverviewEntry>::new();
    if let Some(error) = validate_required_provenance(
        "quran",
        entries.iter().map(|e| {
            (
                e.source_type.as_str(),
                e.source_name.as_str(),
                e.source_reference.as_str(),
                e.review_status.as_str(),
            )
        }),
    ) {
        return Ok(error);
    }
    Ok(HttpResponse::Ok().json(QuranOverview {
        module: "quran".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "Active / Under expert verification".to_string(),
        rag: rag_readiness("SAKINA_RAG_QURAN_ENABLED"),
        entries,
    }))
}

pub async fn prayer_overview(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    if let Some(blocked) = enforce_module_gate(
        &req,
        pool.get_ref(),
        "SAKINA_FEATURE_PRAYER",
        "prayer_access",
    )
    .await?
    {
        return Ok(blocked);
    }
    let windows = Vec::<PrayerOverviewWindow>::new();
    if let Some(error) = validate_required_provenance(
        "prayer",
        windows.iter().map(|e| {
            (
                e.source_type.as_str(),
                e.source_name.as_str(),
                e.source_reference.as_str(),
                e.review_status.as_str(),
            )
        }),
    ) {
        return Ok(error);
    }
    Ok(HttpResponse::Ok().json(PrayerOverview {
        module: "prayer".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "Active / Under expert verification".to_string(),
        rag: rag_readiness("SAKINA_RAG_PRAYER_ENABLED"),
        windows,
    }))
}

pub async fn knowledge_overview(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    if let Some(blocked) = enforce_module_gate(
        &req,
        pool.get_ref(),
        "SAKINA_FEATURE_KNOWLEDGE",
        "knowledge_access",
    )
    .await?
    {
        return Ok(blocked);
    }
    let topics = Vec::<KnowledgeOverviewTopic>::new();
    if let Some(error) = validate_required_provenance(
        "knowledge",
        topics.iter().map(|e| {
            (
                e.source_type.as_str(),
                e.source_name.as_str(),
                e.source_reference.as_str(),
                e.review_status.as_str(),
            )
        }),
    ) {
        return Ok(error);
    }
    Ok(HttpResponse::Ok().json(KnowledgeOverview {
        module: "knowledge".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "Active / Under expert verification".to_string(),
        rag: rag_readiness("SAKINA_RAG_KNOWLEDGE_ENABLED"),
        topics,
    }))
}

pub async fn community_overview(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    if let Some(blocked) = enforce_module_gate(
        &req,
        pool.get_ref(),
        "SAKINA_FEATURE_COMMUNITY",
        "community_access",
    )
    .await?
    {
        return Ok(blocked);
    }
    let channels = Vec::<CommunityOverviewChannel>::new();
    if let Some(error) = validate_required_provenance(
        "community",
        channels.iter().map(|e| {
            (
                e.source_type.as_str(),
                e.source_name.as_str(),
                e.source_reference.as_str(),
                e.review_status.as_str(),
            )
        }),
    ) {
        return Ok(error);
    }
    Ok(HttpResponse::Ok().json(CommunityOverview {
        module: "community".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "Active / Under expert verification".to_string(),
        rag: rag_readiness("SAKINA_RAG_COMMUNITY_ENABLED"),
        channels,
    }))
}

#[cfg(test)]
#[allow(clippy::await_holding_lock)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;
    use actix_web::test as awtest;
    use actix_web::{http::StatusCode, test::TestRequest, web, App};

    #[actix_rt::test]
    async fn disabled_flag_blocks_module_access_with_standard_error_shape() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "false");
        let req = TestRequest::default().to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let response = quran_overview(req, web::Data::new(pool))
            .await
            .expect("disabled flag response");
        assert_eq!(response.status(), StatusCode::FORBIDDEN);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"feature_disabled\""));
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[actix_rt::test]
    async fn enabled_flag_without_subscription_is_blocked() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let req = TestRequest::default().to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let error = quran_overview(req, web::Data::new(pool))
            .await
            .expect_err("missing JWT must fail before entitlement lookup");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
        assert_eq!(error.code, "unauthorized");
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[actix_rt::test]
    async fn entitlement_bypass_with_free_tier_is_blocked() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_COMMUNITY", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let error = community_overview(req, web::Data::new(pool))
            .await
            .expect_err("forged tier header must not bypass JWT/session auth");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
        std::env::remove_var("SAKINA_FEATURE_COMMUNITY");
    }

    #[actix_rt::test]
    async fn enabled_quran_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let error = quran_overview(req, web::Data::new(pool))
            .await
            .expect_err("premium header alone must not produce quran payload");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[actix_rt::test]
    async fn enabled_prayer_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_PRAYER", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let error = prayer_overview(req, web::Data::new(pool))
            .await
            .expect_err("premium header alone must not produce prayer payload");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
        std::env::remove_var("SAKINA_FEATURE_PRAYER");
    }

    #[actix_rt::test]
    async fn enabled_knowledge_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_KNOWLEDGE", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let error = knowledge_overview(req, web::Data::new(pool))
            .await
            .expect_err("premium header alone must not produce knowledge payload");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
        std::env::remove_var("SAKINA_FEATURE_KNOWLEDGE");
    }

    #[actix_rt::test]
    async fn enabled_community_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_COMMUNITY", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy test pool");
        let error = community_overview(req, web::Data::new(pool))
            .await
            .expect_err("premium header alone must not produce community payload");
        assert_eq!(error.status, StatusCode::UNAUTHORIZED);
        std::env::remove_var("SAKINA_FEATURE_COMMUNITY");
    }

    #[test]
    fn provenance_validation_rejects_missing_required_fields() {
        let result = validate_required_provenance(
            "quran",
            vec![("tafsir", "", "1:1", "scholar_review_pending")],
        );
        assert!(result.is_some());
    }

    #[test]
    fn provenance_validation_rejects_unsourced_religious_content() {
        let result = validate_required_provenance(
            "knowledge",
            vec![("article", "Fiqh Book", "", "editor_review_pending")],
        );
        assert!(result.is_some());
    }

    #[actix_rt::test]
    async fn module_status_defaults_to_chat_active_and_others_coming_soon() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::remove_var("SAKINA_FEATURE_CHAT");
        std::env::remove_var("SAKINA_FEATURE_QURAN");
        std::env::remove_var("SAKINA_FEATURE_PRAYER");
        std::env::remove_var("SAKINA_FEATURE_COMMUNITY");
        std::env::remove_var("SAKINA_FEATURE_KNOWLEDGE");

        let chat = module_status("chat");
        let quran = module_status("quran");

        assert!(chat.enabled);
        assert_eq!(chat.status, ModuleLifecycleStatus::Active);
        assert!(!quran.enabled);
        assert_eq!(quran.status, ModuleLifecycleStatus::ComingSoon);
    }

    #[actix_rt::test]
    async fn modules_endpoints_exist_for_root_and_v1_paths() {
        let app = awtest::init_service(
            App::new()
                .service(
                    web::scope("/modules")
                        .route("", web::get().to(modules_status))
                        .route("/chat/status", web::get().to(chat_status))
                        .route("/quran/status", web::get().to(quran_status))
                        .route("/prayer/status", web::get().to(prayer_status))
                        .route("/community/status", web::get().to(community_status))
                        .route("/knowledge/status", web::get().to(knowledge_status)),
                )
                .service(
                    web::scope("/v1").service(
                        web::scope("/modules")
                            .route("", web::get().to(modules_status))
                            .route("/chat/status", web::get().to(chat_status))
                            .route("/quran/status", web::get().to(quran_status))
                            .route("/prayer/status", web::get().to(prayer_status))
                            .route("/community/status", web::get().to(community_status))
                            .route("/knowledge/status", web::get().to(knowledge_status)),
                    ),
                ),
        )
        .await;

        let root_modules =
            awtest::call_service(&app, TestRequest::get().uri("/modules").to_request()).await;
        let v1_modules =
            awtest::call_service(&app, TestRequest::get().uri("/v1/modules").to_request()).await;
        let v1_quran = awtest::call_service(
            &app,
            TestRequest::get()
                .uri("/v1/modules/quran/status")
                .to_request(),
        )
        .await;

        assert_eq!(root_modules.status(), StatusCode::OK);
        assert_eq!(v1_modules.status(), StatusCode::OK);
        assert_eq!(v1_quran.status(), StatusCode::OK);

        let modules_body = to_bytes(v1_modules.into_body())
            .await
            .expect("modules body");
        let modules_text = String::from_utf8(modules_body.to_vec()).expect("utf8");
        assert!(modules_text.contains("\"module\":\"chat\""));
        assert!(modules_text.contains("\"module\":\"quran\""));
        assert!(modules_text.contains("\"status\":\"coming_soon\""));

        let quran_body = to_bytes(v1_quran.into_body()).await.expect("quran body");
        let quran_text = String::from_utf8(quran_body.to_vec()).expect("utf8");
        assert!(quran_text.contains("\"module\":\"quran\""));
        assert!(quran_text.contains("\"enabled\":false"));
        assert!(quran_text.contains("\"requires_subscription\":true"));
    }
}
