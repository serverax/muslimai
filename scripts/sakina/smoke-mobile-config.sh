#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="sakina-frontend/lib/config/staging_client_config.dart"
API_CONFIG_FILE="sakina-frontend/lib/config/api_config.dart"

[[ -f "$CONFIG_FILE" ]] || { echo "missing $CONFIG_FILE" >&2; exit 1; }
[[ -f "$API_CONFIG_FILE" ]] || { echo "missing $API_CONFIG_FILE" >&2; exit 1; }

grep -q "SAKINA_API_BASE_URL" "$CONFIG_FILE"
grep -q "SAKINA_API_BASE_URL" "$API_CONFIG_FILE"

echo "mobile config smoke passed"
