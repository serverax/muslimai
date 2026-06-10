#!/usr/bin/env bash
set -Eeuo pipefail

SAKINA_NS="${SAKINA_NS:-sakina-mobile-staging}"

echo "=== WORKLOADS ==="
kubectl -n "$SAKINA_NS" get deploy,ds,sts,pod,svc,endpoints -o wide

echo
echo "=== SERVICE ENTRYPOINTS ==="
for DEPLOY in $(kubectl -n "$SAKINA_NS" get deploy -o jsonpath='{.items[*].metadata.name}'); do
  echo
  echo "=== $DEPLOY ==="
  kubectl -n "$SAKINA_NS" get deploy "$DEPLOY" -o jsonpath='{range .spec.template.spec.containers[*]}container={.name} image={.image} command={.command} args={.args}{"\n"}{end}'
done

echo
echo "=== ENDPOINTS ==="
kubectl -n "$SAKINA_NS" get endpoints -o wide

echo
echo "=== POD DISTRIBUTION ==="
kubectl -n "$SAKINA_NS" get pods -o wide

echo
echo "=== OLLAMA ==="
kubectl -n "$SAKINA_NS" get ds,pod,svc,endpoints -o wide | grep -Ei "ollama|inference" || true

echo
echo "=== NETWORK POLICIES ==="
kubectl -n "$SAKINA_NS" get networkpolicy -o wide || true

echo
echo "=== HEALTH CHECKS ==="
SERVICES="
sakina-api-gateway:8080
sakina-auth-service:8080
sakina-user-workspace-service:8080
sakina-ask-shaikh-service:8080
sakina-mother-algorithm-service:8080
sakina-aia-orchestrator-service:8080
sakina-islamic-knowledge-service:8080
sakina-rag-retrieval-service:8080
sakina-rag-ingestion-service:8080
sakina-psychology-support-service:8080
sakina-safety-policy-service:8080
sakina-citation-guard-service:8080
sakina-document-service:8080
sakina-audit-service:8080
sakina-notification-service:8080
sakina-llm-gateway:8087
"

for ITEM in $SERVICES; do
  SVC="${ITEM%%:*}"
  PORT="${ITEM##*:}"
  echo
  echo "=== $SVC /health ==="
  kubectl -n "$SAKINA_NS" run "curl-health-$SVC-$(date +%s)" \
    --rm -i --restart=Never --image=curlimages/curl:8.8.0 \
    -- curl -fsS "http://$SVC:$PORT/health" || {
      echo "FAIL: health check failed for $SVC"
      exit 1
    }
done

echo
echo "=== READY CHECKS ==="
echo "Note: /ready is expected to FAIL until REAL_SERVICE_WIRED=true after real business logic is connected."
for ITEM in $SERVICES; do
  SVC="${ITEM%%:*}"
  PORT="${ITEM##*:}"
  echo
  echo "=== $SVC /ready ==="
  kubectl -n "$SAKINA_NS" run "curl-ready-$SVC-$(date +%s)" \
    --rm -i --restart=Never --image=curlimages/curl:8.8.0 \
    -- curl -sS "http://$SVC:$PORT/ready" || true
done

echo
echo "=== FINAL NOTE ==="
echo "Distributed infrastructure proof complete."
echo "Product signoff still requires REAL_SERVICE_WIRED=true and full Ask Shaikh end-to-end DB/citation/audit proof."
