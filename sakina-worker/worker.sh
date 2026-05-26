#!/usr/bin/env sh
set -eu

echo "SakinaAI worker started"
echo "Redis: ${REDIS_HOST:-sakinaai-redis}:${REDIS_PORT:-6379}"
echo "AI gateway: ${AI_GATEWAY_URL:-unset}"

while true; do
  sleep 300
done
