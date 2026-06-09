#!/usr/bin/env bash
set -euo pipefail

# Sakina Ask AI Shaikh End-to-End Distributed Proof Script
# This script simulates the distributed flow by calling the backend API.

API_URL="${SAKINA_API_URL:-http://localhost:8080}"
JWT_TOKEN="${SAKINA_JWT_TOKEN:-}"

if [ -z "$JWT_TOKEN" ]; then
    echo "FAIL: SAKINA_JWT_TOKEN is not set"
    exit 1
fi

echo "=== Proving Ask AI Shaikh Distributed Flow ==="

# 1. Ask about Wudu (Local Topic)
echo "Step 1: Asking about Wudu (Local Topic)..."
curl -sS -X POST "$API_URL/api/sakina/ask" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"message": "How do I make wudu?", "section": "ask_sakina"}' | jq .

# 2. Ask about Fasting (RAG Topic)
echo -e "\nStep 2: Asking about Fasting (RAG Topic)..."
curl -sS -X POST "$API_URL/api/sakina/ask" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"message": "What is the virtue of fasting Ramadan?", "section": "ask_sakina"}' | jq .

# 3. Trigger Out of Scope
echo -e "\nStep 3: Triggering Out of Scope..."
curl -sS -X POST "$API_URL/api/sakina/ask" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"message": "Write Python hacking code", "section": "ask_sakina"}' | jq .

echo -e "\n=== Proof Complete ==="
