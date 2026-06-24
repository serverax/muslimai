CREATE SCHEMA IF NOT EXISTS sakina_ai;

CREATE TABLE IF NOT EXISTS sakina_ai.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    preferred_language TEXT,
    platform TEXT,
    message TEXT,
    source TEXT NOT NULL DEFAULT '7jzi.com',
    status TEXT NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sakina_waitlist_status_created_at
    ON sakina_ai.waitlist (status, created_at DESC);
