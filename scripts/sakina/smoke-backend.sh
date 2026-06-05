#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${SAKINA_BACKEND_BASE_URL:-}"
if [[ -z "$BASE_URL" ]]; then
  echo "SAKINA_BACKEND_BASE_URL is required" >&2
  exit 1
fi

curl -fsS "$BASE_URL/health" >/dev/null
curl -fsS "$BASE_URL/api/v1/modules" >/dev/null

echo "backend smoke completed with HTTP assertions."
