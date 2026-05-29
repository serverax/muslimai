use actix_web::{web, HttpResponse};
use sqlx::Row;
use uuid::Uuid;

use crate::error::error_response;
use crate::models::{
    AddMessageRequest, AddMessageResponse, ConversationMessageResponse, CreateConversationRequest,
    CreateConversationResponse, GetConversationResponse,
};

pub async fn create_conversation(
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<CreateConversationRequest>,
) -> HttpResponse {
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

    let result = sqlx::query(
        r#"
        INSERT INTO sakina_ai.conversations (user_id, title)
        VALUES ($1, $2)
        RETURNING id, user_id, title, created_at::text AS created_at, updated_at::text AS updated_at
        "#,
    )
    .bind(payload.user_id)
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
    pool: web::Data<sqlx::PgPool>,
    path: web::Path<Uuid>,
) -> HttpResponse {
    let conversation_id = path.into_inner();
    let conversation = sqlx::query(
        r#"
        SELECT id, user_id, title, created_at::text AS created_at, updated_at::text AS updated_at
        FROM sakina_ai.conversations
        WHERE id = $1
        "#,
    )
    .bind(conversation_id)
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

    let conversation_exists = sqlx::query_scalar::<_, Option<Uuid>>(
        "SELECT id FROM sakina_ai.conversations WHERE id = $1",
    )
    .bind(conversation_id)
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
        INSERT INTO sakina_ai.messages (conversation_id, role, content)
        VALUES ($1, 'user', $2)
        RETURNING id
        "#,
    )
    .bind(conversation_id)
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
        assistant_message_id: None,
        response: None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;
    use sqlx::{PgPool, Row};

    async fn maybe_pool() -> Option<PgPool> {
        let database_url = match std::env::var("DATABASE_URL") {
            Ok(v) if !v.trim().is_empty() => v,
            _ => return None,
        };
        PgPool::connect(&database_url).await.ok()
    }

    async fn ensure_chat_schema(pool: &PgPool) {
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
    }

    #[actix_rt::test]
    async fn create_conversation_returns_created_record() {
        let Some(pool) = maybe_pool().await else {
            eprintln!("DATABASE_URL not set; skipping chat DB tests");
            return;
        };
        ensure_chat_schema(&pool).await;
        let response = create_conversation(
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
    async fn add_message_persists_user_message_without_assistant_placeholder() {
        let Some(pool) = maybe_pool().await else {
            eprintln!("DATABASE_URL not set; skipping chat DB tests");
            return;
        };
        ensure_chat_schema(&pool).await;

        let conversation_id: Uuid = sqlx::query_scalar(
            "INSERT INTO sakina_ai.conversations (title) VALUES ($1) RETURNING id",
        )
        .bind("Test conversation")
        .fetch_one(&pool)
        .await
        .expect("insert conversation");

        let response = add_message(
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
        assert!(text.contains("\"assistant_message_id\":null"));
        assert!(text.contains("\"response\":null"));

        let row = sqlx::query(
            "SELECT COUNT(*) AS count FROM sakina_ai.messages WHERE conversation_id = $1",
        )
        .bind(conversation_id)
        .fetch_one(&pool)
        .await
        .expect("count messages");
        let count: i64 = row.get("count");
        assert_eq!(count, 1);
    }

    #[actix_rt::test]
    async fn get_conversation_returns_messages() {
        let Some(pool) = maybe_pool().await else {
            eprintln!("DATABASE_URL not set; skipping chat DB tests");
            return;
        };
        ensure_chat_schema(&pool).await;

        let conversation_id: Uuid = sqlx::query_scalar(
            "INSERT INTO sakina_ai.conversations (title) VALUES ($1) RETURNING id",
        )
        .bind("Fetch conversation")
        .fetch_one(&pool)
        .await
        .expect("insert conversation");

        sqlx::query(
            "INSERT INTO sakina_ai.messages (conversation_id, role, content) VALUES ($1, 'user', $2)",
        )
        .bind(conversation_id)
        .bind("hello")
        .execute(&pool)
        .await
        .expect("insert message");

        let response =
            get_conversation(web::Data::new(pool), web::Path::from(conversation_id)).await;
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
            web::Data::new(pool),
            web::Path::from(Uuid::new_v4()),
            web::Json(AddMessageRequest {
                content: "hello".to_string(),
            }),
        )
        .await;

        // Lazy pool cannot connect; contract still requires normalized error shape.
        assert_eq!(
            response.status(),
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR
        );
        let body = to_bytes(response.into_body()).await.expect("body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("\"error\""));
        assert!(text.contains("\"code\":\"internal_error\""));
    }

    #[actix_rt::test]
    async fn empty_message_is_rejected() {
        let pool = PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = add_message(
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
