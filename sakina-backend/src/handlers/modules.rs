use actix_web::{HttpRequest, HttpResponse};

use crate::error::error_response;
use crate::models::{
    CommunityOverview, CommunityOverviewChannel, KnowledgeOverview, KnowledgeOverviewTopic,
    ModuleSafetyStatus, PrayerOverview, PrayerOverviewWindow, QuranOverview, QuranOverviewEntry,
    RagReadiness, ReviewStatus,
};

fn env_flag_enabled(key: &str) -> bool {
    std::env::var(key)
        .ok()
        .map(|v| matches!(v.trim().to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
}

fn has_entitlement(req: &HttpRequest) -> bool {
    req.headers()
        .get("x-sakina-subscription-tier")
        .and_then(|v| v.to_str().ok())
        .map(|v| {
            matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "premium" | "pro" | "founding"
            )
        })
        .unwrap_or(false)
}

fn enforce_module_gate(req: &HttpRequest, feature_flag_env: &str) -> Option<HttpResponse> {
    if !env_flag_enabled(feature_flag_env) {
        return Some(error_response(
            actix_web::http::StatusCode::FORBIDDEN,
            "feature_disabled",
            "module is disabled by feature flag",
        ));
    }

    if !has_entitlement(req) {
        return Some(error_response(
            actix_web::http::StatusCode::PAYMENT_REQUIRED,
            "subscription_required",
            "module requires premium entitlement",
        ));
    }

    None
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

pub async fn quran_overview(req: HttpRequest) -> HttpResponse {
    if let Some(blocked) = enforce_module_gate(&req, "SAKINA_FEATURE_QURAN") {
        return blocked;
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
        return error;
    }
    HttpResponse::Ok().json(QuranOverview {
        module: "quran".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "coming soon / under review".to_string(),
        rag: rag_readiness("SAKINA_RAG_QURAN_ENABLED"),
        entries,
    })
}

pub async fn prayer_overview(req: HttpRequest) -> HttpResponse {
    if let Some(blocked) = enforce_module_gate(&req, "SAKINA_FEATURE_PRAYER") {
        return blocked;
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
        return error;
    }
    HttpResponse::Ok().json(PrayerOverview {
        module: "prayer".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "coming soon / under review".to_string(),
        rag: rag_readiness("SAKINA_RAG_PRAYER_ENABLED"),
        windows,
    })
}

pub async fn knowledge_overview(req: HttpRequest) -> HttpResponse {
    if let Some(blocked) = enforce_module_gate(&req, "SAKINA_FEATURE_KNOWLEDGE") {
        return blocked;
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
        return error;
    }
    HttpResponse::Ok().json(KnowledgeOverview {
        module: "knowledge".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "coming soon / under review".to_string(),
        rag: rag_readiness("SAKINA_RAG_KNOWLEDGE_ENABLED"),
        topics,
    })
}

pub async fn community_overview(req: HttpRequest) -> HttpResponse {
    if let Some(blocked) = enforce_module_gate(&req, "SAKINA_FEATURE_COMMUNITY") {
        return blocked;
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
        return error;
    }
    HttpResponse::Ok().json(CommunityOverview {
        module: "community".to_string(),
        safety_status: ModuleSafetyStatus::RequiresReview,
        review_status: ReviewStatus::ScholarReviewRequired,
        message: "coming soon / under review".to_string(),
        rag: rag_readiness("SAKINA_RAG_COMMUNITY_ENABLED"),
        channels,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;
    use actix_web::{http::StatusCode, test::TestRequest};

    #[actix_rt::test]
    async fn disabled_flag_blocks_module_access_with_standard_error_shape() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "false");
        let req = TestRequest::default().to_http_request();
        let response = quran_overview(req).await;
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
        let response = quran_overview(req).await;
        assert_eq!(response.status(), StatusCode::PAYMENT_REQUIRED);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"subscription_required\""));
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[actix_rt::test]
    async fn entitlement_bypass_with_free_tier_is_blocked() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_COMMUNITY", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "free"))
            .to_http_request();
        let response = community_overview(req).await;
        assert_eq!(response.status(), StatusCode::PAYMENT_REQUIRED);
        std::env::remove_var("SAKINA_FEATURE_COMMUNITY");
    }

    #[actix_rt::test]
    async fn enabled_quran_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_QURAN", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let response = quran_overview(req).await;
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"safety_status\":\"requires_review\""));
        assert!(text.contains("\"entries\":[]"));
        std::env::remove_var("SAKINA_FEATURE_QURAN");
    }

    #[actix_rt::test]
    async fn enabled_prayer_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_PRAYER", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let response = prayer_overview(req).await;
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"safety_status\":\"requires_review\""));
        assert!(text.contains("\"windows\":[]"));
        std::env::remove_var("SAKINA_FEATURE_PRAYER");
    }

    #[actix_rt::test]
    async fn enabled_knowledge_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_KNOWLEDGE", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let response = knowledge_overview(req).await;
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"safety_status\":\"requires_review\""));
        assert!(text.contains("\"topics\":[]"));
        std::env::remove_var("SAKINA_FEATURE_KNOWLEDGE");
    }

    #[actix_rt::test]
    async fn enabled_community_returns_requires_review_without_fabricated_payload() {
        let _guard = crate::TEST_ENV_LOCK.lock().expect("env test lock");
        std::env::set_var("SAKINA_FEATURE_COMMUNITY", "true");
        let req = TestRequest::default()
            .insert_header(("x-sakina-subscription-tier", "premium"))
            .to_http_request();
        let response = community_overview(req).await;
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"safety_status\":\"requires_review\""));
        assert!(text.contains("\"channels\":[]"));
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
}
