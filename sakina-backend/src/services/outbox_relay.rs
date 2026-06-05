//! Outbox relay (Phase 2, Step 8): drains pending `outbox.events` and marks them
//! Sent. Runs as a background tokio task spawned from `main`.
//!
//! `SELECT ... FOR UPDATE SKIP LOCKED` so multiple API replicas don't
//! double-process the same event.

use sqlx::PgPool;
use tokio::time::{sleep, Duration};
use uuid::Uuid;

pub struct OutboxRelay {
    pool: PgPool,
}

impl OutboxRelay {
    pub fn new(pool: PgPool) -> Self {
        OutboxRelay { pool }
    }

    /// Poll the outbox forever, marking handled events as Sent. Returns only on
    /// a database error (the caller logs it and the task ends).
    pub async fn relay_events(&self) -> Result<(), Box<dyn std::error::Error>> {
        loop {
            let events: Vec<(Uuid, String, i32, i32)> = sqlx::query_as(
                "SELECT id, event_type, COALESCE(retry_count, 0), COALESCE(max_retries, 5) \
                 FROM outbox.events \
                 WHERE status = 'Pending' \
                 ORDER BY created_at \
                 FOR UPDATE SKIP LOCKED LIMIT 25",
            )
            .fetch_all(&self.pool)
            .await?;

            for (event_id, event_type, retry_count, max_retries) in events {
                if matches!(
                    event_type.as_str(),
                    "chunk_indexed"
                        | "user_data_deleted"
                        | "backup_disaster_recovery_verified"
                        | "human_review_created"
                        | "notification_created"
                ) {
                    sqlx::query(
                        "UPDATE outbox.events \
                         SET status = 'Sent', updated_at = now() \
                         WHERE id = $1",
                    )
                    .bind(event_id)
                    .execute(&self.pool)
                    .await?;
                    tracing::info!(event = "outbox_event_sent", %event_id, %event_type);
                } else {
                    let next_retry = retry_count + 1;
                    if next_retry >= max_retries {
                        sqlx::query(
                            "UPDATE outbox.events \
                             SET status = 'DeadLetter', retry_count = $2, updated_at = now() \
                             WHERE id = $1",
                        )
                        .bind(event_id)
                        .bind(next_retry)
                        .execute(&self.pool)
                        .await?;
                        sqlx::query(
                            "INSERT INTO outbox.dead_letters (event_id, error_message) \
                             VALUES ($1, $2)",
                        )
                        .bind(event_id)
                        .bind(format!("unsupported outbox event type: {event_type}"))
                        .execute(&self.pool)
                        .await?;
                        tracing::warn!(event = "outbox_event_dead_lettered", %event_id, %event_type);
                    } else {
                        sqlx::query(
                            "UPDATE outbox.events \
                             SET retry_count = $2, updated_at = now() \
                             WHERE id = $1",
                        )
                        .bind(event_id)
                        .bind(next_retry)
                        .execute(&self.pool)
                        .await?;
                        tracing::warn!(event = "outbox_event_retry_scheduled", %event_id, %event_type, retry_count = next_retry);
                    }
                }
            }

            sleep(Duration::from_secs(5)).await;
        }
    }
}
