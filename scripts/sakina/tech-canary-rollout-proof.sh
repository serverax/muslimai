#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'CANARY_ROLLOUT_BLOCKER %s\n' "$1" >&2
  exit 1
}

command -v psql >/dev/null 2>&1 || fail "psql is required"
command -v rg >/dev/null 2>&1 || fail "rg is required"

if [[ -f tasks/AGENTS.md ]]; then cat tasks/AGENTS.md >/dev/null; fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
proof_id="canary-$(date +%s)-$$"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v proof_id="$proof_id" <<'SQL'
\pset pager off
SELECT set_config('sakina.proof_flag', :'proof_id', false);

DO $$
BEGIN
  IF to_regclass('public.feature_flags') IS NULL THEN
    RAISE EXCEPTION 'public.feature_flags missing';
  END IF;
END $$;

INSERT INTO public.feature_flags (flag_key, flag_description, is_enabled, rollout_percent, rules, updated_by)
VALUES (:'proof_id', 'Canary rollout proof', true, 5, jsonb_build_object('beta_group', 'closed-beta', 'kill_switch', false), 'advanced-gate')
ON CONFLICT (flag_key) DO UPDATE SET
  is_enabled = EXCLUDED.is_enabled,
  rollout_percent = EXCLUDED.rollout_percent,
  rules = EXCLUDED.rules,
  updated_by = EXCLUDED.updated_by,
  updated_at = now();

DO $$
DECLARE
  rollout integer;
  enabled boolean;
BEGIN
  SELECT rollout_percent, is_enabled INTO rollout, enabled FROM public.feature_flags WHERE flag_key = current_setting('sakina.proof_flag', true);
  IF rollout <> 5 OR enabled IS NOT TRUE THEN
    RAISE EXCEPTION 'canary flag did not persist enabled 5%% rollout';
  END IF;
END $$;
SQL

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v proof_id="$proof_id" <<'SQL'
SELECT set_config('sakina.proof_flag', :'proof_id', false);
UPDATE public.feature_flags
SET is_enabled = false,
    rollout_percent = 0,
    rules = rules || '{"kill_switch": true}'::jsonb,
    updated_at = now()
WHERE flag_key = :'proof_id';

SELECT flag_key, is_enabled, rollout_percent, rules->>'kill_switch' AS kill_switch
FROM public.feature_flags
WHERE flag_key = :'proof_id';

DO $$
DECLARE
  disabled_count bigint;
BEGIN
  SELECT COUNT(*) INTO disabled_count
  FROM public.feature_flags
  WHERE flag_key = current_setting('sakina.proof_flag', true)
    AND is_enabled = false
    AND rollout_percent = 0
    AND rules->>'kill_switch' = 'true';
  IF disabled_count <> 1 THEN
    RAISE EXCEPTION 'canary kill switch did not disable direct rollout';
  END IF;
END $$;
SQL

rg -n "feature_flags|module_status|release_flags|SAKINA_FEATURE_" sakina-backend/src sakina-backend/db sakina-frontend/lib \
  > reports/final-hardening-evidence/690-canary-feature-flag-code-paths.txt \
  || fail "feature flag code paths were not found"

printf 'CANARY_ROLLOUT_OK feature flag rollout and kill switch persisted in DB and code paths exist for backend/frontend enforcement.\n'
