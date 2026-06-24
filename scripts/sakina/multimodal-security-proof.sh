#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MULTIMODAL_SECURITY_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export QDRANT_COLLECTION="${QDRANT_COLLECTION:-sakina_islamic_chunks_en}"
export VLLM_URL="${VLLM_URL:-http://localhost:18080}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export SAKINA_MULTIMODAL_STORAGE_DIR="${SAKINA_MULTIMODAL_STORAGE_DIR:-/tmp/sakina-private-multimodal-proof}"
export SAKINA_MULTIMODAL_MAX_BYTES=1024
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

api_base="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${api_base%/}"
started_backend=0
backend_log="${TMPDIR:-/tmp}/sakina-multimodal-security-api.log"

cleanup() {
  set +e
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  set -e
}
trap cleanup EXIT

wait_ready() {
  for _ in $(seq 1 120); do
    curl -fsS "$api_base/health/ready" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >>"$backend_log" 2>&1
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_ready || fail "backend did not become ready; log: $backend_log"
fi

suffix="$(date +%s)-$RANDOM"
credential="StrongPassword123!"
reg_a="$(curl -fsS -X POST "$api_base/auth/register" -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "sakina-mm-sec-a-$suffix@example.com" --arg credential "$credential" '{email:$email,password:$credential,display_name:"MM Security A"}')")"
reg_b="$(curl -fsS -X POST "$api_base/auth/register" -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "sakina-mm-sec-b-$suffix@example.com" --arg credential "$credential" '{email:$email,password:$credential,display_name:"MM Security B"}')")"
access_jwt_a="$(printf '%s\n' "$reg_a" | jq -r '.access_token')"
user_a="$(printf '%s\n' "$reg_a" | jq -r '.user_id')"
access_jwt_b="$(printf '%s\n' "$reg_b" | jq -r '.access_token')"

payload_file="$(mktemp)"
printf 'Can I shorten prayers while travelling?' >"$payload_file"

missing_jwt_status="$(curl -sS -o /tmp/sakina-mm-sec-nojwt.json -w '%{http_code}' \
  -X POST "$api_base/v1/api/multimodal/analyze" \
  -F "asset_type=document" -F "mime_type=text/plain" -F "language=en" \
  -F "file=@$payload_file;filename=note.txt;type=text/plain")"
printf 'Missing JWT status=%s\n' "$missing_jwt_status"
[[ "$missing_jwt_status" = "401" ]] || fail "upload route accepted missing JWT"

bad_type_status="$(curl -sS -o /tmp/sakina-mm-sec-badtype.json -w '%{http_code}' \
  -X POST "$api_base/v1/api/multimodal/analyze" \
  -H "Authorization: Bearer $access_jwt_a" \
  -F "asset_type=image" -F "mime_type=image/png" -F "language=en" \
  -F "file=@$payload_file;filename=not-image.png;type=image/png")"
printf 'Bad type status=%s\n' "$bad_type_status"
[[ "$bad_type_status" = "400" ]] || fail "mismatched image content was accepted"

oversize_file="$(mktemp)"
python3 - <<'PY' >"$oversize_file"
print("x" * 2048)
PY
oversize_status="$(curl -sS -o /tmp/sakina-mm-sec-oversize.json -w '%{http_code}' \
  -X POST "$api_base/v1/api/multimodal/analyze" \
  -H "Authorization: Bearer $access_jwt_a" \
  -F "asset_type=document" -F "mime_type=text/plain" -F "language=en" \
  -F "file=@$oversize_file;filename=large.txt;type=text/plain")"
printf 'Oversize status=%s\n' "$oversize_status"
[[ "$oversize_status" = "400" ]] || fail "oversized upload was accepted"

asset_id="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -qAt -c "
WITH inserted AS (
INSERT INTO sakina_ai.multimodal_assets (
  user_id, asset_type, original_name, storage_scope, redacted_text,
  extracted_text, safety_level, status, metadata
) VALUES (
  '$user_a'::uuid, 'document', 'owner-proof.txt', 'user',
  'redacted', 'extracted', 'safe', 'analyzed',
  '{\"private_path\":\"/tmp/private-owner-proof\",\"trace_id\":\"security-proof\"}'::jsonb
) RETURNING id
)
SELECT id FROM inserted;
")"
asset_id="$(printf '%s' "$asset_id" | tr -d '\r\n[:space:]')"
[[ "$asset_id" =~ ^[0-9a-fA-F-]{36}$ ]] || fail "seeded multimodal asset id is invalid: $asset_id"
own_status="$(curl -sS -o /tmp/sakina-mm-sec-own.json -w '%{http_code}' \
  "$api_base/v1/api/multimodal/assets/$asset_id" -H "Authorization: Bearer $access_jwt_a")"
cross_status="$(curl -sS -o /tmp/sakina-mm-sec-cross.json -w '%{http_code}' \
  "$api_base/v1/api/multimodal/assets/$asset_id" -H "Authorization: Bearer $access_jwt_b")"
printf 'Own asset status=%s Cross-user status=%s\n' "$own_status" "$cross_status"
[[ "$own_status" = "200" ]] || fail "owner could not read own asset"
[[ "$cross_status" = "404" ]] || fail "user B could read user A asset"

printf 'MULTIMODAL_SECURITY_OK auth, type/size validation, private metadata, and owner isolation proved.\n'
