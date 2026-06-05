#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

export DATABASE_URL="${DATABASE_URL:-postgres://sakina_user:sakina_password@localhost:5434/sakina}"
export JWT_SECRET="${JWT_SECRET:-sakina-local-jwt-secret-minimum-32-bytes-value}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-sakina-local-encryption-key-minimum-32-byte}"
export QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
export SAKINA_REDIS_URL="${SAKINA_REDIS_URL:-redis://localhost:6380}"
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

log_file="${TMPDIR:-/tmp}/sakina-api-auth.log"
rm -f "$log_file"

cargo run --manifest-path sakina-backend/Cargo.toml --bin sakina-api >"$log_file" 2>&1 &
pid=$!
cleanup() {
  set +e
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
}
trap cleanup EXIT

for _ in $(seq 1 240); do
  if curl -fsS http://localhost:8080/health/ready >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -fsS http://localhost:8080/health/ready >/dev/null

email="sakina-proof-$(date +%s)-$RANDOM@example.com"
credential="StrongPassword123!"

echo "=== register ==="
register_json="$(curl -fsS -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$email\",\"password\":\"$credential\",\"display_name\":\"User A\"}")"
echo "$register_json" | jq '{user_id,email,has_access_token:(.access_token != null), has_refresh_token:(.refresh_token != null)}'

echo "=== login ==="
login_json="$(curl -fsS -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$email\",\"password\":\"$credential\"}")"
echo "$login_json" | jq '{user_id,email,access_token_format:(.access_token|test("^[^.]+[.][^.]+[.][^.]+$")), has_refresh_token:(.refresh_token != null)}'
access_jwt="$(echo "$login_json" | jq -r '.access_token')"
user_id="$(echo "$login_json" | jq -r '.user_id')"

echo "=== wrong password ==="
wrong_status="$(curl -sS -o /tmp/sakina-wrong-password.json -w "%{http_code}" -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$email\",\"password\":\"WrongPassword123!\"}")"
echo "status=$wrong_status"
cat /tmp/sakina-wrong-password.json | jq .
test "$wrong_status" = "401"

echo "=== auth me ==="
curl -fsS http://localhost:8080/auth/me -H "Authorization: Bearer $access_jwt" | jq '{user_id,email}'

echo "=== protected route without token ==="
no_token_status="$(curl -sS -o /tmp/sakina-no-token.json -w "%{http_code}" http://localhost:8080/auth/me)"
echo "status=$no_token_status"
cat /tmp/sakina-no-token.json | jq .
test "$no_token_status" = "401"

echo "=== logout ==="
curl -fsS -X POST http://localhost:8080/auth/logout -H "Authorization: Bearer $access_jwt" | jq .

echo "=== revoked token rejected ==="
revoked_status="$(curl -sS -o /tmp/sakina-revoked-token.json -w "%{http_code}" http://localhost:8080/auth/me -H "Authorization: Bearer $access_jwt")"
echo "status=$revoked_status"
cat /tmp/sakina-revoked-token.json | jq .
test "$revoked_status" = "401"

echo "=== password hash proof ==="
docker exec -e PGPASSWORD=sakina_password sakina-postgres-dev \
  psql -U sakina_user -d sakina -c \
  "SELECT u.email, left(pc.password_hash, 10) AS hash_prefix, pc.password_version, pc.password_hash <> '$credential' AS not_plaintext FROM public.users u JOIN public.password_credentials pc ON pc.user_id = u.id WHERE u.id = '$user_id';"
