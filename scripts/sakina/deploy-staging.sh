#!/usr/bin/env bash
set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_KUBE_CONTEXT:-ordinox-talos}"
TARGET_NAMESPACE="sakina-mobile-staging"
KUSTOMIZE_PATH="infra/k8s/${TARGET_NAMESPACE}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if kubectl config current-context >/tmp/sakina-active-kube-context.txt 2>/tmp/sakina-active-kube-context.err; then
  ACTIVE_CONTEXT="$(cat /tmp/sakina-active-kube-context.txt)"
else
  ACTIVE_CONTEXT=""
fi
if [[ -z "${ACTIVE_CONTEXT}" ]]; then
  echo "Unable to read current kube context" >&2
  exit 1
fi

if [[ "${ACTIVE_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "Refusing deploy: current context '${ACTIVE_CONTEXT}' does not match expected '${EXPECTED_CONTEXT}'" >&2
  exit 1
fi

bash scripts/sakina/verify-single-namespace.sh
bash scripts/sakina/verify-no-secret-leak.sh --all-files

kubectl apply -f "${KUSTOMIZE_PATH}/namespace.yaml"
kubectl apply -k "${KUSTOMIZE_PATH}"
kubectl rollout status deployment/sakina-backend -n "${TARGET_NAMESPACE}" --timeout=180s
kubectl rollout status deployment/sakina-rag -n "${TARGET_NAMESPACE}" --timeout=180s
kubectl rollout status deployment/sakina-admin -n "${TARGET_NAMESPACE}" --timeout=180s

echo "staging deploy applied to ${TARGET_NAMESPACE}"
