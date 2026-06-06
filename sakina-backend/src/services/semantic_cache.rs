use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SemanticCacheEntry {
    pub cache_key: String,
    pub user_id: Option<Uuid>,
    pub workspace_id: Option<Uuid>,
    pub language: String,
    pub intent: String,
    pub safety_level: String,
    pub source_version: String,
    pub hit_count: i32,
    pub payload: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SemanticCacheStats {
    pub enabled: bool,
    pub total_entries: i64,
    pub total_hits: i64,
}

#[derive(Debug, Clone)]
pub struct SemanticCacheService {
    pool: PgPool,
}

impl SemanticCacheService {
    pub const TTL_SECONDS: i64 = 86_400;

    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub fn cache_key(
        language: &str,
        intent: &str,
        safety_level: &str,
        source_version: &str,
        user_context: &str,
    ) -> String {
        let mut hasher = Sha256::new();
        hasher.update(language.trim().to_ascii_lowercase().as_bytes());
        hasher.update(intent.trim().to_ascii_lowercase().as_bytes());
        hasher.update(safety_level.trim().to_ascii_lowercase().as_bytes());
        hasher.update(source_version.trim().to_ascii_lowercase().as_bytes());
        hasher.update(user_context.trim().to_ascii_lowercase().as_bytes());
        format!("{:x}", hasher.finalize())
    }

    pub fn is_cacheable(safety_level: &str, payload: &Value) -> bool {
        if !matches!(safety_level.to_ascii_lowercase().as_str(), "safe" | "low") {
            return false;
        }
        let text = payload.to_string().to_ascii_lowercase();
        ![
            "self harm",
            "suicide",
            "medical",
            "legal",
            "diagnosis",
            "personal trauma",
            "private memory",
        ]
        .iter()
        .any(|needle| text.contains(needle))
    }

    pub async fn source_version(&self) -> Result<String, sqlx::Error> {
        let row = sqlx::query(
            r#"
            SELECT COUNT(*)::text AS chunk_count,
                   md5(COALESCE(string_agg(
                       c.id::text || ':' || c.review_status || ':' || c.source_status || ':' || md5(c.chunk_text),
                       '|' ORDER BY c.id::text
                   ), 'empty')) AS source_hash
            FROM sakina_ai.islamic_chunks c
            JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
            JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
            WHERE c.review_status IN ('verified', 'approved')
              AND c.source_status = 'approved'
              AND d.review_status IN ('verified', 'approved')
              AND d.source_status = 'approved'
              AND s.review_status IN ('verified', 'approved')
              AND s.source_status = 'approved'
            "#,
        )
        .fetch_one(&self.pool)
        .await?;

        let chunk_count: String = row.get("chunk_count");
        let source_hash: String = row.get("source_hash");
        Ok(format!("hybrid-v1:{chunk_count}:{source_hash}"))
    }

    pub async fn lookup(
        &self,
        cache_key: &str,
        user_id: Option<Uuid>,
    ) -> Result<Option<SemanticCacheEntry>, sqlx::Error> {
        let row = sqlx::query(
            r#"
            SELECT cache_key, user_id, workspace_id, language, intent, safety_level, source_version,
                   hit_count, payload
            FROM sakina_ai.brain_cache_metadata
            WHERE cache_key = $1
              AND ($2::uuid IS NULL OR user_id = $2)
              AND updated_at > now() - ($3::text::interval)
            "#,
        )
        .bind(cache_key)
        .bind(user_id)
        .bind(format!("{} seconds", Self::TTL_SECONDS))
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            let cache_key_value: String = row.get("cache_key");
            sqlx::query(
                r#"
                UPDATE sakina_ai.brain_cache_metadata
                SET hit_count = hit_count + 1,
                    updated_at = now()
                WHERE cache_key = $1
                "#,
            )
            .bind(&cache_key_value)
            .execute(&self.pool)
            .await?;

            return Ok(Some(SemanticCacheEntry {
                cache_key: cache_key_value,
                user_id: row.get("user_id"),
                workspace_id: row.get("workspace_id"),
                language: row.get("language"),
                intent: row.get("intent"),
                safety_level: row.get("safety_level"),
                source_version: row.get("source_version"),
                hit_count: row.get("hit_count"),
                payload: row.get("payload"),
            }));
        }

        Ok(None)
    }

    pub async fn upsert(&self, entry: &SemanticCacheEntry) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO sakina_ai.brain_cache_metadata (
                cache_key, user_id, workspace_id, language, intent, safety_level, source_version, hit_count, payload, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, 0), $9, now())
            ON CONFLICT (cache_key)
            DO UPDATE SET
                user_id = EXCLUDED.user_id,
                workspace_id = EXCLUDED.workspace_id,
                language = EXCLUDED.language,
                intent = EXCLUDED.intent,
                safety_level = EXCLUDED.safety_level,
                source_version = EXCLUDED.source_version,
                hit_count = sakina_ai.brain_cache_metadata.hit_count + 1,
                payload = EXCLUDED.payload,
                updated_at = now()
            "#,
        )
        .bind(&entry.cache_key)
        .bind(entry.user_id)
        .bind(entry.workspace_id)
        .bind(&entry.language)
        .bind(&entry.intent)
        .bind(&entry.safety_level)
        .bind(&entry.source_version)
        .bind(entry.hit_count)
        .bind(&entry.payload)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn stats(&self) -> Result<SemanticCacheStats, sqlx::Error> {
        let row = sqlx::query(
            r#"
            SELECT COUNT(*)::bigint AS total_entries,
                   COALESCE(SUM(hit_count), 0)::bigint AS total_hits
            FROM sakina_ai.brain_cache_metadata
            "#,
        )
        .fetch_one(&self.pool)
        .await?;

        Ok(SemanticCacheStats {
            enabled: true,
            total_entries: row.get("total_entries"),
            total_hits: row.get("total_hits"),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cache_key_depends_on_context() {
        let a = SemanticCacheService::cache_key("en", "answer", "safe", "v1", "q1");
        let b = SemanticCacheService::cache_key("en", "answer", "safe", "v1", "q2");
        assert_ne!(a, b);
    }

    #[test]
    fn sensitive_payload_is_not_cacheable() {
        let payload = serde_json::json!({"answer":"medical advice about diagnosis"});
        assert!(!SemanticCacheService::is_cacheable("safe", &payload));
    }
}
