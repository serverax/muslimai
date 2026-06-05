#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MULTIMODAL_LIVE_E2E_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd cargo
require_cmd curl
require_cmd jq
require_cmd psql
require_cmd python3

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
export SAKINA_FEATURE_QURAN=true
export SAKINA_RAG_QURAN_ENABLED=true
export SAKINA_LLM_ENABLED="${SAKINA_LLM_ENABLED:-false}"
export SAKINA_MULTIMODAL_PROVIDER="${SAKINA_MULTIMODAL_PROVIDER:-local_tesseract_ocr}"
export SAKINA_MULTIMODAL_STORAGE_DIR="${SAKINA_MULTIMODAL_STORAGE_DIR:-/tmp/sakina-private-multimodal-proof}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/sakina-cargo-target}"
export ALLOW_DEMO_MODE=false
export ALLOW_MOCK_AI=false
export ALLOW_MOCK_RAG=false
export ALLOW_MOCK_AUTH=false
export ALLOW_MOCK_PAYMENTS=false
export ALLOW_FAKE_CI_PASS=false

BASE_URL="${SAKINA_API_BASE_URL:-http://localhost:8080}"
api_base="${BASE_URL%/}"
started_backend=0
started_embeddings=0
backend_log="${TMPDIR:-/tmp}/sakina-multimodal-live-api.log"
embedding_log="${TMPDIR:-/tmp}/sakina-multimodal-live-embeddings.log"

ensure_tesseract_runtime() {
  if command -v tesseract >/dev/null 2>&1; then
    return 0
  fi
  require_cmd docker
  docker build -f sakina-backend/Dockerfile.api -t sakina-backend-api:multimodal-ocr-proof . \
    > reports/final-hardening-evidence/410-multimodal-ocr-docker-build.txt 2>&1 \
    || fail "Docker image with Tesseract OCR runtime did not build: reports/final-hardening-evidence/410-multimodal-ocr-docker-build.txt"
  local wrapper_dir="${TMPDIR:-/tmp}/sakina-ocr-runtime-bin"
  mkdir -p "$wrapper_dir"
  cat > "$wrapper_dir/tesseract" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
input="$1"
shift
dir="$(dirname "$input")"
base="$(basename "$input")"
docker run --rm -v "$dir:/work:ro" sakina-backend-api:multimodal-ocr-proof \
  tesseract "/work/$base" "$@"
WRAPPER
  chmod +x "$wrapper_dir/tesseract"
  export PATH="$wrapper_dir:$PATH"
  command -v tesseract >/dev/null 2>&1 \
    || fail "Tesseract OCR runtime wrapper was not added to PATH"
}

cleanup() {
  set +e
  if [[ "${started_embeddings}" = "1" ]]; then
    kill "$embedding_pid" 2>/dev/null
    wait "$embedding_pid" 2>/dev/null
  fi
  if [[ "${started_backend}" = "1" ]]; then
    kill "$backend_pid" 2>/dev/null
    wait "$backend_pid" 2>/dev/null
  fi
  set -e
}
trap cleanup EXIT

wait_url() {
  local url="$1"
  for _ in $(seq 1 120); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if ! curl -fsS "$VLLM_URL/v1/models" >/dev/null 2>&1; then
  python3 scripts/sakina/local_feature_hash_embedding_provider.py >"$embedding_log" 2>&1 &
  embedding_pid=$!
  started_embeddings=1
  wait_url "$VLLM_URL/v1/models" || fail "embedding provider did not start; log: $embedding_log"
fi

python3 scripts/sakina/index-approved-rag-corpus.py

if [[ "$SAKINA_MULTIMODAL_PROVIDER" = "local_tesseract_ocr" ]]; then
  ensure_tesseract_runtime
fi

if ! curl -fsS "$api_base/health/ready" >/dev/null 2>&1; then
  cargo build --manifest-path sakina-backend/Cargo.toml --bin sakina-api >>"$backend_log" 2>&1
  "$CARGO_TARGET_DIR/debug/sakina-api" >"$backend_log" 2>&1 &
  backend_pid=$!
  started_backend=1
  wait_url "$api_base/health/ready" || fail "backend did not become ready; log: $backend_log"
fi

curl -fsS "$api_base/health/ready" | jq -e '.status == "ready"' >/dev/null \
  || fail "backend readiness did not report ready"

suffix="$(date +%s)-$RANDOM"
credential="StrongPassword123!"
register="$(curl -fsS -X POST "$api_base/auth/register" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg email "sakina-mm-live-$suffix@example.com" --arg credential "$credential" '{email:$email,password:$credential,display_name:"Multimodal Live User"}')")"
access_jwt="$(printf '%s\n' "$register" | jq -r '.access_token')"
user_id="$(printf '%s\n' "$register" | jq -r '.user_id')"
[[ "$access_jwt" != "null" && "$user_id" != "null" ]] || fail "registration did not return JWT/user_id"
printf '%s\n' "$register" | jq '{user_id,email,has_access_token:(.access_token != null)}'

doc_file="$(mktemp)"
cat >"$doc_file" <<'DOC'
I found a note asking: Can I shorten prayers while travelling? Please explain using verified Islamic sources.
DOC
trace_doc="mm-doc-$suffix"
doc_response="$(curl -fsS -X POST "$api_base/v1/api/multimodal/analyze" \
  -H "Authorization: Bearer $access_jwt" \
  -H "x-request-id: $trace_doc" \
  -F "asset_type=document" \
  -F "mime_type=text/plain" \
  -F "language=en" \
  -F "file=@$doc_file;filename=travel-prayer-note.txt;type=text/plain")"
printf '%s\n' "$doc_response" | jq .
printf '%s\n' "$doc_response" | jq -e \
  --arg trace "$trace_doc" \
  '.trace_id == $trace and .provider == "local_text_extractor" and (.asset_id | type == "string") and (.islamic_answer.citations | length >= 1) and .islamic_answer.generated_from_verified_sources == true' >/dev/null \
  || fail "text document upload did not return Brain/RAG/citation-backed multimodal answer"
asset_id="$(printf '%s\n' "$doc_response" | jq -r '.asset_id')"

asset_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.multimodal_assets WHERE id = '$asset_id'::uuid AND user_id = '$user_id'::uuid AND metadata->>'trace_id' = '$trace_doc' AND metadata->>'private_path' IS NOT NULL AND (metadata->>'citations_count')::int >= 1;")"
[[ "$asset_probe" = "1" ]] || fail "multimodal asset DB row lacks owner/private-path/trace/citation metadata"

brain_probe="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "SELECT COUNT(*) FROM sakina_ai.brain_decision_traces WHERE request_id = '$trace_doc' AND selected_pipeline LIKE '%rag%' AND execution_trace::text LIKE '%input_received%';")"
printf 'Brain trace rows related to multimodal: %s\n' "$brain_probe"
if (( brain_probe < 1 )); then
  fail "Brain trace did not record multimodal stage"
fi

if [[ "$SAKINA_MULTIMODAL_PROVIDER" = "local_tesseract_ocr" ]]; then
  command -v tesseract >/dev/null 2>&1 \
    || fail "Tesseract OCR runtime is unavailable after Docker-backed runtime setup"
elif [[ -z "${SAKINA_MULTIMODAL_API_KEY:-${OPENAI_API_KEY:-}}" ]]; then
  fail "image/vision proof requires SAKINA_MULTIMODAL_API_KEY or OPENAI_API_KEY; text document path passed but full multimodal image workflow is not proven"
fi

png_file="$(mktemp --suffix=.png)"
python3 - <<'PY' >"$png_file"
import struct
import sys
import zlib

glyphs = {
    " ": ["00000","00000","00000","00000","00000","00000","00000"],
    "A": ["01110","10001","10001","11111","10001","10001","10001"],
    "C": ["01111","10000","10000","10000","10000","10000","01111"],
    "E": ["11111","10000","10000","11110","10000","10000","11111"],
    "H": ["10001","10001","10001","11111","10001","10001","10001"],
    "I": ["11111","00100","00100","00100","00100","00100","11111"],
    "L": ["10000","10000","10000","10000","10000","10000","11111"],
    "N": ["10001","11001","10101","10011","10001","10001","10001"],
    "O": ["01110","10001","10001","10001","10001","10001","01110"],
    "P": ["11110","10001","10001","11110","10000","10000","10000"],
    "R": ["11110","10001","10001","11110","10100","10010","10001"],
    "S": ["01111","10000","10000","01110","00001","00001","11110"],
    "T": ["11111","00100","00100","00100","00100","00100","00100"],
    "V": ["10001","10001","10001","10001","10001","01010","00100"],
    "W": ["10001","10001","10001","10101","10101","10101","01010"],
    "Y": ["10001","10001","01010","00100","00100","00100","00100"],
}

text = "TRAVEL PRAYER"
scale = 10
margin = 24
width = margin * 2 + sum((5 + 1) * scale for _ in text)
height = margin * 2 + 7 * scale
pixels = bytearray([255] * (width * height))
cursor = margin
for ch in text:
    glyph = glyphs[ch]
    for gy, row in enumerate(glyph):
        for gx, bit in enumerate(row):
            if bit == "1":
                for sy in range(scale):
                    for sx in range(scale):
                        x = cursor + gx * scale + sx
                        y = margin + gy * scale + sy
                        pixels[y * width + x] = 0
    cursor += 6 * scale

raw = bytearray()
for y in range(height):
    raw.append(0)
    raw.extend(pixels[y * width:(y + 1) * width])

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

sys.stdout.buffer.write(b"\x89PNG\r\n\x1a\n")
sys.stdout.buffer.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)))
sys.stdout.buffer.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
sys.stdout.buffer.write(chunk(b"IEND", b""))
PY
trace_img="mm-image-$suffix"
image_response="$(curl -fsS -X POST "$api_base/v1/api/multimodal/analyze" \
  -H "Authorization: Bearer $access_jwt" \
  -H "x-request-id: $trace_img" \
  -F "asset_type=image" \
  -F "mime_type=image/png" \
  -F "language=en" \
  -F "file=@$png_file;filename=proof-image.png;type=image/png")"
printf '%s\n' "$image_response" | jq .
printf '%s\n' "$image_response" | jq -e \
  --arg trace "$trace_img" \
  --arg provider "$SAKINA_MULTIMODAL_PROVIDER" \
  '.trace_id == $trace and .provider == $provider and (.asset_id | type == "string") and (.extracted_text | length > 0) and (.islamic_answer.answer | type == "string")' >/dev/null \
  || fail "image upload did not use live OCR/vision provider and Brain response"

printf 'MULTIMODAL_LIVE_E2E_OK document and image multimodal workflow proved with real backend, DB, Brain/RAG, and provider.\n'
