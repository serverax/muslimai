-- PHASE 6I: local admin owner seed marker (actual seed runs in migrate.rs when SAKINA_SEED_LOCAL_ADMIN=true).
-- Keeps migration numbering stable; no production effect unless env flag set in migrate runner.
BEGIN;
-- no-op
COMMIT;
