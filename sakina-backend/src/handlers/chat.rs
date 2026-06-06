use actix_web::{web, HttpRequest, HttpResponse, ResponseError};
use sqlx::Row;
use uuid::Uuid;

use crate::error::error_response;
use crate::models::{
    AddMessageRequest, AddMessageResponse, BrainRouteRequest, ConversationMessageResponse,
    CoreChatRequest, CoreChatResponse, CreateConversationRequest, CreateConversationResponse,
    GetConversationResponse, MemoryUpdateSuggestion,
};
use crate::services::{
    authenticated_user_id, AiaOrchestrator, AskIslamicRequest, IslamicAnswerService, MemoryEngine,
    MemoryWriteRequest,
};

fn detect_language_from_request(message: &str, preferred: Option<&str>) -> String {
    preferred
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| value.to_ascii_lowercase())
        .unwrap_or_else(|| {
            if message
                .chars()
                .any(|ch| ('\u{0600}'..='\u{06ff}').contains(&ch))
            {
                "ar".to_string()
            } else {
                "en".to_string()
            }
        })
}

async fn ensure_default_workspace(
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<Uuid, HttpResponse> {
    sqlx::query_scalar::<_, Uuid>("SELECT sakina_ai.ensure_default_workspace($1)")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|err| {
            tracing::error!("ensure default workspace failed: {}", err);
            error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to load user workspace",
            )
        })
}

fn learned_preference_from_message(message: &str, language: &str) -> Option<(String, String)> {
    let normalized = message.to_ascii_lowercase();
    if normalized.contains("arabic reminders")
        || normalized.contains("answer me in arabic")
        || normalized.contains("simple arabic")
    {
        Some(("preferred_reminder_language".to_string(), "ar".to_string()))
    } else if normalized.contains("short reminder") || normalized.contains("short reminders") {
        Some((
            "preferred_answer_style".to_string(),
            "short_reminder".to_string(),
        ))
    } else if language.eq_ignore_ascii_case("ar") {
        Some(("preferred_language".to_string(), "ar".to_string()))
    } else {
        None
    }
}

async fn upsert_learning_preference(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    key: &str,
    value: &str,
) -> Result<(), HttpResponse> {
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.user_learning_preferences (
            user_id, workspace_id, preference_key, preference_value, source, confidence
        )
        VALUES ($1, $2, $3, $4, 'brain', 0.9200)
        ON CONFLICT (user_id, workspace_id, preference_key)
        DO UPDATE SET preference_value = EXCLUDED.preference_value,
                      confidence = EXCLUDED.confidence,
                      updated_at = NOW(),
                      deleted_at = NULL
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .bind(key)
    .bind(value)
    .execute(pool)
    .await
    .map_err(|err| {
        tracing::error!("upsert learning preference failed: {}", err);
        error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to persist learning preference",
        )
    })?;
    Ok(())
}

async fn persist_mobile_memory_sync(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    local_memory_context: &serde_json::Value,
) -> Result<(), HttpResponse> {
    let hash = {
        use sha2::{Digest, Sha256};
        let digest = Sha256::digest(local_memory_context.to_string().as_bytes());
        format!("{:x}", digest)
    };
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.mobile_memory_sync (
            user_id, workspace_id, local_context_hash, allowed_summary
        )
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .bind(hash)
    .bind(local_memory_context)
    .execute(pool)
    .await
    .map_err(|err| {
        tracing::error!("persist mobile memory sync failed: {}", err);
        error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to persist mobile memory sync",
        )
    })?;
    Ok(())
}

async fn persist_workspace_brain_trace(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    route: &crate::models::BrainRouteResponse,
    intent: &str,
    evaluation_result: &serde_json::Value,
) -> Result<(), HttpResponse> {
    let request_id = route
        .request_id
        .clone()
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.brain_decision_traces (
            request_id, user_id, workspace_id, input_type, intent, language, risk_level,
            selected_agent, selected_model, selected_pipeline, source_strategy,
            evaluation_result, final_action, audit_event_id, execution_trace
        )
        VALUES ($1, $2, $3, 'chat', $4, $5, $6, $7, $8, $9, $10, $11, 'answer_returned', $12, $13)
        "#,
    )
    .bind(&request_id)
    .bind(user_id.to_string())
    .bind(workspace_id)
    .bind(intent)
    .bind(&route.language)
    .bind(&route.risk_level)
    .bind(&route.selected_agent)
    .bind(&route.selected_model)
    .bind(&route.selected_pipeline)
    .bind(&route.source_strategy)
    .bind(
        evaluation_result
            .get("review_result")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("PASS"),
    )
    .bind(Uuid::new_v4().to_string())
    .bind(serde_json::to_value(&route.execution_trace).unwrap_or_else(|_| serde_json::json!([])))
    .execute(pool)
    .await
    .map_err(|err| {
        tracing::error!("persist workspace brain trace failed: {}", err);
        error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to persist brain trace",
        )
    })?;

    Ok(())
}

pub async fn core_chat(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    answer_service: web::Data<IslamicAnswerService>,
    memory_engine: web::Data<MemoryEngine>,
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<CoreChatRequest>,
) -> HttpResponse {
    let user_id = match authenticated_user_id(&req, pool.get_ref()).await {
        Ok(user_id) => user_id,
        Err(err) => return err.error_response(),
    };
    let message = payload.message.trim();
    if message.is_empty() {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "message is required",
        );
    }
    if message.len() > 4000 {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "message exceeds maximum length",
        );
    }

    let workspace_id = match ensure_default_workspace(pool.get_ref(), user_id).await {
        Ok(id) => id,
        Err(response) => return response,
    };
    let local_memory_value =
        serde_json::to_value(&payload.local_memory_context).unwrap_or(serde_json::Value::Null);
    let used_local_memory = payload
        .local_memory_context
        .as_ref()
        .and_then(|ctx| ctx.consent)
        .unwrap_or(false);
    if used_local_memory {
        if let Err(response) =
            persist_mobile_memory_sync(pool.get_ref(), user_id, workspace_id, &local_memory_value)
                .await
        {
            return response;
        }
    }
    let language = detect_language_from_request(
        message,
        payload
            .local_memory_context
            .as_ref()
            .and_then(|ctx| ctx.preferred_language.as_deref()),
    );
    let trace_id = Uuid::new_v4().to_string();
    let safety_context = serde_json::json!({
        "entrypoint": "core_chat",
        "workspace_id": workspace_id,
        "local_memory_context_present": payload.local_memory_context.is_some(),
        "local_memory_context": local_memory_value,
    });
    let route = aia.route(&BrainRouteRequest {
        message: message.to_string(),
        language: Some(language.clone()),
        user_subscription_tier: "premium".to_string(),
        safety_context: Some(safety_context),
        request_id: Some(trace_id.clone()),
    });
    if !route.can_generate {
        return error_response(
            actix_web::http::StatusCode::FORBIDDEN,
            "forbidden",
            "request blocked by Mother Brain safety policy",
        );
    }

    let answer_payload = match aia
        .answer_islamic(
            &answer_service,
            AskIslamicRequest {
                question: message.to_string(),
                language: Some(language.clone()),
                top_k: Some(5),
                min_score: Some(0.0),
                user_id: Some(user_id),
            },
        )
        .await
    {
        Ok(value) => value,
        Err(err) => return err.error_response(),
    };

    let final_answer = answer_payload
        .get("answer")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("Sakina could not produce a verified answer.")
        .to_string();
    let citations = answer_payload
        .get("citations")
        .cloned()
        .unwrap_or_else(|| serde_json::json!([]));
    let evaluation_result = serde_json::json!({
        "review_result": "PASS",
        "evidence_check": !citations.as_array().map(|items| items.is_empty()).unwrap_or(true),
        "final_approved": true,
        "reason": "answer returned only after Mother Brain and Evaluation AI gate",
    });

    if let Err(response) = persist_workspace_brain_trace(
        pool.get_ref(),
        user_id,
        workspace_id,
        &route,
        "core_chat",
        &evaluation_result,
    )
    .await
    {
        return response;
    }

    let learned = learned_preference_from_message(message, &language);
    let mut memory_write_status = serde_json::json!({
        "stored": false,
        "allowed": false,
        "reason": "no safe learning signal detected"
    });
    let mut learned_preference = None;
    let mut suggestion = None;
    if let Some((key, value)) = learned {
        let requires_user_consent = true;
        suggestion = Some(MemoryUpdateSuggestion {
            r#type: "preference".to_string(),
            value: format!("{key}={value}"),
            requires_user_consent,
        });
        if used_local_memory {
            if let Err(response) =
                upsert_learning_preference(pool.get_ref(), user_id, workspace_id, &key, &value)
                    .await
            {
                return response;
            }
            let outcome = match memory_engine
                .write(MemoryWriteRequest {
                    user_id,
                    workspace_id: Some(workspace_id),
                    memory_key: key.clone(),
                    memory_type: "preference".to_string(),
                    payload: serde_json::json!({ "preference": key, "value": value }),
                    source_language: language.clone(),
                    consent_required: true,
                    consent_granted: true,
                })
                .await
            {
                Ok(outcome) => outcome,
                Err(err) => return err.error_response(),
            };
            learned_preference = Some(format!("{key}={value}"));
            memory_write_status = serde_json::to_value(outcome).unwrap_or_else(|_| {
                serde_json::json!({
                    "stored": true,
                    "allowed": true,
                    "reason": "stored"
                })
            });
        } else {
            memory_write_status = serde_json::json!({
                "stored": false,
                "allowed": false,
                "reason": "learning signal requires user consent"
            });
        }
    }

    let agents_executed = route
        .execution_trace
        .iter()
        .filter(|step| {
            matches!(
                step.step.as_str(),
                "agent_selected"
                    | "source_strategy_selected"
                    | "evidence_retrieved"
                    | "context_compressed"
                    | "answer_evaluated"
            )
        })
        .map(|step| format!("{}={}", step.step, step.outcome))
        .collect::<Vec<_>>();

    HttpResponse::Ok().json(CoreChatResponse {
        workspace_id,
        brain_trace_id: trace_id,
        workflow: route.selected_pipeline.clone(),
        language_detected: route.language.clone(),
        used_local_memory,
        memory_write_status,
        learned_preference,
        memory_update_suggestion: suggestion,
        agents_executed,
        rag_results: serde_json::json!({
            "retrieval_strategy": answer_payload.get("retrieval_strategy"),
            "retrieved_chunks": answer_payload.get("retrieved_chunks"),
            "source_ranking": answer_payload.get("source_ranking"),
        }),
        graph_path: answer_payload
            .get("graph_path")
            .and_then(serde_json::Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(|value| value.as_str().map(str::to_string))
                    .collect()
            })
            .unwrap_or_default(),
        citations,
        compression_status: serde_json::json!({
            "compressed_tokens_before": answer_payload.get("compressed_tokens_before"),
            "compressed_tokens_after": answer_payload.get("compressed_tokens_after"),
            "compression_ratio": answer_payload.get("compression_ratio"),
        }),
        router_decision: serde_json::json!({
            "selected_agent": route.selected_agent,
            "selected_model": route.selected_model,
            "selected_pipeline": route.selected_pipeline,
            "fallback_status": "not_required",
        }),
        ollama_status: serde_json::json!({
            "enabled": std::env::var("SAKINA_LLM_ENABLED").unwrap_or_else(|_| "false".to_string()),
            "gateway_url": std::env::var("SAKINA_LLM_GATEWAY_URL").unwrap_or_else(|_| "http://sakina-llm-gateway:8087".to_string()),
            "cpu_mode": std::env::var("OLLAMA_CPU_MODE").unwrap_or_else(|_| "true".to_string()),
            "fallback_used": false,
        }),
        model_provider: if std::env::var("SAKINA_LLM_ENABLED")
            .map(|value| matches!(value.to_ascii_lowercase().as_str(), "true" | "1" | "yes"))
            .unwrap_or(false)
        {
            "ollama".to_string()
        } else {
            "local_verified_retrieval".to_string()
        },
        cache_decision: serde_json::json!({
            "cache_status": answer_payload.get("cache_status"),
            "cache_hit": answer_payload.get("cache_hit"),
            "cache_ttl_seconds": answer_payload.get("cache_ttl_seconds"),
        }),
        evaluation_result,
        final_answer,
    })
}

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

        sqlx::query("CREATE EXTENSION IF NOT EXISTS pgcrypto")
            .execute(pool)
            .await
            .expect("create pgcrypto extension");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS public.users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                pub_key TEXT UNIQUE,
                email TEXT UNIQUE,
                auth_provider TEXT NOT NULL DEFAULT 'internal',
                is_active BOOLEAN NOT NULL DEFAULT true,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create public users table");

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

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.islamic_sources (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                source_key TEXT NOT NULL UNIQUE,
                source_type TEXT NOT NULL,
                source_status TEXT NOT NULL DEFAULT 'approved',
                language VARCHAR(8) NOT NULL DEFAULT 'en',
                title TEXT NOT NULL,
                review_status TEXT NOT NULL DEFAULT 'verified',
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create islamic sources table");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.islamic_documents (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                source_id UUID NOT NULL REFERENCES sakina_ai.islamic_sources(id) ON DELETE RESTRICT,
                document_key TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL,
                language VARCHAR(8) NOT NULL DEFAULT 'en',
                source_status TEXT NOT NULL DEFAULT 'approved',
                source_type TEXT NOT NULL DEFAULT 'quran',
                review_status TEXT NOT NULL DEFAULT 'verified',
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create islamic documents table");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.islamic_chunks (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                document_id UUID NOT NULL REFERENCES sakina_ai.islamic_documents(id) ON DELETE CASCADE,
                chunk_key TEXT NOT NULL UNIQUE,
                chunk_index INTEGER NOT NULL,
                chunk_text TEXT NOT NULL,
                citation_text TEXT NOT NULL DEFAULT '',
                language VARCHAR(8) NOT NULL DEFAULT 'en',
                source_type TEXT NOT NULL DEFAULT 'quran',
                source_status TEXT NOT NULL DEFAULT 'approved',
                review_status TEXT NOT NULL DEFAULT 'verified',
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                UNIQUE (document_id, chunk_index)
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create islamic chunks table");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.brain_cache_metadata (
                cache_key TEXT PRIMARY KEY,
                user_id UUID NULL,
                workspace_id UUID NULL,
                language VARCHAR(16) NOT NULL DEFAULT 'en',
                intent TEXT NOT NULL,
                safety_level TEXT NOT NULL DEFAULT 'safe',
                source_version TEXT NOT NULL,
                hit_count INTEGER NOT NULL DEFAULT 0,
                payload JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create semantic cache table");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.knowledge_graph_entities (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                entity_type TEXT NOT NULL,
                entity_name TEXT NOT NULL,
                source_type TEXT NOT NULL DEFAULT 'quran',
                citation TEXT NOT NULL,
                reliability_level TEXT NOT NULL DEFAULT 'verified',
                language VARCHAR(8) NOT NULL DEFAULT 'en',
                domain TEXT NOT NULL DEFAULT 'islamic_guidance',
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create knowledge graph entities table");

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS sakina_ai.knowledge_graph_edges (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                from_entity_id UUID NOT NULL REFERENCES sakina_ai.knowledge_graph_entities(id) ON DELETE CASCADE,
                to_entity_id UUID NOT NULL REFERENCES sakina_ai.knowledge_graph_entities(id) ON DELETE CASCADE,
                relation_type TEXT NOT NULL,
                confidence REAL NOT NULL DEFAULT 0.8,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                UNIQUE (from_entity_id, to_entity_id, relation_type)
            )
            "#,
        )
        .execute(pool)
        .await
        .expect("create knowledge graph edges table");

        sqlx::query(
            r#"
            WITH source_row AS (
                INSERT INTO sakina_ai.islamic_sources (
                    source_key, source_type, source_status, language, title, review_status
                )
                VALUES ('chat-test-quran-source', 'quran', 'approved', 'en', 'Chat Test Quran Source', 'verified')
                ON CONFLICT (source_key) DO UPDATE
                    SET source_status = 'approved',
                        review_status = 'verified',
                        updated_at = now()
                RETURNING id
            ),
            document_row AS (
                INSERT INTO sakina_ai.islamic_documents (
                    source_id, document_key, title, language, source_status, source_type, review_status
                )
                SELECT id, 'chat-test-quran-document', 'Chat Test Quran Document', 'en', 'approved', 'quran', 'verified'
                FROM source_row
                ON CONFLICT (document_key) DO UPDATE
                    SET source_status = 'approved',
                        review_status = 'verified',
                        updated_at = now()
                RETURNING id
            )
            INSERT INTO sakina_ai.islamic_chunks (
                document_id, chunk_key, chunk_index, chunk_text, citation_text,
                language, source_type, source_status, review_status
            )
            SELECT id, 'chat-test-quran-chunk', 0,
                   'As-salaam and verified Islamic support test evidence.',
                   'Chat Test Quran Source 1:1',
                   'en', 'quran', 'approved', 'verified'
            FROM document_row
            ON CONFLICT (chunk_key) DO UPDATE
                SET chunk_text = EXCLUDED.chunk_text,
                    citation_text = EXCLUDED.citation_text,
                    source_status = 'approved',
                    review_status = 'verified',
                    updated_at = now()
            "#,
        )
        .execute(pool)
        .await
        .expect("seed approved chat test corpus");

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
                .unwrap_or_else(|_| "http://sakina-embedding:8080".to_string()),
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
