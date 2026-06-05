#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

run_step() {
  local name="$1"
  shift
  local evidence="reports/final-hardening-evidence/${name}.txt"
  printf 'Running %s\n' "$name"
  "$@" > "$evidence" 2>&1
}

run_step 190-backend-tests-with-db env DATABASE_URL=postgres://sakina_user:sakina_password@localhost:5434/sakina cargo test --manifest-path sakina-backend/Cargo.toml --all --all-features -- --nocapture --test-threads=1
run_step 190-auth-live-proof bash scripts/sakina/auth-live-proof.sh

if [[ ! -f scripts/sakina/auth-refresh-proof.sh ]]; then
  printf 'CLOSED_BETA_GATE_BLOCKER missing required proof script: scripts/sakina/auth-refresh-proof.sh\n' >&2
  printf 'Missing required refresh proof script.\n' > reports/final-hardening-evidence/190-auth-refresh-proof.txt
  exit 1
fi
run_step 190-auth-refresh-proof bash scripts/sakina/auth-refresh-proof.sh

run_step 190-db-user-isolation bash scripts/sakina/db-user-isolation-proof.sh
run_step 190-local-runtime bash scripts/sakina/local-runtime-proof.sh
run_step 190-final-wiring bash scripts/sakina/final-wiring-gate.sh
run_step 190-final-new-technologies bash scripts/sakina/final-new-technologies-gate.sh

if [[ ! -f scripts/sakina/store-readiness-proof.sh ]]; then
  printf 'CLOSED_BETA_GATE_BLOCKER missing required proof script: scripts/sakina/store-readiness-proof.sh\n' >&2
  printf 'Missing required store readiness proof script.\n' > reports/final-hardening-evidence/190-store-readiness-proof.txt
  exit 1
fi
run_step 190-store-readiness bash scripts/sakina/store-readiness-proof.sh

printf 'CLOSED_BETA_GATE_OK all closed-beta subchecks exited successfully.\n'
