use actix_web::{web, HttpRequest, HttpResponse};
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::authenticated_user_id;
use crate::services::phase2::{
    ActivateSubscriptionRequest, AppendSupportTicketMessageRequest, AssignScholarReviewRequest,
    CreateAuditLogRequest, CreateChatFeedbackRequest, CreateEventRequest,
    CreateNotificationTemplateRequest, CreateScholarAccountRequest, CreateSecurityLogRequest,
    CreateSessionRequest, CreateSourceApprovalItemRequest, CreateSupportTicketRequest,
    EnqueueNotificationRequest, EnqueueScholarReviewRequest, LogAdminActionRequest,
    LogCitationEventRequest, LogMastermindDecisionRequest, LogRagRetrievalRequest,
    LogSafetyClassificationRequest, LogWasmVerificationRequest, LoginRequest, Phase2Repository,
    RefreshTokenRequest, RegisterUserRequest, ReportAnswerRequest, SourceApprovalItem,
    UpsertAdminRoleRequest, UpsertDeviceTokenRequest, UpsertProfileRequest,
};

#[derive(Debug, serde::Deserialize)]
pub struct ModuleQuery {
    pub module: String,
}

fn normalized_module(module: &str) -> Result<String, ApiError> {
    let normalized = module.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return Err(ApiError::bad_request("module is required"));
    }
    Ok(normalized)
}

pub async fn register_user(
    repo: web::Data<Phase2Repository>,
    body: web::Json<RegisterUserRequest>,
) -> Result<HttpResponse, ApiError> {
    let request = body.into_inner();
    if request.email.trim().is_empty() {
        return Err(ApiError::bad_request("email is required"));
    }
    let response = repo.register_user(request).await?;
    Ok(HttpResponse::Created().json(response))
}

pub async fn create_session(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateSessionRequest>,
) -> Result<HttpResponse, ApiError> {
    let request = body.into_inner();
    if request.session_token_hash.trim().is_empty() || request.refresh_token_hash.trim().is_empty()
    {
        return Err(ApiError::bad_request(
            "session_token_hash and refresh_token_hash are required",
        ));
    }
    let response = repo.create_session(request).await?;
    Ok(HttpResponse::Created().json(response))
}

pub async fn login(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LoginRequest>,
) -> Result<HttpResponse, ApiError> {
    let request = body.into_inner();
    if request.email.trim().is_empty() || request.password.is_empty() {
        return Err(ApiError::bad_request("email and password are required"));
    }
    let response = repo.login_password(request).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn refresh(
    repo: web::Data<Phase2Repository>,
    body: web::Json<RefreshTokenRequest>,
) -> Result<HttpResponse, ApiError> {
    let response = repo.refresh_session(body.into_inner()).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn current_user(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, repo.pool()).await?;
    let response = repo.get_user_summary(user_id).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn logout(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
) -> Result<HttpResponse, ApiError> {
    let token = crate::services::auth::bearer_token(&req)?;
    let token_hash = crate::services::auth::session_token_hash(token);
    let mut tx = repo
        .pool()
        .begin()
        .await
        .map_err(|_| ApiError::internal("failed to begin logout transaction"))?;

    let session_id = sqlx::query_scalar::<_, Uuid>(
        r#"
        UPDATE public.auth_sessions
        SET revoked_at = now(), updated_at = now()
        WHERE session_token_hash = $1 AND revoked_at IS NULL
        RETURNING id
        "#,
    )
    .bind(token_hash)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|_| ApiError::internal("failed to revoke session"))?;

    let mut refresh_rows = 0;
    if let Some(session_id) = session_id {
        refresh_rows = sqlx::query(
            r#"
            UPDATE public.auth_refresh_tokens
            SET revoked_at = now()
            WHERE session_id = $1 AND revoked_at IS NULL
            "#,
        )
        .bind(session_id)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to revoke refresh tokens"))?
        .rows_affected();
    }

    tx.commit()
        .await
        .map_err(|_| ApiError::internal("failed to commit logout transaction"))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "revoked": session_id.is_some(),
        "revoked_refresh_tokens": refresh_rows
    })))
}

pub async fn upsert_profile(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
    body: web::Json<UpsertProfileRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    let requested_user_id = path.into_inner();
    let auth_user_id = authenticated_user_id(&req, repo.pool()).await?;
    if auth_user_id != requested_user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    request.user_id = auth_user_id;
    let response = repo.upsert_profile(request).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn create_family_profile(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
    body: web::Json<crate::services::phase2::CreateFamilyProfileRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    let requested_user_id = path.into_inner();
    let auth_user_id = authenticated_user_id(&req, repo.pool()).await?;
    if auth_user_id != requested_user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    request.user_id = auth_user_id;
    if request.family_name.trim().is_empty() {
        return Err(ApiError::bad_request("family_name is required"));
    }
    let response = repo.create_family_profile(request).await?;
    Ok(HttpResponse::Created().json(response))
}

pub async fn activate_subscription(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
    body: web::Json<ActivateSubscriptionRequest>,
) -> Result<HttpResponse, ApiError> {
    let grant_secret = std::env::var("SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET")
        .map_err(|_| ApiError::service_unavailable("manual entitlement grants are disabled"))?;
    if grant_secret.trim().len() < 24 {
        return Err(ApiError::service_unavailable(
            "manual entitlement grant secret is not strong enough",
        ));
    }
    let supplied_secret = req
        .headers()
        .get("X-Sakina-Grant-Secret")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    if supplied_secret != grant_secret {
        return Err(ApiError::unauthorized(
            "manual entitlement grant credential is invalid",
        ));
    }

    let mut request = body.into_inner();
    let requested_user_id = path.into_inner();
    let auth_user_id = authenticated_user_id(&req, repo.pool()).await?;
    if auth_user_id != requested_user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    request.user_id = auth_user_id;
    let response = repo.activate_subscription(request).await?;
    Ok(HttpResponse::Created().json(response))
}

pub async fn list_entitlements(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let requested_user_id = path.into_inner();
    let auth_user_id = authenticated_user_id(&req, repo.pool()).await?;
    if auth_user_id != requested_user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match authenticated user",
        ));
    }
    let entries = repo.list_user_entitlements(auth_user_id).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "entitlements": entries })))
}

pub async fn create_chat_feedback(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
    body: web::Json<CreateChatFeedbackRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    request.user_id = Some(authenticated_user_id(&req, repo.pool()).await?);
    request.message_id = Some(path.into_inner());
    let id = repo.create_chat_feedback(request).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn report_answer(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
    body: web::Json<ReportAnswerRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    request.user_id = Some(authenticated_user_id(&req, repo.pool()).await?);
    request.message_id = Some(path.into_inner());
    if request.report_reason.trim().is_empty() {
        return Err(ApiError::bad_request("report_reason is required"));
    }
    let id = repo.report_answer(request).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn approved_rag_sources(
    repo: web::Data<Phase2Repository>,
    query: web::Query<ModuleQuery>,
) -> Result<HttpResponse, ApiError> {
    let module = normalized_module(&query.module)?;
    let items = repo.list_approved_rag_sources(&module).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "sources": items })))
}

pub async fn log_rag_retrieval(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LogRagRetrievalRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.log_rag_retrieval(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn log_citation_event(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LogCitationEventRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.log_citation_event(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn log_safety_classification(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LogSafetyClassificationRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.log_safety_classification(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn log_mastermind_decision(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LogMastermindDecisionRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.log_mastermind_decision(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn enqueue_scholar_review(
    repo: web::Data<Phase2Repository>,
    body: web::Json<EnqueueScholarReviewRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.enqueue_scholar_review(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn log_wasm_event(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LogWasmVerificationRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.log_wasm_verification(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn upsert_admin_role(
    repo: web::Data<Phase2Repository>,
    body: web::Json<UpsertAdminRoleRequest>,
) -> Result<HttpResponse, ApiError> {
    let response = repo.upsert_admin_role(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(response))
}

pub async fn log_admin_action(
    repo: web::Data<Phase2Repository>,
    body: web::Json<LogAdminActionRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.log_admin_action(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_scholar_account(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateScholarAccountRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_scholar_account(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn assign_scholar_review(
    repo: web::Data<Phase2Repository>,
    body: web::Json<AssignScholarReviewRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.assign_scholar_review(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn source_approval_queue(
    repo: web::Data<Phase2Repository>,
) -> Result<HttpResponse, ApiError> {
    let items: Vec<SourceApprovalItem> = repo.list_source_approval_queue().await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "queue": items })))
}

pub async fn create_source_approval_item(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateSourceApprovalItemRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_source_approval_item(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_notification_template(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateNotificationTemplateRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_notification_template(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn enqueue_notification(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    body: web::Json<EnqueueNotificationRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    request.user_id = authenticated_user_id(&req, repo.pool()).await?;
    let id = repo.enqueue_notification(request).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn list_notifications(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, repo.pool()).await?;
    let notifications = repo.list_notifications(user_id).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "notifications": notifications })))
}

pub async fn mark_notification_read(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    notification_id: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, repo.pool()).await?;
    match repo
        .mark_notification_read(user_id, notification_id.into_inner())
        .await?
    {
        Some(notification) => Ok(HttpResponse::Ok().json(notification)),
        None => Err(ApiError::not_found("notification not found")),
    }
}

pub async fn upsert_device_token(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    body: web::Json<UpsertDeviceTokenRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    request.user_id = authenticated_user_id(&req, repo.pool()).await?;
    let id = repo.upsert_device_token(request).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_support_ticket(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateSupportTicketRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    request.user_id = Some(authenticated_user_id(&req, repo.pool()).await?);
    let response = repo.create_support_ticket(request).await?;
    Ok(HttpResponse::Created().json(response))
}

pub async fn append_support_ticket_message(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
    body: web::Json<AppendSupportTicketMessageRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut request = body.into_inner();
    request.support_ticket_id = path.into_inner();
    if request.message_body.trim().is_empty() {
        return Err(ApiError::bad_request("message_body is required"));
    }
    let auth_user_id = authenticated_user_id(&req, repo.pool()).await?;
    let owner_id = repo
        .support_ticket_owner(request.support_ticket_id)
        .await?
        .ok_or_else(|| ApiError::not_found("support ticket not found"))?;
    if owner_id != auth_user_id {
        return Err(ApiError::unauthorized(
            "requested support ticket does not belong to authenticated user",
        ));
    }
    request.sender_user_id = Some(auth_user_id);
    request.sender_type = "user".to_string();
    let id = repo.append_support_ticket_message(request).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn get_support_ticket(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let support_ticket_id = path.into_inner();
    let auth_user_id = authenticated_user_id(&req, repo.pool()).await?;
    let ticket = repo
        .get_support_ticket_owned_by(support_ticket_id, auth_user_id)
        .await?;
    Ok(HttpResponse::Ok().json(ticket))
}

pub async fn create_audit_log(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateAuditLogRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_audit_log(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_security_log(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateSecurityLogRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_security_log(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn request_account_deletion(
    req: HttpRequest,
    repo: web::Data<Phase2Repository>,
) -> Result<HttpResponse, ApiError> {
    let user_id = authenticated_user_id(&req, repo.pool()).await?;
    let request_id = req
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let audit_id: i64 = sqlx::query_scalar(
        r#"
        INSERT INTO public.audit_logs (event_type, actor_type, actor_id, request_id, payload)
        VALUES ('account_deletion_requested', 'user', $1, $2, $3)
        RETURNING id
        "#,
    )
    .bind(user_id.to_string())
    .bind(&request_id)
    .bind(serde_json::json!({
        "source": "mobile_app",
        "status": "queued",
        "pii_minimized": true
    }))
    .fetch_one(repo.pool())
    .await
    .map_err(|_| ApiError::internal("failed to create account deletion audit event"))?;

    let outbox_id: Uuid = sqlx::query_scalar(
        r#"
        INSERT INTO outbox.events (event_type, payload, status)
        VALUES ('account_deletion_requested', $1, 'Pending')
        RETURNING id
        "#,
    )
    .bind(serde_json::json!({
        "user_id": user_id,
        "audit_id": audit_id,
        "request_id": request_id
    }))
    .fetch_one(repo.pool())
    .await
    .map_err(|_| ApiError::internal("failed to enqueue account deletion event"))?;

    Ok(HttpResponse::Accepted().json(serde_json::json!({
        "status": "queued",
        "request_id": request_id,
        "audit_id": audit_id,
        "outbox_event_id": outbox_id
    })))
}

pub async fn create_app_event(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateEventRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_app_event(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_chat_event(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateEventRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_chat_event(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_rag_event(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateEventRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_rag_event(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

pub async fn create_admin_event(
    repo: web::Data<Phase2Repository>,
    body: web::Json<CreateEventRequest>,
) -> Result<HttpResponse, ApiError> {
    let id = repo.create_admin_event(body.into_inner()).await?;
    Ok(HttpResponse::Created().json(serde_json::json!({ "id": id })))
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{http::StatusCode, test, App};
    use chrono::{Duration, Utc};
    use sqlx::PgPool;

    async fn required_repo_with_pool() -> (Phase2Repository, PgPool) {
        let database_url = std::env::var("DATABASE_URL")
            .expect("DATABASE_URL is required for phase2 DB integration tests");
        let pool = PgPool::connect(&database_url)
            .await
            .expect("connect phase2 DB integration pool");

        sqlx::query("SELECT pg_advisory_lock(7242001)")
            .execute(&pool)
            .await
            .expect("lock phase2 schema setup");
        let migration_result = sqlx::raw_sql(include_str!(
            "../../db/20260529_phase3_full_product_schema_revision2.sql"
        ))
        .execute(&pool)
        .await;
        sqlx::query("SELECT pg_advisory_unlock(7242001)")
            .execute(&pool)
            .await
            .expect("unlock phase2 schema setup");
        assert!(
            migration_result.is_ok(),
            "required phase2 schema migration failed"
        );
        let repo = Phase2Repository::new(pool.clone());
        (repo, pool)
    }

    async fn required_repo() -> Phase2Repository {
        let (repo, _pool) = required_repo_with_pool().await;
        repo
    }

    fn unique(suffix: &str) -> String {
        format!("phase2-{}-{}", suffix, Uuid::new_v4())
    }

    fn answer_service_data(pool: PgPool) -> web::Data<crate::services::IslamicAnswerService> {
        let repo = crate::services::IslamicKnowledgeRepository::new(pool.clone());
        let embeddings = crate::services::EmbeddingsService::new(
            &std::env::var("SAKINA_EMBEDDING_BASE_URL")
                .unwrap_or_else(|_| "http://localhost:11434".to_string()),
        );
        let collection = std::env::var("ISLAMIC_QDRANT_COLLECTION")
            .unwrap_or_else(|_| "sakina_islamic_chunks_en".to_string());
        let qdrant = crate::services::QdrantVectorDB::new(
            &std::env::var("QDRANT_URL").unwrap_or_else(|_| "http://localhost:6333".to_string()),
            &collection,
        );
        let graph = crate::services::KnowledgeGraphService::new(pool.clone());
        let compressor = crate::services::ContextCompressionService::new();
        let hybrid = crate::services::HybridRagService::new(
            pool.clone(),
            embeddings,
            qdrant,
            graph,
            compressor,
        );
        let cache = crate::services::SemanticCacheService::new(pool.clone());
        web::Data::new(crate::services::IslamicAnswerService::new(
            repo, hybrid, cache,
        ))
    }

    #[actix_rt::test]
    async fn auth_domain_wires_user_and_session_tables() {
        let repo = required_repo().await;
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(repo))
                .route("/auth/register", web::post().to(register_user))
                .route("/auth/sessions", web::post().to(create_session)),
        )
        .await;

        let register_req = test::TestRequest::post()
            .uri("/auth/register")
            .set_json(serde_json::json!({
                "email": format!("{}@example.com", unique("auth")),
                "pub_key": unique("pubkey"),
                "provider": "internal",
                "provider_user_id": unique("provider-user"),
                "provider_email": null,
                "email_verified_at": null,
                "metadata": {}
            }))
            .to_request();
        let register_resp = test::call_service(&app, register_req).await;
        assert_eq!(register_resp.status(), StatusCode::CREATED);
        let body: serde_json::Value = test::read_body_json(register_resp).await;
        let user_id = body["user_id"]
            .as_str()
            .expect("user id string")
            .to_string();

        let session_req = test::TestRequest::post()
            .uri("/auth/sessions")
            .set_json(serde_json::json!({
                "user_id": user_id,
                "session_token_hash": unique("session-hash"),
                "refresh_token_hash": unique("refresh-hash"),
                "expires_at": (Utc::now() + Duration::hours(1)).to_rfc3339(),
                "refresh_expires_at": (Utc::now() + Duration::days(30)).to_rfc3339(),
                "ip_address": "127.0.0.1",
                "user_agent": "phase2-test"
            }))
            .to_request();
        let session_resp = test::call_service(&app, session_req).await;
        assert_eq!(session_resp.status(), StatusCode::CREATED);
    }

    #[actix_rt::test]
    async fn register_session_profile_chain_is_fully_wired() {
        let repo = required_repo().await;
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(repo))
                .route("/auth/register", web::post().to(register_user))
                .route("/auth/sessions", web::post().to(create_session))
                .route("/profiles/{user_id}", web::put().to(upsert_profile)),
        )
        .await;

        let register_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/auth/register")
                .set_json(serde_json::json!({
                    "email": format!("{}@example.com", unique("chain")),
                    "pub_key": unique("chain-pub"),
                    "provider": "internal",
                    "provider_user_id": unique("chain-provider"),
                    "provider_email": null,
                    "email_verified_at": null,
                    "metadata": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(register_resp.status(), StatusCode::CREATED);
        let register_body: serde_json::Value = test::read_body_json(register_resp).await;
        let user_id = register_body["user_id"].as_str().expect("user id string");

        let session_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/auth/sessions")
                .set_json(serde_json::json!({
                    "user_id": user_id,
                    "session_token_hash": unique("chain-session"),
                    "refresh_token_hash": unique("chain-refresh"),
                    "expires_at": (Utc::now() + Duration::hours(2)).to_rfc3339(),
                    "refresh_expires_at": (Utc::now() + Duration::days(14)).to_rfc3339(),
                    "ip_address": "127.0.0.1",
                    "user_agent": "phase2-chain-test"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(session_resp.status(), StatusCode::CREATED);

        let profile_resp = test::call_service(
            &app,
            test::TestRequest::put()
                .uri(&format!("/profiles/{user_id}"))
                .insert_header(("x-sakina-user-id", user_id))
                .set_json(serde_json::json!({
                    "user_id": user_id,
                    "full_name": "Lifecycle Chain User",
                    "display_name": "chain-user",
                    "timezone": "UTC",
                    "madhhab_preference": "shafi",
                    "metadata": {},
                    "ui_language": "en",
                    "content_language": "ar",
                    "transliteration_enabled": true,
                    "profile_visibility": "private",
                    "data_export_allowed": true,
                    "analytics_opt_in": false,
                    "text_scale": 1.0,
                    "high_contrast_enabled": false,
                    "reduced_motion_enabled": false,
                    "screen_reader_optimized": false,
                    "in_app_enabled": true,
                    "email_enabled": false,
                    "push_enabled": true
                }))
                .to_request(),
        )
        .await;
        assert_eq!(profile_resp.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn profile_domain_wires_profile_and_family_tables() {
        let repo = required_repo().await;
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(repo))
                .route("/auth/register", web::post().to(register_user))
                .route("/profiles/{user_id}", web::put().to(upsert_profile))
                .route(
                    "/profiles/{user_id}/family",
                    web::post().to(create_family_profile),
                ),
        )
        .await;

        let register_req = test::TestRequest::post()
            .uri("/auth/register")
            .set_json(serde_json::json!({
                "email": format!("{}@example.com", unique("profile")),
                "pub_key": null,
                "provider": "internal",
                "provider_user_id": unique("profile-user"),
                "provider_email": null,
                "email_verified_at": null,
                "metadata": {}
            }))
            .to_request();
        let register_resp = test::call_service(&app, register_req).await;
        let register_body: serde_json::Value = test::read_body_json(register_resp).await;
        let user_id = register_body["user_id"].as_str().expect("user id string");

        let profile_req = test::TestRequest::put()
            .uri(&format!("/profiles/{user_id}"))
            .insert_header(("x-sakina-user-id", user_id))
            .set_json(serde_json::json!({
                "user_id": user_id,
                "full_name": "Phase Two User",
                "display_name": "phase2",
                "timezone": "UTC",
                "madhhab_preference": "hanafi",
                "metadata": {},
                "ui_language": "en",
                "content_language": "ar",
                "transliteration_enabled": true,
                "profile_visibility": "private",
                "data_export_allowed": true,
                "analytics_opt_in": false,
                "text_scale": 1.1,
                "high_contrast_enabled": false,
                "reduced_motion_enabled": false,
                "screen_reader_optimized": false,
                "in_app_enabled": true,
                "email_enabled": false,
                "push_enabled": true
            }))
            .to_request();
        let profile_resp = test::call_service(&app, profile_req).await;
        assert_eq!(profile_resp.status(), StatusCode::OK);

        let family_req = test::TestRequest::post()
            .uri(&format!("/profiles/{user_id}/family"))
            .insert_header(("x-sakina-user-id", user_id))
            .set_json(serde_json::json!({
                "user_id": user_id,
                "family_name": "Phase2 Household",
                "household_size": 3,
                "location_country_code": "GB",
                "metadata": {},
                "children": [{
                    "user_id": null,
                    "preferred_name": "Kid One",
                    "birth_year": 2016,
                    "learning_level": "beginner",
                    "notes": "none",
                    "metadata": {}
                }]
            }))
            .to_request();
        let family_resp = test::call_service(&app, family_req).await;
        assert_eq!(family_resp.status(), StatusCode::CREATED);
    }

    #[actix_rt::test]
    async fn subscription_domain_wires_plan_payment_and_entitlement_tables() {
        std::env::set_var(
            "SAKINA_MANUAL_ENTITLEMENT_GRANT_SECRET",
            "sakina-test-manual-grant-secret-minimum-32",
        );
        let repo = required_repo().await;
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(repo))
                .route("/auth/register", web::post().to(register_user))
                .route(
                    "/subscriptions/{user_id}/activate",
                    web::post().to(activate_subscription),
                )
                .route(
                    "/subscriptions/{user_id}/entitlements",
                    web::get().to(list_entitlements),
                ),
        )
        .await;

        let register_req = test::TestRequest::post()
            .uri("/auth/register")
            .set_json(serde_json::json!({
                "email": format!("{}@example.com", unique("sub")),
                "pub_key": null,
                "provider": "internal",
                "provider_user_id": unique("sub-user"),
                "provider_email": null,
                "email_verified_at": null,
                "metadata": {}
            }))
            .to_request();
        let register_resp = test::call_service(&app, register_req).await;
        let register_body: serde_json::Value = test::read_body_json(register_resp).await;
        let user_id = register_body["user_id"].as_str().expect("user id string");

        let activate_req = test::TestRequest::post()
            .uri(&format!("/subscriptions/{user_id}/activate"))
            .insert_header(("x-sakina-user-id", user_id))
            .insert_header((
                "X-Sakina-Grant-Secret",
                "sakina-test-manual-grant-secret-minimum-32",
            ))
            .set_json(serde_json::json!({
                "user_id": user_id,
                "provider_key": "stripe-test",
                "provider_display_name": "Stripe",
                "provider_customer_ref": unique("cust"),
                "plan_key": unique("plan"),
                "plan_name": "Premium Monthly",
                "billing_interval": "monthly",
                "provider_subscription_ref": unique("sub"),
                "provider_invoice_ref": unique("inv"),
                "provider_transaction_ref": unique("txn"),
                "currency_code": "USD",
                "amount_minor": 1999,
                "current_period_start": Utc::now().to_rfc3339(),
                "current_period_end": (Utc::now() + Duration::days(30)).to_rfc3339(),
                "entitlement_keys": ["chat_premium", "rag_verified"]
            }))
            .to_request();
        let activate_resp = test::call_service(&app, activate_req).await;
        assert_eq!(activate_resp.status(), StatusCode::CREATED);

        let entitlements_req = test::TestRequest::get()
            .uri(&format!("/subscriptions/{user_id}/entitlements"))
            .insert_header(("x-sakina-user-id", user_id))
            .to_request();
        let entitlements_resp = test::call_service(&app, entitlements_req).await;
        assert_eq!(entitlements_resp.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn chat_rag_safety_and_admin_domains_wire_tables() {
        let (repo, pool) = required_repo_with_pool().await;
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(repo))
                .app_data(web::Data::new(pool.clone()))
                .app_data(web::Data::new(crate::services::AiaOrchestrator::new(
                    std::sync::Arc::new(crate::services::SemanticRouter::new()),
                )))
                .app_data(answer_service_data(pool.clone()))
                .route("/auth/register", web::post().to(register_user))
                .route(
                    "/chat/conversations",
                    web::post().to(crate::handlers::chat::create_conversation),
                )
                .route(
                    "/chat/conversations/{id}/messages",
                    web::post().to(crate::handlers::chat::add_message),
                )
                .route(
                    "/chat/messages/{id}/feedback",
                    web::post().to(create_chat_feedback),
                )
                .route("/chat/messages/{id}/report", web::post().to(report_answer))
                .route("/rag/audit/retrieval", web::post().to(log_rag_retrieval))
                .route("/rag/audit/citation", web::post().to(log_citation_event))
                .route("/rag/sources/approved", web::get().to(approved_rag_sources))
                .route(
                    "/safety/classifications",
                    web::post().to(log_safety_classification),
                )
                .route(
                    "/safety/mastermind-decisions",
                    web::post().to(log_mastermind_decision),
                )
                .route(
                    "/safety/scholar-review-queue",
                    web::post().to(enqueue_scholar_review),
                )
                .route("/safety/wasm-events", web::post().to(log_wasm_event))
                .route("/admin/roles", web::post().to(upsert_admin_role))
                .route("/admin/audit-actions", web::post().to(log_admin_action))
                .route("/admin/scholars", web::post().to(create_scholar_account))
                .route(
                    "/admin/scholar-assignments",
                    web::post().to(assign_scholar_review),
                )
                .route(
                    "/admin/source-approval-queue",
                    web::get().to(source_approval_queue),
                )
                .route(
                    "/admin/source-approval-queue",
                    web::post().to(create_source_approval_item),
                ),
        )
        .await;

        let request_id = Uuid::new_v4();
        let user_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO public.users (email, auth_provider, is_active)
            VALUES ($1, 'phase2-chat-test', true)
            RETURNING id
            "#,
        )
        .bind(format!("{}@example.com", unique("chat-user")))
        .fetch_one(&pool)
        .await
        .expect("insert phase2 chat test user");
        let conversation_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/chat/conversations")
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "user_id": user_id,
                    "title": "phase2 lifecycle chat"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(conversation_resp.status(), StatusCode::OK);
        let conversation_body: serde_json::Value = test::read_body_json(conversation_resp).await;
        let conversation_id = conversation_body["id"].as_str().expect("conversation id");

        let add_message_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri(&format!("/chat/conversations/{conversation_id}/messages"))
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "content": "phase2 conversation message"
                }))
                .to_request(),
        )
        .await;
        let add_message_status = add_message_resp.status();
        let add_message_body_bytes = test::read_body(add_message_resp).await;
        assert!(
            add_message_status == StatusCode::OK,
            "add_message returned {add_message_status}: {}",
            String::from_utf8_lossy(&add_message_body_bytes)
        );
        let add_message_body: serde_json::Value =
            serde_json::from_slice(&add_message_body_bytes).expect("add message json");
        let message_id = add_message_body["user_message_id"]
            .as_str()
            .expect("message id");

        let feedback_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri(&format!("/chat/messages/{message_id}/feedback"))
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "user_id": null,
                    "conversation_id": null,
                    "message_id": null,
                    "feedback_type": "thumbs_up",
                    "feedback_score": 5,
                    "feedback_comment": "helpful"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(feedback_resp.status(), StatusCode::CREATED);

        let report_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri(&format!("/chat/messages/{message_id}/report"))
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "user_id": null,
                    "message_id": null,
                    "report_reason": "citation_missing",
                    "report_details": "no source listed"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(report_resp.status(), StatusCode::CREATED);

        let source_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.islamic_sources (
                source_key, source_type, source_status, language, title, review_status
            )
            VALUES ($1, 'quran', 'approved', 'ar', 'Verified Source', 'verified')
            RETURNING id
            "#,
        )
        .bind(unique("source"))
        .fetch_one(&pool)
        .await
        .expect("insert approved source");
        let document_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.islamic_documents (
                source_id, document_key, title, source_type, source_status, review_status
            )
            VALUES ($1, $2, 'Verified Document', 'quran', 'approved', 'verified')
            RETURNING id
            "#,
        )
        .bind(source_id)
        .bind(unique("document"))
        .fetch_one(&pool)
        .await
        .expect("insert approved document");
        let _chunk_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.islamic_chunks (
                document_id, chunk_key, chunk_index, chunk_text, citation_text, source_type, source_status, review_status
            )
            VALUES ($1, $2, 0, 'verified chunk text', 'verified citation', 'quran', 'approved', 'verified')
            RETURNING id
            "#,
        )
        .bind(document_id)
        .bind(unique("chunk"))
        .fetch_one(&pool)
        .await
        .expect("insert approved chunk");

        let approved_sources_resp = test::call_service(
            &app,
            test::TestRequest::get()
                .uri("/rag/sources/approved?module=quran")
                .to_request(),
        )
        .await;
        assert_eq!(approved_sources_resp.status(), StatusCode::OK);
        let approved_sources_body: serde_json::Value =
            test::read_body_json(approved_sources_resp).await;
        let sources = approved_sources_body["sources"]
            .as_array()
            .expect("approved sources array");
        assert!(!sources.is_empty());

        let retrieval_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/rag/audit/retrieval")
                .set_json(serde_json::json!({
                    "request_id": request_id,
                    "user_id": null,
                    "conversation_id": null,
                    "query_text": "test query",
                    "selected_module": "quran",
                    "language": "en",
                    "retrieval_status": "blocked",
                    "citation": null,
                    "confidence": 0.0,
                    "decision_reason": "no verified sources"
                }))
                .to_request(),
        )
        .await;
        let retrieval_status = retrieval_resp.status();
        let retrieval_body_bytes = test::read_body(retrieval_resp).await;
        assert!(
            retrieval_status == StatusCode::CREATED,
            "log_rag_retrieval returned {retrieval_status}: {}",
            String::from_utf8_lossy(&retrieval_body_bytes)
        );
        let retrieval_body: serde_json::Value =
            serde_json::from_slice(&retrieval_body_bytes).expect("retrieval json");
        let retrieval_audit_id = retrieval_body["id"].as_str().expect("retrieval id");

        let citation_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/rag/audit/citation")
                .set_json(serde_json::json!({
                    "request_id": request_id,
                    "retrieval_audit_id": retrieval_audit_id,
                    "citation_text": "none",
                    "verification_status": "failed",
                    "verification_reason": "source not found",
                    "verified_by": "policy"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(citation_resp.status(), StatusCode::CREATED);

        let safety_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/safety/classifications")
                .set_json(serde_json::json!({
                    "request_id": request_id,
                    "user_id": null,
                    "safety_level": "unknown",
                    "islamic_sensitivity": "religious_sensitive",
                    "classifier_version": "v1",
                    "classifier_output": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(safety_resp.status(), StatusCode::CREATED);

        let mastermind_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/safety/mastermind-decisions")
                .set_json(serde_json::json!({
                    "request_id": request_id,
                    "user_id": null,
                    "conversation_id": null,
                    "message_id": null,
                    "language": "en",
                    "intent": "religious_question",
                    "selected_module": "quran",
                    "safety_level": "unknown",
                    "islamic_sensitivity": "religious_sensitive",
                    "rag_allowed": false,
                    "retrieval_required": true,
                    "citations_required": true,
                    "citation_sufficiency": false,
                    "answer_allowed": false,
                    "scholar_review_required": true,
                    "final_response_policy": "defer",
                    "user_subscription_tier": "free",
                    "entitlement_allowed": false,
                    "reason": "insufficient_verified_evidence",
                    "user_message": "deferred pending review",
                    "decision_payload": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(mastermind_resp.status(), StatusCode::CREATED);
        let mastermind_body: serde_json::Value = test::read_body_json(mastermind_resp).await;
        let mastermind_decision_id = mastermind_body["id"].as_str().expect("mastermind id");

        let queue_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/safety/scholar-review-queue")
                .set_json(serde_json::json!({
                    "request_id": request_id,
                    "mastermind_decision_id": mastermind_decision_id,
                    "conversation_id": null,
                    "priority": "normal",
                    "reviewer_notes": "phase2 wiring"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(queue_resp.status(), StatusCode::CREATED);
        let queue_body: serde_json::Value = test::read_body_json(queue_resp).await;
        let scholar_review_queue_id = queue_body["id"].as_str().expect("queue id");

        let wasm_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/safety/wasm-events")
                .set_json(serde_json::json!({
                    "request_id": request_id,
                    "module_name": "mastermind",
                    "decision_type": "fallback",
                    "input_hash": unique("hash"),
                    "output_decision": {},
                    "policy_version": "v1",
                    "runtime_mode": "fallback"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(wasm_resp.status(), StatusCode::CREATED);

        let role_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/admin/roles")
                .set_json(serde_json::json!({
                    "role_key": unique("reviewer"),
                    "role_name": "Reviewer",
                    "permission_keys": [unique("perm")]
                }))
                .to_request(),
        )
        .await;
        assert_eq!(role_resp.status(), StatusCode::CREATED);

        let scholar_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/admin/scholars")
                .set_json(serde_json::json!({
                    "user_id": null,
                    "scholar_slug": unique("scholar"),
                    "display_name": "Scholar Test",
                    "verified": false,
                    "credentials_summary": "none",
                    "account_status": "pending"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(scholar_resp.status(), StatusCode::CREATED);
        let scholar_body: serde_json::Value = test::read_body_json(scholar_resp).await;
        let scholar_account_id = scholar_body["id"].as_str().expect("scholar id");

        let assignment_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/admin/scholar-assignments")
                .set_json(serde_json::json!({
                    "scholar_account_id": scholar_account_id,
                    "scholar_review_queue_id": scholar_review_queue_id,
                    "notes": "assign from test"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(assignment_resp.status(), StatusCode::CREATED);

        let audit_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/admin/audit-actions")
                .set_json(serde_json::json!({
                    "admin_user_id": null,
                    "request_id": request_id,
                    "action_type": "assign_review",
                    "target_type": "scholar_review_queue",
                    "target_id": scholar_review_queue_id,
                    "action_status": "completed",
                    "notes": "ok",
                    "metadata": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(audit_resp.status(), StatusCode::CREATED);

        let source_queue_write_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/admin/source-approval-queue")
                .set_json(serde_json::json!({
                    "source_id": null,
                    "submitted_by": null,
                    "notes": "queue from test"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(source_queue_write_resp.status(), StatusCode::CREATED);

        let queue_list_resp = test::call_service(
            &app,
            test::TestRequest::get()
                .uri("/admin/source-approval-queue")
                .to_request(),
        )
        .await;
        assert_eq!(queue_list_resp.status(), StatusCode::OK);
    }

    #[actix_rt::test]
    async fn notifications_support_and_audit_domains_wire_tables() {
        let (repo, pool) = required_repo_with_pool().await;
        let user_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO public.users (email, auth_provider, is_active)
            VALUES ($1, 'phase2-notification-test', true)
            RETURNING id
            "#,
        )
        .bind(format!("{}@example.com", unique("notify-user")))
        .fetch_one(&pool)
        .await
        .expect("insert phase2 notification test user");
        let app = test::init_service(
            App::new()
                .app_data(web::Data::new(repo))
                .route(
                    "/notifications/templates",
                    web::post().to(create_notification_template),
                )
                .route("/notifications/send", web::post().to(enqueue_notification))
                .route(
                    "/notifications/device-tokens",
                    web::post().to(upsert_device_token),
                )
                .route("/support/tickets", web::post().to(create_support_ticket))
                .route(
                    "/support/tickets/{ticket_id}",
                    web::get().to(get_support_ticket),
                )
                .route(
                    "/support/tickets/{ticket_id}/messages",
                    web::post().to(append_support_ticket_message),
                )
                .route("/audit/logs", web::post().to(create_audit_log))
                .route("/security/logs", web::post().to(create_security_log))
                .route("/events/app", web::post().to(create_app_event))
                .route("/events/chat", web::post().to(create_chat_event))
                .route("/events/rag", web::post().to(create_rag_event))
                .route("/events/admin", web::post().to(create_admin_event)),
        )
        .await;

        let template_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/notifications/templates")
                .set_json(serde_json::json!({
                    "template_key": unique("welcome"),
                    "channel": "in_app",
                    "subject_template": "Welcome",
                    "body_template": "Welcome to Sakina",
                    "locale": "en-US"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(template_resp.status(), StatusCode::CREATED);
        let template_body: serde_json::Value = test::read_body_json(template_resp).await;
        let template_id = template_body["id"].as_str().expect("template id");

        let send_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/notifications/send")
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "user_id": user_id,
                    "template_id": template_id,
                    "channel": "in_app",
                    "title": "t",
                    "body": "b",
                    "payload": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(send_resp.status(), StatusCode::CREATED);
        let send_body: serde_json::Value = test::read_body_json(send_resp).await;
        let notification_id = send_body["id"]
            .as_str()
            .and_then(|v| Uuid::parse_str(v).ok())
            .expect("notification id");
        let delivery_attempt_count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM public.notification_delivery_attempts WHERE user_notification_id = $1",
        )
        .bind(notification_id)
        .fetch_one(&pool)
        .await
        .expect("count delivery attempts");
        assert_eq!(delivery_attempt_count, 1);

        let token_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/notifications/device-tokens")
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "user_id": user_id,
                    "platform": "android",
                    "token_hash": unique("token"),
                    "app_version": "1.0.0"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(token_resp.status(), StatusCode::CREATED);

        let ticket_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/support/tickets")
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "user_id": user_id,
                    "priority": "normal",
                    "category": "account",
                    "subject": "Need help",
                    "message_body": "Support message"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(ticket_resp.status(), StatusCode::CREATED);
        let ticket_body: serde_json::Value = test::read_body_json(ticket_resp).await;
        let ticket_id = ticket_body["ticket_id"].as_str().expect("ticket id");

        let append_ticket_message_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri(&format!("/support/tickets/{ticket_id}/messages"))
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .set_json(serde_json::json!({
                    "support_ticket_id": ticket_id,
                    "sender_type": "support",
                    "sender_user_id": null,
                    "message_body": "Follow up from support"
                }))
                .to_request(),
        )
        .await;
        assert_eq!(append_ticket_message_resp.status(), StatusCode::CREATED);

        let get_ticket_resp = test::call_service(
            &app,
            test::TestRequest::get()
                .uri(&format!("/support/tickets/{ticket_id}"))
                .insert_header(("x-sakina-user-id", user_id.to_string()))
                .to_request(),
        )
        .await;
        assert_eq!(get_ticket_resp.status(), StatusCode::OK);
        let get_ticket_body: serde_json::Value = test::read_body_json(get_ticket_resp).await;
        let message_count = get_ticket_body["messages"]
            .as_array()
            .expect("messages array")
            .len();
        assert!(message_count >= 2);

        let audit_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/audit/logs")
                .set_json(serde_json::json!({
                    "event_type": "phase2_test",
                    "actor_type": "user",
                    "actor_id": user_id,
                    "request_id": Uuid::new_v4().to_string(),
                    "payload": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(audit_resp.status(), StatusCode::CREATED);

        let security_resp = test::call_service(
            &app,
            test::TestRequest::post()
                .uri("/security/logs")
                .set_json(serde_json::json!({
                    "event_type": "login_attempt",
                    "severity": "info",
                    "user_id": user_id,
                    "ip_address": "127.0.0.1",
                    "request_id": Uuid::new_v4().to_string(),
                    "details": {}
                }))
                .to_request(),
        )
        .await;
        assert_eq!(security_resp.status(), StatusCode::CREATED);

        for route in [
            "/events/app",
            "/events/chat",
            "/events/rag",
            "/events/admin",
        ] {
            let event_user_id = if route == "/events/rag" {
                serde_json::Value::Null
            } else {
                serde_json::json!(user_id)
            };
            let event_resp = test::call_service(
                &app,
                test::TestRequest::post()
                    .uri(route)
                    .set_json(serde_json::json!({
                        "request_id": Uuid::new_v4(),
                        "user_id": event_user_id,
                        "admin_user_id": null,
                        "session_id": null,
                        "retrieval_audit_id": null,
                        "conversation_id": null,
                        "message_id": null,
                        "event_name": format!("phase2{}", route),
                        "event_payload": {}
                    }))
                    .to_request(),
            )
            .await;
            let event_status = event_resp.status();
            if event_status != StatusCode::CREATED {
                let body = test::read_body(event_resp).await;
                panic!(
                    "route {route} returned {event_status}; body={}",
                    String::from_utf8_lossy(&body)
                );
            }
        }
    }
}
