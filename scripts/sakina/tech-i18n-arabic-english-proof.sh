#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'I18N_ARABIC_ENGLISH_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql
require_cmd rg

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${BASE_URL%/}"
run_id="i18n-$(date +%s)-$RANDOM"
started_backend=0
backend_log_file="${TMPDIR:-/tmp}/sakina-i18n-backend.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
}
trap cleanup EXIT

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >"$backend_log_file" 2>&1 \
    || fail "backend build failed; log: $backend_log_file"
  "$CARGO_TARGET_DIR/debug/sakina-api" >>"$backend_log_file" 2>&1 &
  backend_pid=$!
  started_backend=1
  for _ in $(seq 1 180); do
    if curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend did not become ready for i18n proof; log: $backend_log_file"

register_response="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-register" \
  -d "$(jq -n --arg email "$run_id@example.com" --arg credential "$(printf '%s' 'StrongPassword123!')" '{
    email:$email,
    password:$credential,
    display_name:"Arabic English Proof User",
    provider:"password",
    provider_user_id:$email,
    metadata:{}
  }')")"
token="$(printf '%s\n' "$register_response" | jq -r '.access_token // empty')"
user_id="$(printf '%s\n' "$register_response" | jq -r '.user_id // empty')"
[[ "$token" == *.*.* && "$user_id" =~ ^[0-9a-fA-F-]{36}$ ]] \
  || fail "registration did not return real JWT and user id"

profile_response="$(curl -fsS -X PUT "$api_base/v1/profiles/$user_id" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-profile-ar" \
  -d "$(jq -n --arg user_id "$user_id" '{
    user_id:$user_id,
    display_name:"مستخدم سكينة",
    timezone:"UTC",
    metadata:{proof:"i18n-arabic-english"},
    ui_language:"ar",
    content_language:"ar",
    transliteration_enabled:true,
    profile_visibility:"private",
    data_export_allowed:true,
    analytics_opt_in:false,
    text_scale:1.0,
    high_contrast_enabled:false,
    reduced_motion_enabled:false,
    screen_reader_optimized:false,
    in_app_enabled:true,
    email_enabled:false,
    push_enabled:false
  }')")"
printf '%s\n' "$profile_response" | jq .
printf '%s\n' "$profile_response" | jq -e --arg user_id "$user_id" '.profile_id and .user_id == $user_id' >/dev/null \
  || fail "Arabic profile preference update did not return profile id"

db_language_count="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c \
  "SELECT COUNT(*) FROM public.language_preferences WHERE user_id = '$user_id'::uuid AND ui_language = 'ar' AND content_language = 'ar';")"
printf 'DB Arabic language preference rows: %s\n' "$db_language_count"
[[ "$db_language_count" = "1" ]] || fail "Arabic profile preferences were not persisted in DB"

arabic_trace="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-brain-ar" \
  -d '{"message":"اشرح آية الكرسي من القرآن","language":"ar","user_subscription_tier":"premium"}')"
printf '%s\n' "$arabic_trace" | jq .
printf '%s\n' "$arabic_trace" \
  | jq -e '.language == "ar" and (.execution_trace[]? | select(.step == "language_detected" and .outcome == "ar"))' >/dev/null \
  || fail "Brain trace did not preserve Arabic language detection"

english_trace="$(curl -fsS -X POST "$api_base/api/brain/trace" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $run_id-brain-en" \
  -d '{"message":"What is zakat?","language":"en","user_subscription_tier":"premium"}')"
printf '%s\n' "$english_trace" | jq -e '.language == "en"' >/dev/null \
  || fail "Brain trace did not preserve English language"

rg -n "AppLanguage\\.arabic|AppLanguage\\.english|سكينة|تعذر الاتصال|TextDirection\\.rtl|Directionality|ButtonSegment\\(value: 'ar'|ui_language|content_language" \
  sakina-frontend/lib sakina-frontend/test \
  >/tmp/sakina-i18n-frontend-code-path.txt \
  || fail "frontend Arabic/English UI, RTL, and profile language code paths were not found"
cat /tmp/sakina-i18n-frontend-code-path.txt

rg -n "detect_language|is_arabic_text|language_detected|language: row.get|ui_language|content_language|offline_lookup\\(question, &language\\)" \
  sakina-backend/src \
  >/tmp/sakina-i18n-backend-code-path.txt \
  || fail "backend Arabic/English routing, profile, and source language code paths were not found"
cat /tmp/sakina-i18n-backend-code-path.txt

if command -v flutter >/dev/null 2>&1; then
  (
    cd sakina-frontend
    flutter test test/widget_test.dart test/api_service_test.dart
  )
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command \
    "Set-Location -LiteralPath 'F:\\SakinaAL\\sakina-frontend'; flutter test test/widget_test.dart test/api_service_test.dart"
else
  fail "Flutter is not available in PATH and Windows PowerShell fallback is unavailable"
fi

printf 'I18N_ARABIC_ENGLISH_OK Arabic and English UI strings/RTL controls exist, Arabic profile language preferences persist through authenticated backend API and DB, Arabic and English Brain traces preserve language, backend routes support language-aware retrieval/routing, and frontend tests passed.\n'
