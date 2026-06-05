#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

fail() {
  printf 'AGENTIC_LEARNING_GATE_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd rg

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

rg -n "AgenticOrchestrator|SakinaState|AgentNode|p99_budget_is_enforced" \
  sakina-backend/src/agent \
  > reports/final-hardening-evidence/915-agentic-learning-code-paths.txt

rg -n "validate_output|block_prompt_injection|block_secret_or_credential_leak" \
  wasm/src/lib.rs \
  > reports/final-hardening-evidence/916-wasm-validator-code-paths.txt

cargo test --manifest-path sakina-backend/Cargo.toml agent:: -- --nocapture \
  > reports/final-hardening-evidence/917-agentic-learning-backend-tests.txt 2>&1

cargo test --manifest-path sakina-backend/Cargo.toml --test agent_integration_tests -- --nocapture \
  > reports/final-hardening-evidence/921-agent-integration-tests.txt 2>&1

bash scripts/sakina/agent-feedback-export-proof.sh \
  > reports/final-hardening-evidence/923-agent-feedback-export-proof.txt 2>&1

cargo test --manifest-path wasm/Cargo.toml -- --nocapture \
  > reports/final-hardening-evidence/918-wasm-validator-tests.txt 2>&1

if rustup target list --installed | grep -Fx wasm32-unknown-unknown >/dev/null; then
  cargo build --manifest-path wasm/Cargo.toml --target wasm32-unknown-unknown --release \
    > reports/final-hardening-evidence/919-wasm-validator-build.txt 2>&1
  test -s wasm/target/wasm32-unknown-unknown/release/sakina_validator.wasm \
    || fail "compiled wasm artifact missing after wasm32 build"
else
  printf 'wasm32-unknown-unknown target is not installed; native validator tests passed but wasm artifact build is blocked.\n' \
    > reports/final-hardening-evidence/919-wasm-validator-build.txt
  fail "wasm32-unknown-unknown target is not installed"
fi

printf 'AGENTIC_LEARNING_GATE_OK backend agentic router tests, Redis integration, feedback export, deterministic validator tests, and wasm artifact build completed.\n'
