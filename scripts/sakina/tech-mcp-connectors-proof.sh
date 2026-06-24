#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MCP_CONNECTORS_BLOCKER %s\n' "$1" >&2
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

export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"

cargo test --manifest-path sakina-backend/Cargo.toml \
  services::mcp_registry::tests::registry_is_disabled_by_default \
  -- --nocapture

if rg -n "mcp|MCP|connector" sakina-frontend/lib >/tmp/sakina-mcp-frontend-hits.txt; then
  cat /tmp/sakina-mcp-frontend-hits.txt
  fail "MCP connector UI/service is visible in Flutter production code while connectors are disabled"
fi

if rg -n "route\\(.*mcp|scope\\(.*mcp|McpConnectorRegistry.*call|\\.call\\(" sakina-backend/src/main.rs sakina-backend/src/handlers >/tmp/sakina-mcp-route-hits.txt; then
  cat /tmp/sakina-mcp-route-hits.txt
  fail "direct MCP connector route/call is exposed outside Brain-gated implementation"
fi

rg -n "SAKINA_MCP_ENABLED|endpoint.is_some|failing closed|connector disabled by configuration|registry_is_disabled_by_default" \
  sakina-backend/src/services/mcp_registry.rs >/tmp/sakina-mcp-code-path.txt \
  || fail "MCP registry does not show disabled-by-default and fail-closed behavior"
cat /tmp/sakina-mcp-code-path.txt

printf 'MCP_CONNECTORS_OK MCP connectors are hidden and fail closed; not accepted as complete/live.\n'
