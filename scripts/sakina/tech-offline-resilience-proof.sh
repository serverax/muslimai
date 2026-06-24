#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'OFFLINE_RESILIENCE_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd rg

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

if command -v flutter >/dev/null 2>&1; then
  (
    cd sakina-frontend
    flutter test test/offline_resilience_test.dart test/local_db_test.dart
  )
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command \
    "Set-Location -LiteralPath 'F:\\SakinaAL\\sakina-frontend'; flutter test test/offline_resilience_test.dart test/local_db_test.dart"
else
  fail "Flutter is not available in PATH and Windows PowerShell fallback is unavailable"
fi

rg -n "ChatSyncStatus|pendingMessages|retryPending|serviceUnavailable|historyStore|_markPending|_replaceMessage" \
  sakina-frontend/lib/chat/chat_controller.dart sakina-frontend/test/offline_resilience_test.dart \
  >/tmp/sakina-offline-chat-code-path.txt \
  || fail "offline chat queue/retry code path was not found"
cat /tmp/sakina-offline-chat-code-path.txt

rg -n "sync_status|ConflictAlgorithm\\.replace|ALTER TABLE messages ADD COLUMN sync_status|sqflite_sqlcipher" \
  sakina-frontend/lib/services/local_db_service.dart sakina-frontend/test/local_db_test.dart \
  >/tmp/sakina-offline-local-db-code-path.txt \
  || fail "durable encrypted local pending-sync storage code path was not found"
cat /tmp/sakina-offline-local-db-code-path.txt

rg -n "timeout\\(|_withRetry|ApiException|serviceUnavailable|Network unavailable|retryAttempts|retryDelay" \
  sakina-frontend/lib/services/api_service.dart sakina-frontend/lib/config/api_config.dart sakina-frontend/lib/app/app_strings.dart sakina-frontend/lib/chat/chat_controller.dart \
  >/tmp/sakina-offline-network-error-code-path.txt \
  || fail "network timeout/retry/error user state code path was not found"
cat /tmp/sakina-offline-network-error-code-path.txt

if rg -n "offline.*answer|fake.*offline|mock.*offline|return '.*offline.*answer|Source-backed answer" \
  sakina-frontend/lib; then
  fail "production frontend contains offline fake-answer behavior"
fi

if rg -n "fake.*offline|mock.*offline|fabricated.*offline|placeholder.*offline" \
  sakina-backend/src; then
  fail "production code contains offline fake-answer behavior"
fi

printf 'OFFLINE_RESILIENCE_OK frontend queues backend-unavailable chat messages as pending, does not fabricate assistant answers, persists pending state in encrypted local DB, retries pending messages when backend becomes available, maps network errors to user-visible state, and production code has no fake offline answer path.\n'
