#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Scanning for direct frontend/mobile calls to internal services ==="

grep -R "ollama\|rag-retrieval\|rag-ingestion\|llm-gateway\|postgres\|qdrant\|redis\|sakina-backend\|ollama-inference" -n . \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.next \
  --exclude="*.lock" || true

echo
echo "Review the above. Frontend/mobile must call only sakina-api-gateway."
