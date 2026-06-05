use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MemoryWriteRequest {
    pub user_id: Uuid,
    pub memory_key: String,
    pub memory_type: String,
    pub payload: Value,
    pub source_language: String,
    pub consent_required: bool,
    pub consent_granted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MemoryWriteOutcome {
    pub stored: bool,
    pub allowed: bool,
    pub sensitivity_level: String,
    pub reason: String,
    pub memory_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MemoryEntry {
    pub id: Uuid,
    pub user_id: Uuid,
    pub memory_key: String,
    pub memory_type: String,
    pub sensitivity_level: String,
    pub payload: Value,
    pub source_language: String,
    pub consent_required: bool,
    pub consent_granted: bool,
    pub allowed: bool,
}

#[derive(Debug, Clone)]
pub struct MemoryEngine {
    pool: PgPool,
    key_material: Vec<u8>,
}

impl MemoryEngine {
    pub fn new(pool: PgPool) -> Self {
        let key_material = std::env::var("SAKINA_MEMORY_KEY")
            .unwrap_or_else(|_| "sakina-dev-memory-key".to_string())
            .into_bytes();
        Self { pool, key_material }
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }

    pub fn classify_sensitivity(payload: &Value) -> String {
        let text = payload.to_string().to_ascii_lowercase();
        if [
            "suicide",
            "self harm",
            "kill myself",
            "abuse",
            "diagnosis",
            "medical",
            "legal",
            "bank account",
            "credit card",
            "passport",
        ]
        .iter()
        .any(|needle| text.contains(needle))
        {
            "high".to_string()
        } else if [
            "sad",
            "anxious",
            "trauma",
            "family",
            "marriage",
            "memorisation",
            "quran",
        ]
        .iter()
        .any(|needle| text.contains(needle))
        {
            "sensitive".to_string()
        } else {
            "safe".to_string()
        }
    }

    pub fn preview_write(payload: &Value, consent_granted: bool) -> MemoryWriteOutcome {
        let sensitivity_level = Self::classify_sensitivity(payload);
        let sensitive = matches!(sensitivity_level.as_str(), "high" | "sensitive");
        let allowed = !sensitive || consent_granted;
        let reason = if allowed {
            "memory write allowed"
        } else {
            "high-risk memory requires user consent and was not written"
        };
        MemoryWriteOutcome {
            stored: allowed,
            allowed,
            sensitivity_level,
            reason: reason.to_string(),
            memory_id: None,
        }
    }

    fn derive_stream(&self, nonce: &[u8], len: usize) -> Vec<u8> {
        let mut stream = Vec::with_capacity(len);
        let mut counter = 0u64;
        while stream.len() < len {
            let mut hasher = Sha256::new();
            hasher.update(&self.key_material);
            hasher.update(nonce);
            hasher.update(counter.to_le_bytes());
            stream.extend_from_slice(&hasher.finalize());
            counter += 1;
        }
        stream.truncate(len);
        stream
    }

    fn encrypt(&self, plaintext: &str) -> (Vec<u8>, Vec<u8>) {
        let nonce = *Uuid::new_v4().as_bytes();
        let stream = self.derive_stream(&nonce, plaintext.len());
        let encrypted = plaintext
            .as_bytes()
            .iter()
            .zip(stream.iter())
            .map(|(a, b)| a ^ b)
            .collect::<Vec<u8>>();
        (encrypted, nonce.to_vec())
    }

    fn decrypt(&self, encrypted: &[u8], nonce: &[u8]) -> Result<String, ApiError> {
        let stream = self.derive_stream(nonce, encrypted.len());
        let plaintext = encrypted
            .iter()
            .zip(stream.iter())
            .map(|(a, b)| a ^ b)
            .collect::<Vec<u8>>();
        String::from_utf8(plaintext).map_err(|_| ApiError::internal("failed to decrypt memory"))
    }

    async fn append_audit(
        &self,
        user_id: Option<Uuid>,
        action: &str,
        sensitivity_level: &str,
        allowed: bool,
        payload: &Value,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO sakina_ai.brain_memory_events (
                user_id, action, sensitivity_level, allowed, payload
            )
            VALUES ($1, $2, $3, $4, $5)
            "#,
        )
        .bind(user_id)
        .bind(action)
        .bind(sensitivity_level)
        .bind(allowed)
        .bind(payload)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn write(&self, request: MemoryWriteRequest) -> Result<MemoryWriteOutcome, ApiError> {
        let preview = Self::preview_write(&request.payload, request.consent_granted);
        let sensitivity_level = preview.sensitivity_level.clone();
        let allowed = preview.allowed;
        let reason = preview.reason.clone();
        self.append_audit(
            Some(request.user_id),
            "write",
            &sensitivity_level,
            allowed,
            &request.payload,
        )
        .await
        .map_err(|_| ApiError::internal("failed to record memory audit"))?;

        if !allowed {
            return Ok(preview);
        }

        let plaintext = serde_json::to_string(&request.payload)
            .map_err(|_| ApiError::internal("failed to serialize memory payload"))?;
        let (encrypted_payload, nonce) = self.encrypt(&plaintext);
        let row = sqlx::query(
            r#"
            INSERT INTO sakina_ai.user_memory_entries (
                user_id, memory_key, memory_type, sensitivity_level, encrypted_payload,
                nonce, consent_required, consent_granted, allowed, source_language, metadata
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(&request.memory_key)
        .bind(&request.memory_type)
        .bind(&sensitivity_level)
        .bind(encrypted_payload)
        .bind(nonce)
        .bind(request.consent_required)
        .bind(request.consent_granted)
        .bind(allowed)
        .bind(&request.source_language)
        .bind(serde_json::json!({
            "written_by": "mother_brain",
            "sensitivity_level": sensitivity_level,
        }))
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to persist memory entry"))?;

        Ok(MemoryWriteOutcome {
            stored: true,
            allowed,
            sensitivity_level,
            reason,
            memory_id: Some(row.get("id")),
        })
    }

    pub async fn read(
        &self,
        user_id: Uuid,
        memory_key: &str,
    ) -> Result<Option<MemoryEntry>, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT id, user_id, memory_key, memory_type, sensitivity_level, encrypted_payload,
                   nonce, source_language, consent_required, consent_granted, allowed
            FROM sakina_ai.user_memory_entries
            WHERE user_id = $1
              AND memory_key = $2
            ORDER BY created_at DESC
            LIMIT 1
            "#,
        )
        .bind(user_id)
        .bind(memory_key)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load memory entry"))?;

        let Some(row) = row else {
            self.append_audit(
                Some(user_id),
                "read_miss",
                "safe",
                false,
                &serde_json::json!({
                    "memory_key": memory_key
                }),
            )
            .await
            .map_err(|_| ApiError::internal("failed to record memory audit"))?;
            return Ok(None);
        };

        let encrypted_payload: Vec<u8> = row.get("encrypted_payload");
        let nonce: Vec<u8> = row.get("nonce");
        let payload = serde_json::from_str::<Value>(&self.decrypt(&encrypted_payload, &nonce)?)
            .unwrap_or_else(|_| serde_json::json!({}));

        self.append_audit(
            Some(user_id),
            "read",
            row.get("sensitivity_level"),
            row.get("allowed"),
            &payload,
        )
        .await
        .map_err(|_| ApiError::internal("failed to record memory audit"))?;

        Ok(Some(MemoryEntry {
            id: row.get("id"),
            user_id: row.get("user_id"),
            memory_key: row.get("memory_key"),
            memory_type: row.get("memory_type"),
            sensitivity_level: row.get("sensitivity_level"),
            payload,
            source_language: row.get("source_language"),
            consent_required: row.get("consent_required"),
            consent_granted: row.get("consent_granted"),
            allowed: row.get("allowed"),
        }))
    }

    pub async fn delete(&self, user_id: Uuid, memory_key: &str) -> Result<u64, ApiError> {
        let result = sqlx::query(
            r#"
            DELETE FROM sakina_ai.user_memory_entries
            WHERE user_id = $1
              AND memory_key = $2
            "#,
        )
        .bind(user_id)
        .bind(memory_key)
        .execute(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to delete memory entry"))?;

        self.append_audit(
            Some(user_id),
            "delete",
            "safe",
            true,
            &serde_json::json!({ "memory_key": memory_key }),
        )
        .await
        .map_err(|_| ApiError::internal("failed to record memory audit"))?;

        Ok(result.rows_affected())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sensitive_payload_is_classified_as_high_risk() {
        let payload = serde_json::json!({"note": "suicide risk and medical diagnosis"});
        assert_eq!(MemoryEngine::classify_sensitivity(&payload), "high");
    }

    #[test]
    fn sensitive_payload_is_not_written_without_consent() {
        let payload = serde_json::json!({"note": "suicide risk and medical diagnosis"});
        let preview = MemoryEngine::preview_write(&payload, false);
        assert!(!preview.allowed);
        assert!(!preview.stored);
        assert!(preview.reason.contains("not written"));
    }
}
