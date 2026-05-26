//! Outbox relay (Phase 2, Step 8): drains pending `outbox.events` and marks them
//! Sent. Runs as a background tokio task spawned from `main`.
//!
//! `SELECT ... FOR UPDATE SKIP LOCKED` so multiple API replicas don't
//! double-process the same event.

use sqlx::PgPool;
use tokio::time::{sleep, Duration};
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow)]
struct OutboxEvent {
    id: Uuid,
    event_type: String,
    retry_count: i32,
    max_retries: i32,
}

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
            self.relay_once().await?;
            sleep(Duration::from_secs(5)).await;
        }
    }

    /// Drain one batch. Kept public so CI can exercise relay behavior without
    /// spawning a forever task.
    pub async fn relay_once(&self) -> Result<usize, Box<dyn std::error::Error>> {
        let mut tx = self.pool.begin().await?;
        let events: Vec<OutboxEvent> = sqlx::query_as(
            "SELECT id, event_type, retry_count, max_retries \
             FROM outbox.events \
             WHERE status = 'Pending' \
             ORDER BY created_at ASC \
             FOR UPDATE SKIP LOCKED LIMIT 10",
        )
        .fetch_all(&mut *tx)
        .await?;

        let count = events.len();
        for event in events {
            let result = handle_event(&event).await;
            match result {
                Ok(()) => {
                    sqlx::query(
                        "UPDATE outbox.events \
                         SET status = 'Sent', updated_at = NOW() \
                         WHERE id = $1",
                    )
                    .bind(event.id)
                    .execute(&mut *tx)
                    .await?;
                }
                Err(message) => {
                    let next_retry = event.retry_count + 1;
                    if next_retry >= event.max_retries {
                        sqlx::query(
                            "UPDATE outbox.events \
                             SET status = 'DeadLetter', retry_count = $2, updated_at = NOW() \
                             WHERE id = $1",
                        )
                        .bind(event.id)
                        .bind(next_retry)
                        .execute(&mut *tx)
                        .await?;
                        sqlx::query(
                            "INSERT INTO outbox.dead_letters (event_id, error_message) \
                             VALUES ($1, $2)",
                        )
                        .bind(event.id)
                        .bind(message)
                        .execute(&mut *tx)
                        .await?;
                    } else {
                        sqlx::query(
                            "UPDATE outbox.events \
                             SET retry_count = $2, updated_at = NOW() \
                             WHERE id = $1",
                        )
                        .bind(event.id)
                        .bind(next_retry)
                        .execute(&mut *tx)
                        .await?;
                    }
                }
            }
        }

        tx.commit().await?;
        Ok(count)
    }
}

async fn handle_event(event: &OutboxEvent) -> Result<(), String> {
    match event.event_type.as_str() {
        // Ingestion indexes vectors synchronously. The outbox remains as an
        // auditable handoff point for future asynchronous indexers.
        "chunk_ingested" | "chunk_indexed" => Ok(()),
        other => Err(format!("unsupported outbox event type: {other}")),
    }
}
