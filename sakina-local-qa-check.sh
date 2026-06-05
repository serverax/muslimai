#!/usr/bin/env bash
set -u

ROOT="/mnt/f/SakinaAl"

echo "============================================================"
echo "SAKINA AI LOCAL QA CHECK"
echo "============================================================"

cd "$ROOT" || {
  echo "FAILED: Cannot cd to $ROOT"
  exit 1
}

mkdir -p reports/qa/evidence
mkdir -p reports/qa/backend
mkdir -p reports/qa/frontend
mkdir -p reports/qa/security
mkdir -p reports/qa/db
mkdir -p reports/qa/rag
mkdir -p reports/qa/wasm
mkdir -p reports/qa/infra

echo "=== ROOT ===" | tee reports/qa/evidence/root.txt
pwd | tee -a reports/qa/evidence/root.txt
ls | tee -a reports/qa/evidence/root.txt

echo "=== GIT STATUS ===" | tee reports/qa/evidence/git-status.txt
git status --short | tee -a reports/qa/evidence/git-status.txt

echo "=== FILE INVENTORY ==="
find . -type f \
  -not -path "./.git/*" \
  -not -path "./node_modules/*" \
  -not -path "./target/*" \
  -not -path "./build/*" \
  -not -path "./.dart_tool/*" \
  | sort > reports/qa/evidence/file-inventory.txt

echo "=== SECURITY SECRET SCAN ==="
grep -RInE "api[_-]?key|secret|password|passwd|token|jwt|private[_-]?key|BEGIN RSA|BEGIN PRIVATE|DATABASE_URL|OPENAI_API_KEY|ANTHROPIC_API_KEY|STRIPE|PAYPAL|firebase" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=target \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=reports \
  > reports/qa/security/secret-risk-grep.txt || true

gitleaks detect --source . --no-banner --redact \
  > reports/qa/security/gitleaks.txt 2>&1 || true

echo "=== UNSAFE PATTERN SCAN ==="
grep -RInE "TODO|FIXME|stub|placeholder|mock|fake|bypass|disable_auth|allow_all|skip_auth|insecure|unsafe|unwrap\(|expect\(" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=target \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=reports \
  > reports/qa/security/unsafe-patterns.txt || true

echo "=== BACKEND RUST CHECK ==="
if [ -d "sakina-backend" ]; then
  cd sakina-backend || exit 1

  cargo fmt --check > ../reports/qa/backend/cargo-fmt-check.txt 2>&1 || true
  cargo check > ../reports/qa/backend/cargo-check.txt 2>&1 || true
  cargo test > ../reports/qa/backend/cargo-test.txt 2>&1 || true
  cargo audit > ../reports/qa/security/cargo-audit.txt 2>&1 || true

  cd ..
else
  echo "sakina-backend not found" > reports/qa/backend/backend-missing.txt
fi

echo "=== FLUTTER CHECK ==="
find . -name "pubspec.yaml" -print > reports/qa/frontend/pubspec-locations.txt

FIRST_PUBSPEC="$(head -1 reports/qa/frontend/pubspec-locations.txt || true)"

if [ -n "$FIRST_PUBSPEC" ]; then
  FLUTTER_DIR="$(dirname "$FIRST_PUBSPEC")"
  cd "$FLUTTER_DIR" || exit 1

  flutter pub get > "$ROOT/reports/qa/frontend/flutter-pub-get.txt" 2>&1 || true
  flutter analyze > "$ROOT/reports/qa/frontend/flutter-analyze.txt" 2>&1 || true
  flutter test > "$ROOT/reports/qa/frontend/flutter-test.txt" 2>&1 || true

  cd "$ROOT" || exit 1
else
  echo "No pubspec.yaml found" > reports/qa/frontend/flutter-missing.txt
fi

echo "=== DB INVENTORY ==="
find . -type f \( -name "*.sql" -o -path "*db*" -o -path "*migration*" \) \
  -not -path "./.git/*" \
  | sort > reports/qa/db/db-inventory.txt

grep -RInE "quran|ayah|surah|tafsir|hadith|bukhari|muslim|fiqh|fatwa|scholar|madhhab|dua|seerah|zakat|salah|prayer|fasting|hajj|umrah|islamic|authentic|grade|narrator|chain|source|citation" . \
  --include="*.sql" \
  --include="*.rs" \
  --include="*.dart" \
  --include="*.yaml" \
  --include="*.yml" \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=target \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=reports \
  > reports/qa/db/islamic-db-search.txt || true

echo "=== DB ENV STATUS ==="
{
  if [ -n "${DATABASE_URL:-}" ]; then echo "DATABASE_URL=SET"; else echo "DATABASE_URL=MISSING"; fi
  if [ -n "${POSTGRES_USER:-}" ]; then echo "POSTGRES_USER=SET"; else echo "POSTGRES_USER=MISSING"; fi
  if [ -n "${POSTGRES_PASSWORD:-}" ]; then echo "POSTGRES_PASSWORD=SET"; else echo "POSTGRES_PASSWORD=MISSING"; fi
  if [ -n "${POSTGRES_DB:-}" ]; then echo "POSTGRES_DB=SET"; else echo "POSTGRES_DB=MISSING"; fi
} | tee reports/qa/db/db-env-status.txt

echo "=== RAG SEARCH ==="
grep -RInE "rag|retriev|retrieval|embedding|embeddings|vector|pgvector|qdrant|chroma|chunk|chunks|rerank|citation|source|sources|authentic|trust|stale|hallucination" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=target \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=reports \
  > reports/qa/rag/rag-full-search.txt || true

echo "=== BRAIN / ALGORITHM SEARCH ==="
grep -RInE "brain|algorithm|workflow|orchestr|orchestration|agent|planner|router|model_route|policy|guardrail|decision|risk|intent|classification|confidence|fallback|memory|personalization|fatwa|scholar|audit|trace" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=target \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=reports \
  > reports/qa/evidence/brain-algorithm-search.txt || true

echo "=== WASM SEARCH ==="
find . -type f \( -name "*.wasm" -o -name "*.wat" -o -name "*wasm*" \) \
  -not -path "./.git/*" \
  | sort > reports/qa/wasm/wasm-file-inventory.txt

grep -RInE "wasm|wasmtime|wasmer|webassembly|WASI|sandbox" . \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=target \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  --exclude-dir=reports \
  > reports/qa/wasm/wasm-search.txt || true

echo "=== INFRA INVENTORY ==="
find . -type f \( -name "Dockerfile*" -o -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -o -name "*.yaml" -o -name "*.yml" \) \
  -not -path "./.git/*" \
  -not -path "./node_modules/*" \
  | sort > reports/qa/infra/infra-files.txt

echo "=== FINAL GIT DIFF STATUS ==="
git status --short > reports/qa/evidence/git-status-after-qa.txt

echo ""
echo "============================================================"
echo "QA CHECK COMPLETE"
echo "Reports saved under: reports/qa/"
echo "============================================================"
