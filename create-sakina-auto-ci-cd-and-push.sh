#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-$(pwd)}"
BRANCH="${BRANCH:-qa-security-hardening}"
REMOTE="${REMOTE:-origin}"
WORKFLOW_FILE=".github/workflows/sakina-auto-ci-cd.yml"
PUSH_SCRIPT="scripts/ci/sakina-auto-push.sh"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n=== %s ===\n' "$*"
}

cd "$ROOT"
git rev-parse --show-toplevel >/dev/null 2>&1 || die "Run this inside the Sakina git repo, for example: cd /mnt/f/sakinaal"
cd "$(git rev-parse --show-toplevel)"

info "Sakina auto CI/CD setup"
printf 'Repo:   %s\n' "$(pwd)"
printf 'Branch: %s\n' "$BRANCH"
printf 'Remote: %s\n' "$REMOTE"

mkdir -p .github/workflows scripts/ci

info "Updating .gitignore safety rules"
touch .gitignore
for pattern in \
  ".local-bin/" \
  "trivy" \
  "node_modules/" \
  "build/" \
  "dist/" \
  ".dart_tool/" \
  ".gradle/" \
  "*.pem" \
  "*.p8" \
  "*.key" \
  ".env" \
  ".env.*" \
  "models/" \
  "*.gguf" \
  "*.safetensors"
do
  grep -Fxq "$pattern" .gitignore || printf '%s\n' "$pattern" >> .gitignore
done

info "Creating auto push helper"
cat > "$PUSH_SCRIPT" <<'EOS'
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
EOS
chmod +x "$PUSH_SCRIPT"

info "Creating GitHub Actions CI/CD workflow"
cat > "$WORKFLOW_FILE" <<'EOS'
name: Sakina Auto CI/CD

on:
  push:
    branches:
      - qa-security-hardening
      - main
  workflow_dispatch:
    inputs:
      deploy_environment:
        description: "Target environment"
        required: true
        default: "staging"
        type: choice
        options:
          - staging
          - prod
      deploy:
        description: "Deploy after build"
        required: true
        default: true
        type: boolean

permissions:
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io
  BACKEND_IMAGE: ghcr.io/${{ github.repository_owner }}/sakina-backend
  FRONTEND_IMAGE: ghcr.io/${{ github.repository_owner }}/sakina-frontend
  STAGING_NAMESPACE: sakina-mobile-staging
  PROD_NAMESPACE: sakina-mobile-prod

jobs:
  guardrails:
    name: No fake, no secrets, no direct Ollama
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Block generated binaries, model files, and local caches
        run: |
          set -euo pipefail
          if git ls-files | grep -E '(^|/)(\.local-bin|node_modules|build|dist|\.dart_tool|\.gradle)(/|$)|trivy$|\.gguf$|\.safetensors$'; then
            echo "Blocked generated/binary/model files are tracked."
            exit 1
          fi

      - name: Secret scan
        run: |
          set -euo pipefail
          if grep -RInE 'sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|-----BEGIN (RSA |OPENSSH |EC |)PRIVATE KEY-----' \
            --exclude-dir=.git --exclude-dir=reports --exclude-dir=docs .; then
            echo "High-risk secret pattern found."
            exit 1
          fi

      - name: Prove only LLM gateway can own Ollama endpoint
        run: |
          set -euo pipefail
          matches="$(grep -RInE 'OLLAMA_BASE_URL|ollama-inference|:11434|/api/generate' \
            sakina-backend/src sakina-frontend/lib infra/k8s .github/workflows scripts 2>/dev/null || true)"
          printf '%s\n' "$matches"
          disallowed="$(printf '%s\n' "$matches" | grep -vE 'sakina-backend/src/bin/llm_gateway.rs|infra/k8s/.*/llm-gateway.yaml|infra/k8s/.*/ollama|sakina-deploy|sakina-auto-ci-cd|final-llm-gateway-isolation|llm-gateway-local-runtime-proof' || true)"
          if [ -n "$disallowed" ]; then
            echo "Direct Ollama or gateway endpoint references found outside approved files:"
            printf '%s\n' "$disallowed"
            exit 1
          fi

      - name: Block fake product readiness language in code paths
        run: |
          set -euo pipefail
          if grep -RInE 'fake pass|mock pass|placeholder service|TODO: production|coming soon' \
            sakina-backend/src sakina-frontend/lib infra/k8s 2>/dev/null; then
            echo "Fake/placeholder production marker found."
            exit 1
          fi

  backend:
    name: Backend Rust checks
    runs-on: ubuntu-latest
    needs: guardrails
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - name: Cache cargo
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: sakina-backend
      - name: Backend fmt
        working-directory: sakina-backend
        run: cargo fmt --all -- --check
      - name: Backend check
        working-directory: sakina-backend
        run: cargo check --locked
      - name: Backend tests
        working-directory: sakina-backend
        run: cargo test --locked --all-targets

  frontend:
    name: Flutter mobile checks
    runs-on: ubuntu-latest
    needs: guardrails
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Flutter pub get
        working-directory: sakina-frontend
        run: flutter pub get
      - name: Flutter analyze
        working-directory: sakina-frontend
        run: flutter analyze
      - name: Flutter tests
        working-directory: sakina-frontend
        run: flutter test

  build-images:
    name: Build and push images
    runs-on: ubuntu-latest
    needs:
      - backend
      - frontend
    outputs:
      backend_image: ${{ steps.tags.outputs.backend_image }}
      frontend_image: ${{ steps.tags.outputs.frontend_image }}
    steps:
      - uses: actions/checkout@v4
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Compute image tags
        id: tags
        run: |
          echo "backend_image=${BACKEND_IMAGE}:${GITHUB_SHA}" >> "$GITHUB_OUTPUT"
          echo "frontend_image=${FRONTEND_IMAGE}:${GITHUB_SHA}" >> "$GITHUB_OUTPUT"
      - name: Build backend
        run: docker build -f sakina-backend/Dockerfile -t "${BACKEND_IMAGE}:${GITHUB_SHA}" sakina-backend
      - name: Push backend
        run: docker push "${BACKEND_IMAGE}:${GITHUB_SHA}"
      - name: Build frontend/admin image
        run: docker build -f Dockerfile.frontend -t "${FRONTEND_IMAGE}:${GITHUB_SHA}" .
      - name: Push frontend/admin image
        run: docker push "${FRONTEND_IMAGE}:${GITHUB_SHA}"

  deploy:
    name: Deploy to Talos Kubernetes
    runs-on: ubuntu-latest
    needs: build-images
    if: ${{ github.event_name == 'push' || inputs.deploy == true }}
    environment: ${{ inputs.deploy_environment || 'staging' }}
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-kubectl@v4

      - name: Select namespace and manifests
        id: target
        run: |
          set -euo pipefail
          target="${{ inputs.deploy_environment || 'staging' }}"
          if [ "$target" = "prod" ]; then
            echo "namespace=${PROD_NAMESPACE}" >> "$GITHUB_OUTPUT"
            echo "manifest_dir=infra/k8s/sakina-mobile-prod" >> "$GITHUB_OUTPUT"
          else
            echo "namespace=${STAGING_NAMESPACE}" >> "$GITHUB_OUTPUT"
            echo "manifest_dir=infra/k8s/sakina-mobile-staging" >> "$GITHUB_OUTPUT"
          fi

      - name: Load kubeconfig
        env:
          KUBE_CONFIG_B64: ${{ secrets.KUBE_CONFIG_B64 }}
          TALOS_KUBECONFIG_B64: ${{ secrets.TALOS_KUBECONFIG_B64 }}
        run: |
          set -euo pipefail
          mkdir -p "$HOME/.kube"
          if [ -n "${KUBE_CONFIG_B64:-}" ]; then
            printf '%s' "$KUBE_CONFIG_B64" | base64 -d > "$HOME/.kube/config"
          elif [ -n "${TALOS_KUBECONFIG_B64:-}" ]; then
            printf '%s' "$TALOS_KUBECONFIG_B64" | base64 -d > "$HOME/.kube/config"
          else
            echo "Missing KUBE_CONFIG_B64 or TALOS_KUBECONFIG_B64 secret."
            exit 1
          fi
          kubectl config current-context

      - name: Apply manifests
        run: |
          set -euo pipefail
          ns="${{ steps.target.outputs.namespace }}"
          dir="${{ steps.target.outputs.manifest_dir }}"
          test -d "$dir" || { echo "Missing manifest directory: $dir"; exit 1; }
          kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns"
          kubectl apply -f "$dir"

      - name: Set deployed images
        run: |
          set -euo pipefail
          ns="${{ steps.target.outputs.namespace }}"
          kubectl -n "$ns" set image deployment/sakina-backend backend="${{ needs.build-images.outputs.backend_image }}" --record
          if kubectl -n "$ns" get deployment sakina-llm-gateway >/dev/null 2>&1; then
            kubectl -n "$ns" set image deployment/sakina-llm-gateway llm-gateway="${{ needs.build-images.outputs.backend_image }}" --record
          fi
          if kubectl -n "$ns" get deployment sakina-admin >/dev/null 2>&1; then
            kubectl -n "$ns" set image deployment/sakina-admin admin="${{ needs.build-images.outputs.frontend_image }}" --record
          fi

      - name: Rollout proof
        run: |
          set -euo pipefail
          ns="${{ steps.target.outputs.namespace }}"
          kubectl -n "$ns" get deploy,ds,sts,pods,svc -o wide
          kubectl -n "$ns" rollout status deployment/sakina-backend --timeout=10m
          kubectl -n "$ns" rollout status deployment/sakina-llm-gateway --timeout=10m
          if kubectl -n "$ns" get daemonset ollama-inference >/dev/null 2>&1; then
            kubectl -n "$ns" rollout status daemonset/ollama-inference --timeout=10m
          fi

      - name: Runtime smoke proof
        run: |
          set -euo pipefail
          ns="${{ steps.target.outputs.namespace }}"
          kubectl -n "$ns" run "sakina-ci-smoke-${GITHUB_RUN_ID}" \
            --rm -i --restart=Never --image=curlimages/curl:8.8.0 \
            -- sh -c '
              set -e
              curl -fsS http://sakina-backend:8080/health
              echo
              curl -fsS http://sakina-backend:8080/health/ready || true
              echo
              curl -fsS http://sakina-llm-gateway:8087/health
              echo
              curl -fsS http://sakina-llm-gateway:8087/ready
              echo
            '
EOS

info "Creating setup report"
cat > docs-sakina-auto-ci-cd-setup.txt <<EOF
Sakina Auto CI/CD Setup

Created:
- $PUSH_SCRIPT
- $WORKFLOW_FILE
- .gitignore safety additions

GitHub secrets required for deployment:
- KUBE_CONFIG_B64 or TALOS_KUBECONFIG_B64

Optional:
- BRANCH=qa-security-hardening
- REMOTE=origin

Usage:
cd /mnt/f/sakinaal
chmod +x create-sakina-auto-ci-cd-and-push.sh
./create-sakina-auto-ci-cd-and-push.sh

Then for normal future pushes:
./scripts/ci/sakina-auto-push.sh "your commit message"
EOF

info "Committing setup"
git add "$WORKFLOW_FILE" "$PUSH_SCRIPT" .gitignore docs-sakina-auto-ci-cd-setup.txt
if git diff --cached --quiet; then
  printf 'No setup changes to commit.\n'
else
  git commit -m "Add Sakina auto CI CD and push setup"
fi

info "Pushing setup branch"
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH" ]; then
  printf 'Current branch is %s, requested branch is %s.\n' "$current_branch" "$BRANCH"
  printf 'Pushing current branch instead.\n'
  BRANCH="$current_branch"
fi
git push "$REMOTE" "$BRANCH"

info "Complete"
printf 'Created auto CI/CD workflow: %s\n' "$WORKFLOW_FILE"
printf 'Created auto push helper: %s\n' "$PUSH_SCRIPT"
printf 'Required GitHub secret for deployment: KUBE_CONFIG_B64 or TALOS_KUBECONFIG_B64\n'
