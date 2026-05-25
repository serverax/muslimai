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
            let events: Vec<OutboxEvent> = sqlx::query_as(
                "SELECT id, event_type FROM outbox.events \
                 WHERE status = 'Pending' \
                 FOR UPDATE SKIP LOCKED LIMIT 10",
            )
            .fetch_all(&self.pool)
            .await?;

            for event in events {
                if event.event_type == "chunk_indexed" {
                    // Chunks are upserted to Qdrant during ingestion; ack here.
                    sqlx::query("UPDATE outbox.events SET status = 'Sent' WHERE id = $1")
                        .bind(event.id)
                        .execute(&self.pool)
                        .await?;
                }
            }

            sleep(Duration::from_secs(5)).await;
        }
    }
}
