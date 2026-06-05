use deadpool_redis::{Pool, Runtime};
use redis::AsyncCommands;
use uuid::Uuid;

use super::state::SakinaState;

#[derive(Debug)]
pub enum SakinaMemoryStoreError {
    Pool(deadpool_redis::PoolError),
    Redis(redis::RedisError),
    Serialize(serde_json::Error),
}

impl std::fmt::Display for SakinaMemoryStoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Pool(error) => write!(f, "redis pool error: {error}"),
            Self::Redis(error) => write!(f, "redis command error: {error}"),
            Self::Serialize(error) => write!(f, "agent state serialization error: {error}"),
        }
    }
}

impl std::error::Error for SakinaMemoryStoreError {}

#[derive(Clone, Debug)]
pub struct SakinaMemoryStore {
    pool: Pool,
    ttl_seconds: u64,
}

impl SakinaMemoryStore {
    pub fn from_url(redis_url: &str) -> Result<Self, deadpool_redis::CreatePoolError> {
        let cfg = deadpool_redis::Config::from_url(redis_url);
        let pool = cfg.create_pool(Some(Runtime::Tokio1))?;
        Ok(Self {
            pool,
            ttl_seconds: 86_400,
        })
    }

    pub fn new(pool: Pool) -> Self {
        Self {
            pool,
            ttl_seconds: 86_400,
        }
    }

    pub fn with_ttl(mut self, ttl_seconds: u64) -> Self {
        self.ttl_seconds = ttl_seconds;
        self
    }

    pub fn pool(&self) -> &Pool {
        &self.pool
    }

    pub async fn save_state(
        &self,
        trace_id: Uuid,
        state: &SakinaState,
    ) -> Result<(), SakinaMemoryStoreError> {
        Self::save_state_with_ttl(&self.pool, trace_id, state, self.ttl_seconds).await
    }

    pub async fn get_state(
        &self,
        trace_id: Uuid,
    ) -> Result<Option<SakinaState>, SakinaMemoryStoreError> {
        Self::get_state_from_pool(&self.pool, trace_id).await
    }

    pub async fn save_state_with_ttl(
        pool: &Pool,
        trace_id: Uuid,
        state: &SakinaState,
        ttl_seconds: u64,
    ) -> Result<(), SakinaMemoryStoreError> {
        let mut conn = pool.get().await.map_err(SakinaMemoryStoreError::Pool)?;
        let payload = serde_json::to_string(state).map_err(SakinaMemoryStoreError::Serialize)?;
        let key = Self::key(trace_id);
        conn.set_ex::<_, _, ()>(key, payload, ttl_seconds)
            .await
            .map_err(SakinaMemoryStoreError::Redis)?;
        Ok(())
    }

    pub async fn save_state_to_pool(
        pool: &Pool,
        trace_id: Uuid,
        state: &SakinaState,
    ) -> Result<(), SakinaMemoryStoreError> {
        Self::save_state_with_ttl(pool, trace_id, state, 86_400).await
    }

    pub async fn get_state_from_pool(
        pool: &Pool,
        trace_id: Uuid,
    ) -> Result<Option<SakinaState>, SakinaMemoryStoreError> {
        let mut conn = pool.get().await.map_err(SakinaMemoryStoreError::Pool)?;
        let key = Self::key(trace_id);
        let payload: Option<String> = conn.get(key).await.map_err(SakinaMemoryStoreError::Redis)?;
        match payload {
            Some(value) => serde_json::from_str(&value)
                .map(Some)
                .map_err(SakinaMemoryStoreError::Serialize),
            None => Ok(None),
        }
    }

    fn key(trace_id: Uuid) -> String {
        format!("sakina:agent:state:{trace_id}")
    }
}
