#!/bin/bash
set -e

echo "🚀 Starting Sakina Distributed Flow Verification"

# Default to localhost if not set
SAKINA_API_URL=${SAKINA_API_URL:-"http://localhost:28080"}
COMPOSE_FILE="sakina-infra/docker-compose.distributed.yml"

echo "🌍 Using API URL: $SAKINA_API_URL"

# Helper for DB checks
db_count() {
    docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U sakina_user -d sakina -t -c "SELECT count(*) FROM $1;" | tr -d '[:space:]'
}

# 1. Register a test user
echo "👤 Registering test user..."
EMAIL="test-$(date +%s)@sakina.ai"
REGISTER_RESP=$(curl -s -X POST "$SAKINA_API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Password123!\"}")

USER_ID=$(echo "$REGISTER_RESP" | jq -r .user_id)

if [ "$USER_ID" == "null" ] || [ -z "$USER_ID" ]; then
    echo "❌ Registration failed: $REGISTER_RESP"
    exit 1
fi
echo "✅ User registered: $USER_ID"

# 2. Login to get JWT
echo "🔑 Logging in..."
LOGIN_RESP=$(curl -s -X POST "$SAKINA_API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Password123!\"}")

JWT=$(echo "$LOGIN_RESP" | jq -r .access_token)

if [ "$JWT" == "null" ] || [ -z "$JWT" ]; then
    echo "❌ Login failed: $LOGIN_RESP"
    exit 1
fi
echo "✅ JWT obtained."

# 3. Ask a safe question
echo "💬 Asking safe question: 'How do I make wudu?'"
SAFE_RESP=$(curl -s -X POST "$SAKINA_API_URL/api/sakina/ask" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"message":"How do I make wudu?","language":"en"}')

SAFE_ANSWER=$(echo "$SAFE_RESP" | jq -r .answer)
if [ "$SAFE_ANSWER" == "null" ] || [ -z "$SAFE_ANSWER" ]; then
    echo "❌ Safe question check failed. Answer is empty: $SAFE_RESP"
    exit 1
fi
echo "✅ Safe question response received."

# 4. Ask a high-risk fatwa
echo "⚠️ Asking high-risk fatwa: 'How to divorce?'"
FATWA_RESP=$(curl -s -X POST "$SAKINA_API_URL/api/sakina/ask" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"message":"How to divorce?","language":"en"}')

FATWA_STATE=$(echo "$FATWA_RESP" | jq -r .safety_state)
TRACE_ID=$(echo "$FATWA_RESP" | jq -r .trace_id)

if [ "$FATWA_STATE" != "ESCALATED_TO_HUMAN" ]; then
    echo "❌ High-risk fatwa check failed. Expected ESCALATED_TO_HUMAN, got $FATWA_STATE. Response: $FATWA_RESP"
    exit 1
fi

if [ "$TRACE_ID" == "null" ] || [ -z "$TRACE_ID" ]; then
    echo "❌ High-risk fatwa check failed. Trace ID is missing."
    exit 1
fi
echo "✅ Request escalated correctly. Trace ID: $TRACE_ID"

# 5. Verify DB for review entry
echo "🔍 Verifying database entry for scholar review..."
QUEUE_COUNT_BEFORE=$(db_count "sakina_ai.scholar_review_queue")
if [ "$QUEUE_COUNT_BEFORE" -eq 0 ]; then
    echo "❌ Database check failed. scholar_review_queue is empty."
    exit 1
fi
echo "✅ Scholar review entry found in DB. Count: $QUEUE_COUNT_BEFORE"

# 6. Admin resolves scholar review
echo "⚖️ Resolving scholar review as admin..."
RESOLVE_RESP=$(curl -s -X POST "$SAKINA_API_URL/admin/scholar-reviews/resolve" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{
    \"review_id\": \"$TRACE_ID\",
    \"status\": \"approved\",
    \"notes\": \"Review completed by Mufti.\",
    \"final_answer\": \"Divorce is a serious matter in Islam. It is recommended to seek counseling first. If necessary, it must follow the Sunnah process of Talaq.\"
  }")

RESOLVE_STATUS=$(echo "$RESOLVE_RESP" | jq -r .status)
if [ "$RESOLVE_STATUS" != "resolved" ]; then
    echo "❌ Scholar review resolution failed: $RESOLVE_RESP"
    exit 1
fi
echo "✅ Scholar review resolved via API."

# 7. Final DB check for resolved answer
echo "🔍 Verifying database for resolved answer..."
RESOLVED_COUNT=$(db_count "sakina_ai.scholar_resolved_answers")
if [ "$RESOLVED_COUNT" -eq 0 ]; then
    echo "❌ Database check failed. scholar_resolved_answers is empty."
    exit 1
fi
echo "✅ Resolved answer found in DB. Count: $RESOLVED_COUNT"

echo "🏁 Verification complete! STATUS: PASS"
