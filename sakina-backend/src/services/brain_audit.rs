use std::sync::Arc;
use std::sync::Mutex;

use crate::models::{BrainAuditRecord, BrainDecisionTrace};
use sqlx::PgPool;

#[derive(Debug, Clone)]
pub struct BrainAuditLog {
    records: Arc<Mutex<Vec<BrainAuditRecord>>>,
    pool: Option<PgPool>,
}

impl Default for BrainAuditLog {
    fn default() -> Self {
        Self {
            records: Arc::new(Mutex::new(Vec::new())),
            pool: None,
        }
    }
}

impl BrainAuditLog {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_pool(pool: PgPool) -> Self {
        Self {
            records: Arc::new(Mutex::new(Vec::new())),
            pool: Some(pool),
        }
    }

    pub fn append(&self, record: BrainAuditRecord) {
        tracing::info!(
            event = "brain_decision",
            request_id = %record.request_id,
            user_id = ?record.user_id,
            selected_agent = %record.selected_agent,
            selected_model = %record.selected_model,
            final_action = %record.final_action,
            "Brain decision logged"
        );

        if let Ok(mut guard) = self.records.lock() {
            guard.push(record.clone());
        }
    }

    pub fn record_trace(&self, trace: &BrainDecisionTrace) {
        if let Some(pool) = self.pool.clone() {
            let trace = trace.clone();
            if let Ok(handle) = tokio::runtime::Handle::try_current() {
                handle.spawn(async move {
                    let _ = sqlx::query(
                        r#"
                        INSERT INTO sakina_ai.brain_decision_traces (
                            request_id,
                            user_id,
                            input_type,
                            intent,
                            language,
                            risk_level,
                            selected_agent,
                            selected_model,
                            selected_pipeline,
                            source_strategy,
                            evaluation_result,
                            final_action,
                            audit_event_id,
                            execution_trace
                        )
                        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
                        ON CONFLICT DO NOTHING
                        "#,
                    )
                    .bind(&trace.request_id)
                    .bind(&trace.user_id)
                    .bind(&trace.input_type)
                    .bind(&trace.intent)
                    .bind(&trace.language)
                    .bind(&trace.risk_level)
                    .bind(&trace.selected_agent)
                    .bind(&trace.selected_model)
                    .bind(&trace.selected_pipeline)
                    .bind(&trace.source_strategy)
                    .bind(&trace.evaluation_result)
                    .bind(&trace.final_action)
                    .bind(&trace.audit_event_id)
                    .bind(
                        serde_json::to_value(&trace.execution_trace)
                            .unwrap_or_else(|_| serde_json::json!([])),
                    )
                    .execute(&pool)
                    .await;
                });
            }
        }
    }

    pub fn records(&self) -> Vec<BrainAuditRecord> {
        self.records
            .lock()
            .map(|guard| guard.clone())
            .unwrap_or_default()
    }
}
