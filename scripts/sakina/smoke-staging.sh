#!/usr/bin/env bash
set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_KUBE_CONTEXT:-ordinox-talos}"
TARGET_NAMESPACE="sakina-mobile-staging"
SMOKE_MANIFEST="infra/k8s/${TARGET_NAMESPACE}/smoke-tests.yaml"
SMOKE_JOB_NAME="sakina-staging-smoke"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if kubectl config current-context >/tmp/sakina-smoke-kube-context.txt 2>/tmp/sakina-smoke-kube-context.err; then
  ACTIVE_CONTEXT="$(cat /tmp/sakina-smoke-kube-context.txt)"
else
  ACTIVE_CONTEXT=""
fi
if [[ -z "${ACTIVE_CONTEXT}" ]]; then
  echo "Unable to read current kube context" >&2
  exit 1
fi

if [[ "${ACTIVE_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "Refusing smoke test: current context '${ACTIVE_CONTEXT}' does not match expected '${EXPECTED_CONTEXT}'" >&2
  exit 1
fi

kubectl delete job "${SMOKE_JOB_NAME}" -n "${TARGET_NAMESPACE}" --ignore-not-found
kubectl apply -f "${SMOKE_MANIFEST}"
kubectl wait --for=condition=complete "job/${SMOKE_JOB_NAME}" -n "${TARGET_NAMESPACE}" --timeout=240s

echo "staging smoke tests completed in ${TARGET_NAMESPACE}"
