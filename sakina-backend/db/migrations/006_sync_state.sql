BEGIN;
CREATE TABLE IF NOT EXISTS sync_state (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_sync_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  client_version TEXT NOT NULL DEFAULT 'unknown',
  sync_token TEXT NOT NULL DEFAULT ''
);
COMMIT;
