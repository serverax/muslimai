#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

ROOT="${PWD}"

if [[ "${ROOT}" == *"/mnt/f/lawapp"* ]]; then
  fail "Refusing to run from lawapp path: ${ROOT}"
fi

if [[ ! -d ".git" ]]; then
  fail "Not a git repository"
fi

if [[ ! -d "sakina-backend" || ! -d "sakina-frontend" ]]; then
  fail "Sakina repository markers are missing"
fi

if git remote -v | grep -Eiq 'lawapp'; then
  fail "Refusing repository with lawapp remote reference"
fi

if git remote -v | grep -Eiq 'iterlaw-ai|ordinox'; then
  echo "Warning: remote output mentions non-Sakina project names; review carefully." >&2
fi

if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    if [[ "$arg" == *"iterlaw-ai"* || "$arg" == *"lawapp"* || "$arg" == *"OrdinoxAI"* ]]; then
      fail "Refusing command argument that targets another project: $arg"
    fi
  done
fi

if command -v kubectl >/dev/null 2>&1; then
  context="$(kubectl config current-context 2>/dev/null || true)"
  if [[ -n "${context}" ]]; then
    if kubectl get ns --no-headers 2>/dev/null | awk '{print $1}' | grep -Eiq 'lawapp'; then
      fail "Cluster namespace list contains lawapp; this guard refuses mixed-project clusters"
    fi
  fi
fi

echo "sakina-only guard passed"
