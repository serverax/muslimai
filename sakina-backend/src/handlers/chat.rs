use actix_web::{web, HttpRequest, HttpResponse, ResponseError};
use sqlx::Row;
use uuid::Uuid;

use crate::error::error_response;
use crate::models::{
    AddMessageRequest, AddMessageResponse, BrainRouteRequest, ConversationMessageResponse,
    CreateConversationRequest, CreateConversationResponse, GetConversationResponse,
};
use crate::services::{
    authenticated_user_id, AiaOrchestrator, AskIslamicRequest, IslamicAnswerService,
};

pub async fn create_conversation(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<CreateConversationRequest>,
) -> HttpResponse {
    let authenticated_user_id = match authenticated_user_id(&req, pool.get_ref()).await {
        Ok(user_id) => user_id,
        Err(err) => return err.error_response(),
    };

    let title = payload
        .title
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .unwrap_or("New conversation");
    if title.len() > 200 {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "title exceeds maximum length",
        );
    }
    if let Some(requested_user_id) = payload.user_id {
        if requested_user_id != authenticated_user_id {
            return error_response(
                actix_web::http::StatusCode::UNAUTHORIZED,
                "unauthorized",
                "requested user_id does not match authenticated user",
            );
        }
    }
    let brain = aia.route(&BrainRouteRequest {
        message: title.to_string(),
        language: Some("en".to_string()),
        user_subscription_tier: "free".to_string(),
        safety_context: None,
        request_id: None,
    });
    if !brain.can_generate {
        return error_response(
            actix_web::http::StatusCode::FORBIDDEN,
            "forbidden",
            "conversation creation blocked by Mother Brain safety policy",
        );
    }

    let result = sqlx::query(
        r#"
        INSERT INTO sakina_ai.conversations (user_id, title)
        VALUES ($1, $2)
        RETURNING id, user_id, title, created_at::text AS created_at, updated_at::text AS updated_at
        "#,
    )
    .bind(authenticated_user_id)
    .bind(title)
    .fetch_one(pool.get_ref())
    .await;

    match result {
        Ok(row) => HttpResponse::Ok().json(CreateConversationResponse {
            id: row.get("id"),
            user_id: row.get("user_id"),
            title: row.get("title"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        }),
        Err(err) => {
            tracing::error!("create conversation failed: {}", err);
            error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to create conversation",
            )
        }
    }
}

pub async fn get_conversation(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    path: web::Path<Uuid>,
) -> HttpResponse {
    let conversation_id = path.into_inner();
    let authenticated_user_id = match authenticated_user_id(&req, pool.get_ref()).await {
        Ok(user_id) => user_id,
        Err(err) => return err.error_response(),
    };
    let conversation = sqlx::query(
        r#"
        SELECT id, user_id, title, created_at::text AS created_at, updated_at::text AS updated_at
        FROM sakina_ai.conversations
        WHERE id = $1
          AND user_id = $2
        "#,
    )
    .bind(conversation_id)
    .bind(authenticated_user_id)
    .fetch_optional(pool.get_ref())
    .await;

    let Some(conversation_row) = (match conversation {
        Ok(row) => row,
        Err(err) => {
            tracing::error!("get conversation failed: {}", err);
            return error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to fetch conversation",
            );
        }
    }) else {
        return error_response(
            actix_web::http::StatusCode::NOT_FOUND,
            "not_found",
            "conversation not found",
        );
    };

    let messages_result = sqlx::query(
        r#"
        SELECT id, role, content, created_at::text AS created_at
        FROM sakina_ai.messages
        WHERE conversation_id = $1
        ORDER BY created_at ASC
        "#,
    )
    .bind(conversation_id)
    .fetch_all(pool.get_ref())
    .await;

    let messages = match messages_result {
        Ok(rows) => rows
            .into_iter()
            .map(|row| ConversationMessageResponse {
                id: row.get("id"),
                role: row.get("role"),
                content: row.get("content"),
                created_at: row.get("created_at"),
            })
            .collect::<Vec<_>>(),
        Err(err) => {
            tracing::error!("get conversation messages failed: {}", err);
            return error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to fetch conversation messages",
            );
        }
    };

    HttpResponse::Ok().json(GetConversationResponse {
        id: conversation_row.get("id"),
        user_id: conversation_row.get("user_id"),
        title: conversation_row.get("title"),
        created_at: conversation_row.get("created_at"),
        updated_at: conversation_row.get("updated_at"),
        messages,
    })
}

pub async fn add_message(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    answer_service: web::Data<IslamicAnswerService>,
    pool: web::Data<sqlx::PgPool>,
    path: web::Path<Uuid>,
    payload: web::Json<AddMessageRequest>,
) -> HttpResponse {
    let conversation_id = path.into_inner();
    let content = payload.content.trim();
    if content.is_empty() {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "message content is required",
        );
    }
    if content.len() > 4000 {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "message content exceeds maximum length",
        );
    }
    let authenticated_user_id = match authenticated_user_id(&req, pool.get_ref()).await {
        Ok(user_id) => user_id,
        Err(err) => return err.error_response(),
    };

    let conversation_exists = sqlx::query_scalar::<_, Option<Uuid>>(
        "SELECT id FROM sakina_ai.conversations WHERE id = $1 AND user_id = $2",
    )
    .bind(conversation_id)
    .bind(authenticated_user_id)
    .fetch_one(pool.get_ref())
    .await;

    match conversation_exists {
        Ok(Some(_)) => {}
        Ok(None) => {
            return error_response(
                actix_web::http::StatusCode::NOT_FOUND,
                "not_found",
                "conversation not found",
            );
        }
        Err(err) => {
            tracing::error!("conversation lookup failed: {}", err);
            return error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to load conversation",
            );
        }
    }
    let answer_payload = match aia
        .answer_islamic(
            &answer_service,
            AskIslamicRequest {
                question: content.to_string(),
                language: Some("en".to_string()),
                top_k: Some(5),
                min_score: Some(0.0),
                user_id: Some(authenticated_user_id),
            },
        )
        .await
    {
        Ok(value) => value,
        Err(err) => return err.error_response(),
    };
    let answer_text = answer_payload
        .get("answer")
        .and_then(serde_json::Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("Sakina could not produce a verified response for this question.")
        .to_string();
    let trace_id = answer_payload
        .get("trace_id")
        .and_then(serde_json::Value::as_str)
        .map(str::to_string);

    let mut tx = match pool.begin().await {
        Ok(tx) => tx,
        Err(err) => {
            tracing::error!("open transaction failed: {}", err);
            return error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to persist message",
            );
        }
    };

    let user_message_id = match sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO sakina_ai.messages (conversation_id, user_id, role, content)
        VALUES ($1, $2, 'user', $3)
        RETURNING id
        "#,
    )
    .bind(conversation_id)
    .bind(authenticated_user_id)
    .bind(content)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(err) => {
            tracing::error!("insert user message failed: {}", err);
            return error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to persist user message",
            );
        }
    };

    let assistant_message_id = match sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO sakina_ai.messages (conversation_id, user_id, role, content)
        VALUES ($1, $2, 'assistant', $3)
        RETURNING id
        "#,
    )
    .bind(conversation_id)
    .bind(authenticated_user_id)
    .bind(&answer_text)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(err) => {
            tracing::error!("insert assistant message failed: {}", err);
            return error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to persist assistant message",
            );
        }
    };

    if let Err(err) = tx.commit().await {
        tracing::error!("commit chat message transaction failed: {}", err);
        return error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to commit messages",
        );
    }

    HttpResponse::Ok().json(AddMessageResponse {
        conversation_id,
        user_message_id,
        assistant_message_id: Some(assistant_message_id),
        response: Some(answer_text),
        trace_id,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;
    use sha2::{Digest, Sha256};
    use sqlx::{PgPool, Row};

    async fn required_pool() -> PgPool {
        let database_url = std::env::var("DATABASE_URL")
            .expect("DATABASE_URL is required for chat DB integration tests");
        PgPool::connect(&database_url)
            .await
            .expect("connect chat DB integration pool")
    }

    async fn ensure_chat_schema(pool: &PgPool) {
        sqlx::query("SELECT pg_advisory_lock(7242001)")
            .execute(pool)
            .await
            .expect("lock chat schema setup");

        sqlx::query("CREATE SCHEMA IF NOT EXISTS sakina_ai")
            .execute(pool)
            .await
            .expect("create sakina_ai schema");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.conversations (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NULL,
                title TEXT NOT NULL DEFAULT 'New conversation',
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create conversations table");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.messages (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                conversation_id UUID NOT NULL REFERENCES sakina_ai.conversations(id) ON DELETE CASCADE,
                role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
                content TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create messages table");

        sqlx::query("ALTER TABLE sakina_ai.messages ADD COLUMN IF NOT EXISTS user_id UUID NULL")
            .execute(pool)
            .await
            .expect("ensure messages user_id column");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS public.auth_sessions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL,
                session_token_hash TEXT NOT NULL,
                ip_address INET NULL,
                user_agent TEXT NULL,
                expires_at TIMESTAMPTZ NOT NULL,
                revoked_at TIMESTAMPTZ NULL,
                last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create auth_sessions table");

        sqlx::query(
            "ALTER TABLE public.auth_sessions ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ NULL, ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()",
        )
        .execute(pool)
        .await
        .expect("ensure auth session revocation columns");

        sqlx::query("SELECT pg_advisory_unlock(7242001)")
            .execute(pool)
            .await
            .expect("unlock chat schema setup");
    }

    fn token_hash(token: &str) -> String {
        let digest = Sha256::digest(token.as_bytes());
        format!("{:x}", digest)
    }

    async fn insert_session(pool: &PgPool, user_id: Uuid, token: &str) {
        sqlx::query(
            r#"
            INSERT INTO public.users (id, email, auth_provider, is_active)
            VALUES ($1, $2, 'chat-test', true)
            ON CONFLICT (id) DO NOTHING
            "#,
        )
        .bind(user_id)
        .bind(format!("chat-{user_id}@example.com"))
        .execute(pool)
        .await
        .expect("insert chat test user");
        sqlx::query(
            r#"
            INSERT INTO public.auth_sessions (
                user_id, session_token_hash, expires_at
            )
            VALUES ($1, $2, now() + interval '1 hour')
            "#,
        )
        .bind(user_id)
        .bind(token_hash(token))
        .execute(pool)
        .await
        .expect("insert session");
    }

    fn bearer_request(token: &str) -> actix_web::test::TestRequest {
        actix_web::test::TestRequest::default()
            .insert_header(("Authorization", format!("Bearer {}", token)))
    }

    fn test_jwt(user_id: Uuid) -> String {
        crate::services::auth::issue_jwt(user_id, 3600)
            .expect("issue chat test JWT")
            .0
    }

    fn aia_data() -> web::Data<AiaOrchestrator> {
        web::Data::new(AiaOrchestrator::new(std::sync::Arc::new(
            crate::services::SemanticRouter::new(),
        )))
    }

    fn answer_service_data(pool: PgPool) -> web::Data<IslamicAnswerService> {
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
        web::Data::new(IslamicAnswerService::new(repo, hybrid, cache))
    }

    #[actix_rt::test]
    async fn create_conversation_returns_created_record() {
        let pool = required_pool().await;
        ensure_chat_schema(&pool).await;
        let user_id = Uuid::new_v4();
        let token = test_jwt(user_id);
        insert_session(&pool, user_id, &token).await;
        let response = create_conversation(
            bearer_request(&token).to_http_request(),
            aia_data(),
            web::Data::new(pool.clone()),
            web::Json(CreateConversationRequest {
                user_id: None,
                title: Some("Phase 3 chat foundation".to_string()),
            }),
        )
        .await;

        assert_eq!(response.status(), actix_web::http::StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"title\":\"Phase 3 chat foundation\""));
    }

    #[actix_rt::test]
    async fn add_message_persists_user_and_assistant_messages_with_trace() {
        let pool = required_pool().await;
        ensure_chat_schema(&pool).await;

        let user_id = Uuid::new_v4();
        let token = test_jwt(user_id);
        insert_session(&pool, user_id, &token).await;
        let conversation_id: Uuid = sqlx::query_scalar(
            "INSERT INTO sakina_ai.conversations (user_id, title) VALUES ($1, $2) RETURNING id",
        )
        .bind(user_id)
        .bind("Test conversation")
        .fetch_one(&pool)
        .await
        .expect("insert conversation");

        let response = add_message(
            bearer_request(&token).to_http_request(),
            aia_data(),
            answer_service_data(pool.clone()),
            web::Data::new(pool.clone()),
            web::Path::from(conversation_id),
            web::Json(AddMessageRequest {
                content: "As-salaam".to_string(),
            }),
        )
        .await;
        assert_eq!(response.status(), actix_web::http::StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"assistant_message_id\""));
        assert!(text.contains("\"response\""));
        assert!(text.contains("\"trace_id\""));

        let row = sqlx::query(
            "SELECT COUNT(*) AS count FROM sakina_ai.messages WHERE conversation_id = $1",
        )
        .bind(conversation_id)
        .fetch_one(&pool)
        .await
        .expect("count messages");
        let count: i64 = row.get("count");
        assert_eq!(count, 2);
    }

    #[actix_rt::test]
    async fn get_conversation_returns_messages() {
        let pool = required_pool().await;
        ensure_chat_schema(&pool).await;

        let user_id = Uuid::new_v4();
        let token = test_jwt(user_id);
        insert_session(&pool, user_id, &token).await;
        let conversation_id: Uuid = sqlx::query_scalar(
            "INSERT INTO sakina_ai.conversations (user_id, title) VALUES ($1, $2) RETURNING id",
        )
        .bind(user_id)
        .bind("Fetch conversation")
        .fetch_one(&pool)
        .await
        .expect("insert conversation");

        sqlx::query(
            "INSERT INTO sakina_ai.messages (conversation_id, user_id, role, content) VALUES ($1, $2, 'user', $3)",
        )
        .bind(conversation_id)
        .bind(user_id)
        .bind("hello")
        .execute(&pool)
        .await
        .expect("insert message");

        let response = get_conversation(
            bearer_request(&token).to_http_request(),
            web::Data::new(pool),
            web::Path::from(conversation_id),
        )
        .await;
        assert_eq!(response.status(), actix_web::http::StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"messages\""));
        assert!(text.contains("\"role\":\"user\""));
    }

    #[actix_rt::test]
    async fn add_message_for_missing_conversation_uses_normalized_error() {
        let pool = PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = add_message(
            actix_web::test::TestRequest::default()
                .insert_header(("Authorization", "Bearer invalid"))
                .to_http_request(),
            aia_data(),
            answer_service_data(pool.clone()),
            web::Data::new(pool),
            web::Path::from(Uuid::new_v4()),
            web::Json(AddMessageRequest {
                content: "hello".to_string(),
            }),
        )
        .await;

        // Lazy pool cannot connect; contract still requires normalized error shape.
        assert_eq!(response.status(), actix_web::http::StatusCode::UNAUTHORIZED);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"unauthorized\""));
    }

    #[actix_rt::test]
    async fn unsafe_message_is_blocked_by_mother_brain() {
        let pool = required_pool().await;
        ensure_chat_schema(&pool).await;

        let user_id = Uuid::new_v4();
        let token = test_jwt(user_id);
        insert_session(&pool, user_id, &token).await;
        let conversation_id: Uuid = sqlx::query_scalar(
            "INSERT INTO sakina_ai.conversations (user_id, title) VALUES ($1, $2) RETURNING id",
        )
        .bind(user_id)
        .bind("Safety conversation")
        .fetch_one(&pool)
        .await
        .expect("insert conversation");

        let response = add_message(
            bearer_request(&token).to_http_request(),
            aia_data(),
            answer_service_data(pool.clone()),
            web::Data::new(pool.clone()),
            web::Path::from(conversation_id),
            web::Json(AddMessageRequest {
                content: "I want to harm myself".to_string(),
            }),
        )
        .await;
        assert_eq!(response.status(), actix_web::http::StatusCode::UNAUTHORIZED);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"unauthorized\""));
    }

    #[actix_rt::test]
    async fn empty_message_is_rejected() {
        let pool = PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = add_message(
            actix_web::test::TestRequest::default()
                .insert_header(("Authorization", "Bearer invalid"))
                .to_http_request(),
            aia_data(),
            answer_service_data(pool.clone()),
            web::Data::new(pool),
            web::Path::from(Uuid::new_v4()),
            web::Json(AddMessageRequest {
                content: "   ".to_string(),
            }),
        )
        .await;
        assert_eq!(response.status(), actix_web::http::StatusCode::BAD_REQUEST);
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"bad_request\""));
    }
}
