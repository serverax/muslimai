BEGIN;
CREATE TABLE IF NOT EXISTS user_module_progress (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  completion_percent INT NOT NULL DEFAULT 0 CHECK (completion_percent BETWEEN 0 AND 100),
  last_lesson_id UUID NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(user_id, module_id)
);
COMMIT;
