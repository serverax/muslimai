use crate::error::ApiError;
use actix_web::{http::header, web, HttpResponse};
use sqlx::PgPool;

pub async fn metrics(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let users = scalar_count(
        pool.get_ref(),
        "SELECT COUNT(*) FROM public.users",
        "sakina_users_total",
    )
    .await?;
    let chunks = scalar_count(
        pool.get_ref(),
        "SELECT COUNT(*) FROM verified_knowledge.chunks",
        "sakina_verified_chunks_total",
    )
    .await?;
    let guardrails = scalar_count(
        pool.get_ref(),
        "SELECT COUNT(*) FROM audit.logs WHERE event_type = 'guardrail_triggered'",
        "sakina_guardrail_triggers_total",
    )
    .await?;
    let backups = scalar_count(
        pool.get_ref(),
        "SELECT COUNT(*) FROM public.user_backups",
        "sakina_user_backups_total",
    )
    .await?;

    let body = format!(
        "# HELP sakina_users_total Total persisted Sakina users\n\
         # TYPE sakina_users_total gauge\n\
         sakina_users_total {users}\n\
         # HELP sakina_verified_chunks_total Total verified knowledge chunks\n\
         # TYPE sakina_verified_chunks_total gauge\n\
         sakina_verified_chunks_total {chunks}\n\
         # HELP sakina_guardrail_triggers_total Total persisted guardrail trigger events\n\
         # TYPE sakina_guardrail_triggers_total counter\n\
         sakina_guardrail_triggers_total {guardrails}\n\
         # HELP sakina_user_backups_total Total encrypted user backup records\n\
         # TYPE sakina_user_backups_total gauge\n\
         sakina_user_backups_total {backups}\n"
    );

    Ok(HttpResponse::Ok()
        .insert_header((header::CONTENT_TYPE, "text/plain; version=0.0.4"))
        .body(body))
}

async fn scalar_count(pool: &PgPool, sql: &str, metric: &str) -> Result<i64, ApiError> {
    sqlx::query_scalar::<_, i64>(sql)
        .fetch_one(pool)
        .await
        .map_err(|e| {
            tracing::error!("metrics query failed for {metric}: {e}");
            ApiError::internal("failed to gather metrics")
        })
}
