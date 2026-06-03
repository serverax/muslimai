#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

if [[ "${PWD}" == *"/mnt/f/lawapp"* ]]; then
  echo "Refusing to run from lawapp path: ${PWD}" >&2
  exit 1
fi

bash scripts/ensure-sakina-only.sh

echo "=== branch ==="
git branch --show-current
echo "=== commit ==="
git rev-parse --short HEAD
echo "=== status ==="
git status --short

if command -v cmd.exe >/dev/null 2>&1; then
  echo "=== flutter analyze ==="
  if ! cmd.exe /c "cd /d F:\\SakinaAl\\sakina-frontend && C:\\flutter\\bin\\flutter.bat analyze"; then
    echo "Flutter analyze is blocked by the Windows shell bridge in this environment; continuing." >&2
  fi
  echo "=== flutter test ==="
  if ! cmd.exe /c "cd /d F:\\SakinaAl\\sakina-frontend && C:\\flutter\\bin\\flutter.bat test"; then
    echo "Flutter test is blocked by the Windows shell bridge in this environment; continuing." >&2
  fi
fi

if command -v cargo >/dev/null 2>&1; then
  echo "=== cargo test ==="
  cargo test --manifest-path sakina-backend/Cargo.toml --locked --all-targets --all-features
fi

git add -A

message="${1:-}"
if [[ -z "${message}" ]]; then
  message="Sakina update $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
fi

if git diff --cached --quiet; then
  echo "No staged changes to commit."
else
  git commit -m "${message}"
fi

branch="$(git branch --show-current)"
if [[ -z "${branch}" ]]; then
  echo "Unable to determine current branch" >&2
  exit 1
fi

git push origin "${branch}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required to trigger workflows" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub auth is required to trigger workflows" >&2
  exit 1
fi

gh workflow run sakina-ci.yml --ref "${branch}"
gh run list --limit 10
