#!/usr/bin/env bash
set -euo pipefail

cd /mnt/f/SakinaAl

echo "=== Repo check ==="
pwd
git branch --show-current
git rev-parse HEAD

echo "=== Local status before commit ==="
git status --short

echo "=== Add CI/CD files ==="
git add .github/workflows/sakina-ci.yml \
        .github/workflows/sakina-images.yml \
        .github/workflows/sakina-deploy.yml \
        scripts/ci/auto-push-sakina.sh

echo "=== Commit ==="
git commit -m "Add Sakina CI/CD pipelines and auto-push script" || echo "Nothing new to commit"

echo "=== Push ==="
git push origin qa-security-hardening

echo "=== Trigger workflows ==="
gh workflow run sakina-ci.yml --ref qa-security-hardening || true
gh workflow run sakina-images.yml --ref qa-security-hardening || true

echo "=== Latest workflow runs ==="
gh run list --branch qa-security-hardening --limit 10

echo "DONE"
