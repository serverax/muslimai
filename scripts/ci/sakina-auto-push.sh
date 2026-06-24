#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-$(git branch --show-current)}"
MESSAGE="${1:-auto: Sakina CI/CD update}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n=== %s ===\n' "$*"
}

git rev-parse --show-toplevel >/dev/null 2>&1 || die "Run inside Sakina git repo"
cd "$(git rev-parse --show-toplevel)"

[ -n "$BRANCH" ] || die "Cannot detect branch"

info "Preflight: repo status"
git status --short

info "Preflight: blocked files"
if git status --short | grep -E '(^|/)(\.local-bin|node_modules|build|dist|\.dart_tool|\.gradle)(/|$)|trivy|\.gguf$|\.safetensors$'; then
  die "Blocked generated/binary/model files detected. Remove them before pushing."
fi

info "Preflight: secret scan patterns"
if git diff --cached --name-only | grep -E '\.(pem|p8|key)$|(^|/)\.env(\.|$)' >/dev/null; then
  die "Secret-like file staged. Refusing to push."
fi

if command -v rg >/dev/null 2>&1; then
  if rg -n --hidden --glob '!.git' --glob '!reports/**' --glob '!docs/**' \
    'sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|-----BEGIN (RSA |OPENSSH |EC |)PRIVATE KEY-----' .; then
    die "High-risk secret pattern found."
  fi
fi

info "Preflight: syntax checks available locally"
if command -v cargo >/dev/null 2>&1 && [ -f sakina-backend/Cargo.toml ]; then
  (cd sakina-backend && cargo fmt --all -- --check && cargo check && cargo test --lib)
else
  printf 'cargo not available locally; GitHub Actions will run Rust checks.\n'
fi

if command -v flutter >/dev/null 2>&1 && [ -f sakina-frontend/pubspec.yaml ]; then
  (cd sakina-frontend && flutter pub get && flutter analyze && flutter test)
else
  printf 'flutter not available locally; GitHub Actions will run Flutter checks.\n'
fi

info "Commit changes"
git add .github/workflows/sakina-auto-ci-cd.yml scripts/ci/sakina-auto-push.sh .gitignore
git add -A
if git diff --cached --quiet; then
  printf 'No staged changes to commit.\n'
else
  git commit -m "$MESSAGE"
fi

info "Push"
git push "$REMOTE" "$BRANCH"

info "Done"
printf 'Pushed branch: %s/%s\n' "$REMOTE" "$BRANCH"
printf 'Now check GitHub Actions for Sakina Auto CI/CD.\n'
