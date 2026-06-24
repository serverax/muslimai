#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'REDIS_VALKEY_CACHE_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

if [[ -z "${SAKINA_REDIS_URL:-}" && -z "${REDIS_URL:-}" && -z "${VALKEY_URL:-}" ]]; then
  fail "no Sakina-owned Redis/Valkey URL is configured; semantic Postgres cache is not accepted as Redis/Valkey proof"
fi

cache_url="${SAKINA_REDIS_URL:-${VALKEY_URL:-${REDIS_URL:-}}}"
case "$cache_url" in
  *lawapp*|*6379*)
    if docker ps --format '{{.Names}} {{.Ports}}' | grep -E 'lawapp-redis.*6379' >/dev/null 2>&1; then
      fail "configured Redis/Valkey appears to target the unrelated lawapp Redis runtime"
    fi
    ;;
esac

redis_cmd() {
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli -u "$cache_url" "$@"
    return
  fi
  if docker ps --format '{{.Names}}' | grep -q '^sakina-infra-redis-1$'; then
    docker exec sakina-infra-redis-1 redis-cli "$@"
    return
  fi
  fail "redis-cli is missing and no Sakina Redis container is available for docker exec proof"
}

redis_cmd PING | grep -q '^PONG$' \
  || fail "Redis/Valkey did not respond to PING"

probe_key="sakina:cache-proof:$(date +%s):$RANDOM"
redis_cmd SET "$probe_key" "sakina-cache-proof" EX 30 >/dev/null \
  || fail "could not write proof key to Redis/Valkey"
redis_cmd GET "$probe_key" | grep -q '^sakina-cache-proof$' \
  || fail "could not read proof key from Redis/Valkey"
redis_cmd DEL "$probe_key" >/dev/null \
  || fail "could not delete proof key from Redis/Valkey"

if ! rg -n "Redis|Valkey|REDIS_URL|SAKINA_REDIS_URL|VALKEY_URL" sakina-backend/src sakina-backend/Cargo.toml infra .github >/tmp/sakina-redis-code-path.txt; then
  fail "backend/infra code does not show Redis/Valkey integration"
fi
cat /tmp/sakina-redis-code-path.txt

printf 'REDIS_VALKEY_CACHE_OK live Sakina Redis/Valkey runtime responded and code references integration.\n'
