#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p reports/final-hardening-evidence

fail() {
  printf 'KUBERNETES_RESTRICTED_BLOCKER %s\n' "$1" >&2
  exit 1
}

if [[ -f tasks/AGENTS.md ]]; then
  cat tasks/AGENTS.md >/dev/null
fi
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

command -v kubectl >/dev/null 2>&1 || fail "kubectl is missing; live Kubernetes restricted proof cannot run"

TRIVY_BIN="${TRIVY_BIN:-}"
if [[ -z "$TRIVY_BIN" ]]; then
  if [[ -x ".local-bin/trivy" ]]; then
    TRIVY_BIN=".local-bin/trivy"
  elif command -v trivy >/dev/null 2>&1; then
    TRIVY_BIN="$(command -v trivy)"
  else
    fail "trivy binary is missing; Kubernetes manifest policy proof cannot run"
  fi
fi

MANIFEST_EVIDENCE="reports/final-hardening-evidence/630-kubernetes-manifest-restricted-scan.txt"
: > "$MANIFEST_EVIDENCE"
for target in sakina-infra infra/k8s infra/sakina-mobile; do
  [[ -e "$target" ]] || fail "required Kubernetes manifest target is missing: $target"
  {
    printf '=== Kubernetes restricted manifest scan target: %s ===\n' "$target"
    "$TRIVY_BIN" fs --scanners misconfig --severity HIGH,CRITICAL --exit-code 1 --timeout 20m "$target"
  } >> "$MANIFEST_EVIDENCE" 2>&1 \
    || fail "Kubernetes manifests violate restricted policy: $MANIFEST_EVIDENCE"
done

kubectl config current-context \
  > reports/final-hardening-evidence/630-kube-current-context.txt 2>&1 \
  || fail "kubectl current context is unavailable: reports/final-hardening-evidence/630-kube-current-context.txt"

kubectl cluster-info \
  > reports/final-hardening-evidence/630-kube-cluster-info.txt 2>&1 \
  || fail "Kubernetes cluster is unreachable: reports/final-hardening-evidence/630-kube-cluster-info.txt"

kubectl get nodes -o wide \
  > reports/final-hardening-evidence/630-kube-nodes.txt 2>&1 \
  || fail "Kubernetes nodes are not visible: reports/final-hardening-evidence/630-kube-nodes.txt"

kubectl get ns \
  > reports/final-hardening-evidence/630-kube-namespaces.txt 2>&1 \
  || fail "Kubernetes namespaces are not visible: reports/final-hardening-evidence/630-kube-namespaces.txt"

SAKINA_NS="${SAKINA_NS:-}"
if [[ -z "$SAKINA_NS" ]]; then
  for candidate in sakina sakina-ai sakinaai muslimai sakina-prod sakina-staging sakina-mobile-staging; do
    if kubectl get ns "$candidate" >/dev/null 2>&1; then
      SAKINA_NS="$candidate"
      break
    fi
  done
fi

[[ -n "$SAKINA_NS" ]] || fail "no Sakina Kubernetes namespace found in live cluster: reports/final-hardening-evidence/630-kube-namespaces.txt"
printf '%s\n' "$SAKINA_NS" > reports/final-hardening-evidence/630-kube-confirmed-namespace.txt

kubectl -n "$SAKINA_NS" get all -o wide \
  > reports/final-hardening-evidence/630-kube-all.txt 2>&1 \
  || fail "Sakina namespace resources are not readable: reports/final-hardening-evidence/630-kube-all.txt"

kubectl -n "$SAKINA_NS" get deploy,sts,job,cronjob,svc,ingress,configmap,secret,pvc -o wide \
  > reports/final-hardening-evidence/630-kube-core-resources.txt 2>&1 \
  || fail "Sakina namespace core resources are not readable: reports/final-hardening-evidence/630-kube-core-resources.txt"

kubectl -n "$SAKINA_NS" get events --sort-by=.lastTimestamp \
  > reports/final-hardening-evidence/630-kube-events.txt 2>&1 \
  || fail "Sakina namespace events are not readable: reports/final-hardening-evidence/630-kube-events.txt"

kubectl -n "$SAKINA_NS" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{range .status.containerStatuses[*]}{.ready}{"/"}{.restartCount}{" "}{end}{"\n"}{end}' \
  > reports/final-hardening-evidence/630-kube-pod-status.txt 2>&1 \
  || fail "Sakina pod status is not readable: reports/final-hardening-evidence/630-kube-pod-status.txt"

if grep -E "CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError|Pending" \
  reports/final-hardening-evidence/630-kube-all.txt reports/final-hardening-evidence/630-kube-pod-status.txt \
  > reports/final-hardening-evidence/630-kube-runtime-blockers.txt; then
  fail "Sakina Kubernetes runtime has failed or pending resources: reports/final-hardening-evidence/630-kube-runtime-blockers.txt"
fi

kubectl -n "$SAKINA_NS" get deploy,sts,job -o yaml \
  > reports/final-hardening-evidence/630-kube-workloads.yaml 2>&1 \
  || fail "Sakina workload YAML is not readable: reports/final-hardening-evidence/630-kube-workloads.yaml"

grep -R "readOnlyRootFilesystem: true" reports/final-hardening-evidence/630-kube-workloads.yaml \
  > reports/final-hardening-evidence/630-kube-readonly-root-proof.txt \
  || fail "live Sakina workloads do not prove readOnlyRootFilesystem: reports/final-hardening-evidence/630-kube-workloads.yaml"

if grep -R "privileged: true" reports/final-hardening-evidence/630-kube-workloads.yaml \
  > reports/final-hardening-evidence/630-kube-privileged-blocker.txt; then
  fail "live Sakina workloads include privileged containers: reports/final-hardening-evidence/630-kube-privileged-blocker.txt"
fi

grep -R "runAsNonRoot: true" reports/final-hardening-evidence/630-kube-workloads.yaml \
  > reports/final-hardening-evidence/630-kube-nonroot-proof.txt \
  || fail "live Sakina workloads do not prove runAsNonRoot: reports/final-hardening-evidence/630-kube-workloads.yaml"

grep -R "limits:" reports/final-hardening-evidence/630-kube-workloads.yaml \
  > reports/final-hardening-evidence/630-kube-resource-limits-proof.txt \
  || fail "live Sakina workloads do not prove resource limits: reports/final-hardening-evidence/630-kube-workloads.yaml"

grep -R "readinessProbe:" reports/final-hardening-evidence/630-kube-workloads.yaml \
  > reports/final-hardening-evidence/630-kube-readiness-proof.txt \
  || fail "live Sakina workloads do not prove readiness probes: reports/final-hardening-evidence/630-kube-workloads.yaml"

printf 'KUBERNETES_RESTRICTED_OK manifest restricted scan and live namespace restricted workload proof completed for namespace %s.\n' "$SAKINA_NS"
