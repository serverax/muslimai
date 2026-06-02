#!/usr/bin/env bash
set -euo pipefail

TARGET_NAMESPACE="sakina-mobile-staging"
MANIFEST_ROOT="infra/k8s/${TARGET_NAMESPACE}"

if [[ ! -d "${MANIFEST_ROOT}" ]]; then
  echo "Missing manifest directory: ${MANIFEST_ROOT}" >&2
  exit 1
fi

if ! grep -Eq '^kind:[[:space:]]*Namespace$' "${MANIFEST_ROOT}/namespace.yaml"; then
  echo "namespace.yaml must define kind: Namespace" >&2
  exit 1
fi

if ! grep -Eq "^[[:space:]]+name:[[:space:]]*${TARGET_NAMESPACE}$" "${MANIFEST_ROOT}/namespace.yaml"; then
  echo "namespace.yaml must set metadata.name to ${TARGET_NAMESPACE}" >&2
  exit 1
fi

mapfile -t files < <(find "${MANIFEST_ROOT}" -type f -name '*.yaml' | sort)

for file in "${files[@]}"; do
  [[ "${file}" == *"/namespace.yaml" ]] && continue
  [[ "${file}" == *"/kustomization.yaml" ]] && continue
  if ! grep -Eq "^[[:space:]]+namespace:[[:space:]]*${TARGET_NAMESPACE}$" "${file}"; then
    echo "Missing or incorrect namespace in ${file}" >&2
    exit 1
  fi
  if grep -Eq '^[[:space:]]+namespace:[[:space:]]*(default|kube-system|sakina-mobile|sakina-prod|production)[[:space:]]*$' "${file}"; then
    echo "Forbidden namespace reference in ${file}" >&2
    exit 1
  fi
done

echo "namespace verification passed for ${TARGET_NAMESPACE}"
