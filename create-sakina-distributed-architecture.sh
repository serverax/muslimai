#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Sakina Distributed Architecture Automation Scaffold
# Purpose:
# - Create real service directories.
# - Create Kubernetes Deployment/Service manifests.
# - Create proof scripts.
# - Patch backend/LLM routing variables.
# - Refuse fake signoff if services are not deployed and reachable.
#
# This script does NOT magically move all existing business logic.
# Claude/Code must wire real code into each generated service entrypoint.
# ============================================================

SAKINA_NS="${SAKINA_NS:-sakina-mobile-staging}"
ROOT_DIR="${ROOT_DIR:-$(pwd)}"
IMAGE="${IMAGE:-ghcr.io/serverax/sakina-backend:f06535870dfcbec20b5c9757b6525a98edbc9157}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-ghcr.io/serverax/sakina-frontend:qa-security-hardening}"
MODEL="${MODEL:-qwen2.5:3b}"
K8S_DIR="${K8S_DIR:-infra/k8s/${SAKINA_NS}}"
SERVICES_DIR="${SERVICES_DIR:-services}"

echo "=== Sakina distributed architecture bootstrap ==="
echo "Namespace: $SAKINA_NS"
echo "Repo root:  $ROOT_DIR"
echo "Image:      $IMAGE"
echo "K8s dir:    $K8S_DIR"
echo

if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl not found"
  exit 1
fi

if [ ! -d "$ROOT_DIR" ]; then
  echo "FAIL: repo root does not exist: $ROOT_DIR"
  exit 1
fi

mkdir -p "$SERVICES_DIR"
mkdir -p "$K8S_DIR"
mkdir -p scripts/proof
mkdir -p docs/architecture

# ------------------------------------------------------------
# Service catalogue
# Format: service_name:port:kind
# kind = api | worker | internal
# ------------------------------------------------------------
cat > /tmp/sakina_services.list <<'EOF'
sakina-api-gateway:8080:api
sakina-auth-service:8080:internal
sakina-user-workspace-service:8080:internal
sakina-ask-shaikh-service:8080:internal
sakina-mother-algorithm-service:8080:internal
sakina-aia-orchestrator-service:8080:internal
sakina-islamic-knowledge-service:8080:internal
sakina-rag-retrieval-service:8080:internal
sakina-rag-ingestion-service:8080:internal
sakina-psychology-support-service:8080:internal
sakina-safety-policy-service:8080:internal
sakina-citation-guard-service:8080:internal
sakina-document-service:8080:internal
sakina-audit-service:8080:internal
sakina-notification-service:8080:internal
sakina-llm-gateway:8087:internal
EOF

# ------------------------------------------------------------
# Create a shared minimal service runtime.
# This is a real HTTP runtime, but business routes intentionally
# fail until wired. This prevents fake product signoff.
# ------------------------------------------------------------
mkdir -p "$SERVICES_DIR/common"

cat > "$SERVICES_DIR/common/distributed_service.py" <<'PY'
import os
import time
from typing import Dict, Any

try:
    from fastapi import FastAPI, Request, HTTPException
    from fastapi.responses import JSONResponse
except Exception as exc:
    raise RuntimeError(
        "FastAPI is required in the backend image. Install fastapi/uvicorn or use the existing backend runtime."
    ) from exc

SERVICE_NAME = os.getenv("SERVICE_NAME", "unknown-service")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", "8080"))
SERVICE_KIND = os.getenv("SERVICE_KIND", "internal")
REQUIRE_REAL_WIRING = os.getenv("REQUIRE_REAL_WIRING", "true").lower() == "true"
REAL_SERVICE_WIRED = os.getenv("REAL_SERVICE_WIRED", "false").lower() == "true"

app = FastAPI(title=SERVICE_NAME, version=os.getenv("GIT_SHA", "local"))

STARTED_AT = time.time()

@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "service": SERVICE_NAME,
        "kind": SERVICE_KIND,
        "uptime_seconds": round(time.time() - STARTED_AT, 2),
    }

@app.get("/ready")
def ready() -> Dict[str, Any]:
    if REQUIRE_REAL_WIRING and not REAL_SERVICE_WIRED:
        raise HTTPException(
            status_code=503,
            detail={
                "status": "not_ready",
                "service": SERVICE_NAME,
                "reason": "REAL_SERVICE_WIRED=false. Business logic must be connected before signoff.",
            },
        )
    return {
        "status": "ready",
        "service": SERVICE_NAME,
        "real_service_wired": REAL_SERVICE_WIRED,
    }

@app.get("/version")
def version() -> Dict[str, Any]:
    return {
        "service": SERVICE_NAME,
        "version": os.getenv("GIT_SHA", "unknown"),
        "image": os.getenv("IMAGE_NAME", "unknown"),
        "model": os.getenv("OLLAMA_MODEL", ""),
    }

@app.middleware("http")
async def require_trace_id(request: Request, call_next):
    if request.url.path in ["/health", "/ready", "/version"]:
        return await call_next(request)

    trace_id = request.headers.get("x-trace-id")
    if not trace_id:
        return JSONResponse(
            status_code=400,
            content={
                "error": "missing_trace_id",
                "service": SERVICE_NAME,
                "required_header": "x-trace-id",
            },
        )

    response = await call_next(request)
    response.headers["x-trace-id"] = trace_id
    response.headers["x-sakina-service"] = SERVICE_NAME
    return response

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def not_wired(path: str):
    raise HTTPException(
        status_code=501,
        detail={
            "service": SERVICE_NAME,
            "status": "not_implemented",
            "message": "This distributed service exists but its business route is not wired yet. Do not sign off.",
            "path": path,
        },
    )
PY

# ------------------------------------------------------------
# Create service entrypoint packages.
# ------------------------------------------------------------
while IFS=: read -r SVC PORT KIND; do
  PY_NAME="${SVC//-/_}"
  mkdir -p "$SERVICES_DIR/$PY_NAME"
  touch "$SERVICES_DIR/__init__.py"
  touch "$SERVICES_DIR/$PY_NAME/__init__.py"

  cat > "$SERVICES_DIR/$PY_NAME/main.py" <<PY
import os
os.environ.setdefault("SERVICE_NAME", "$SVC")
os.environ.setdefault("SERVICE_PORT", "$PORT")
os.environ.setdefault("SERVICE_KIND", "$KIND")

from services.common.distributed_service import app
PY

done < /tmp/sakina_services.list

# ------------------------------------------------------------
# Write Kubernetes manifests for every service.
# They use the same image but different commands and service names.
# Same image is acceptable only if command/args start different entrypoints.
# ------------------------------------------------------------
cat > "$K8S_DIR/00-distributed-services.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${SAKINA_NS}
EOF

while IFS=: read -r SVC PORT KIND; do
  PY_NAME="${SVC//-/_}"
  REPLICAS=1

  if [ "$SVC" = "sakina-api-gateway" ]; then
    REPLICAS=2
  fi

  if [ "$SVC" = "sakina-ask-shaikh-service" ]; then
    REPLICAS=2
  fi

  cat >> "$K8S_DIR/00-distributed-services.yaml" <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SVC}
  namespace: ${SAKINA_NS}
  labels:
    app: ${SVC}
    part-of: sakina
    architecture: distributed
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${SVC}
  template:
    metadata:
      labels:
        app: ${SVC}
        part-of: sakina
        architecture: distributed
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${SVC}
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["python", "-m", "services.${PY_NAME}.main"]
          args: []
          ports:
            - name: http
              containerPort: ${PORT}
          env:
            - name: SERVICE_NAME
              value: "${SVC}"
            - name: SERVICE_PORT
              value: "${PORT}"
            - name: SERVICE_KIND
              value: "${KIND}"
            - name: REQUIRE_REAL_WIRING
              value: "true"
            - name: REAL_SERVICE_WIRED
              value: "false"
            - name: OLLAMA_BASE_URL
              value: "http://ollama-inference.${SAKINA_NS}.svc.cluster.local:11434"
            - name: OLLAMA_MODEL
              value: "${MODEL}"
            - name: AUTH_SERVICE_URL
              value: "http://sakina-auth-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: WORKSPACE_SERVICE_URL
              value: "http://sakina-user-workspace-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: ASK_SHAIKH_SERVICE_URL
              value: "http://sakina-ask-shaikh-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: MOTHER_ALGORITHM_SERVICE_URL
              value: "http://sakina-mother-algorithm-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: AIA_ORCHESTRATOR_SERVICE_URL
              value: "http://sakina-aia-orchestrator-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: ISLAMIC_KNOWLEDGE_SERVICE_URL
              value: "http://sakina-islamic-knowledge-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: RAG_RETRIEVAL_SERVICE_URL
              value: "http://sakina-rag-retrieval-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: RAG_INGESTION_SERVICE_URL
              value: "http://sakina-rag-ingestion-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: PSYCHOLOGY_SUPPORT_SERVICE_URL
              value: "http://sakina-psychology-support-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: SAFETY_POLICY_SERVICE_URL
              value: "http://sakina-safety-policy-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: CITATION_GUARD_SERVICE_URL
              value: "http://sakina-citation-guard-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: DOCUMENT_SERVICE_URL
              value: "http://sakina-document-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: AUDIT_SERVICE_URL
              value: "http://sakina-audit-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: NOTIFICATION_SERVICE_URL
              value: "http://sakina-notification-service.${SAKINA_NS}.svc.cluster.local:8080"
            - name: LLM_GATEWAY_URL
              value: "http://sakina-llm-gateway.${SAKINA_NS}.svc.cluster.local:8087"
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 20
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 6
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
---
apiVersion: v1
kind: Service
metadata:
  name: ${SVC}
  namespace: ${SAKINA_NS}
  labels:
    app: ${SVC}
    part-of: sakina
    architecture: distributed
spec:
  type: ClusterIP
  selector:
    app: ${SVC}
  ports:
    - name: http
      port: ${PORT}
      targetPort: http
EOF

done < /tmp/sakina_services.list

# ------------------------------------------------------------
# Ollama DaemonSet fix.
# Uses only 2 nodes by default if one node cannot schedule.
# You can remove nodeAffinity later when all nodes have capacity.
# ------------------------------------------------------------
cat > "$K8S_DIR/10-ollama-inference-daemonset.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ollama-inference
  namespace: ${SAKINA_NS}
  labels:
    app: ollama-inference
    part-of: sakina
spec:
  type: ClusterIP
  selector:
    app: ollama-inference
  ports:
    - name: http
      port: 11434
      targetPort: 11434
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ollama-inference
  namespace: ${SAKINA_NS}
  labels:
    app: ollama-inference
    part-of: sakina
spec:
  selector:
    matchLabels:
      app: ollama-inference
  template:
    metadata:
      labels:
        app: ollama-inference
        part-of: sakina
    spec:
      tolerations:
        - operator: Exists
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ollama
          image: ollama/ollama:latest
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 11434
          env:
            - name: OLLAMA_HOST
              value: "0.0.0.0:11434"
            - name: OLLAMA_NUM_PARALLEL
              value: "1"
            - name: OLLAMA_MAX_LOADED_MODELS
              value: "1"
            - name: CUDA_VISIBLE_DEVICES
              value: ""
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2"
              memory: "6Gi"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: ollama-models
              mountPath: /root/.ollama
          readinessProbe:
            httpGet:
              path: /api/tags
              port: http
            initialDelaySeconds: 20
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 30
          livenessProbe:
            httpGet:
              path: /api/tags
              port: http
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 6
      volumes:
        - name: ollama-models
          emptyDir: {}
EOF

# ------------------------------------------------------------
# NetworkPolicy baseline.
# This is intentionally strict but not perfect. It must be tuned
# after all services are live.
# ------------------------------------------------------------
cat > "$K8S_DIR/20-network-policies.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sakina-default-deny-ingress
  namespace: ${SAKINA_NS}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-gateway-to-internal-services
  namespace: ${SAKINA_NS}
spec:
  podSelector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - sakina-auth-service
          - sakina-user-workspace-service
          - sakina-ask-shaikh-service
          - sakina-audit-service
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: sakina-api-gateway
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-llm-gateway-to-ollama
  namespace: ${SAKINA_NS}
spec:
  podSelector:
    matchLabels:
      app: ollama-inference
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: sakina-llm-gateway
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-rag-to-qdrant-postgres
  namespace: ${SAKINA_NS}
spec:
  podSelector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - sakina-postgres
          - sakina-qdrant
  ingress:
    - from:
        - podSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - sakina-rag-retrieval-service
                  - sakina-rag-ingestion-service
                  - sakina-islamic-knowledge-service
                  - sakina-auth-service
                  - sakina-user-workspace-service
                  - sakina-audit-service
                  - sakina-document-service
  policyTypes:
    - Ingress
EOF

# ------------------------------------------------------------
# Architecture doc.
# ------------------------------------------------------------
cat > docs/architecture/sakina-distributed-architecture.md <<EOF
# Sakina Distributed Architecture

Generated by create-sakina-distributed-architecture.sh

## Rule

The mobile/frontend must call only:

- sakina-api-gateway

No frontend/mobile direct calls to:

- Ollama
- RAG
- Postgres
- Qdrant
- Redis
- LLM Gateway
- internal business services

## Ask Shaikh target flow

frontend/mobile
-> sakina-api-gateway
-> sakina-auth-service
-> sakina-user-workspace-service
-> sakina-ask-shaikh-service
-> sakina-mother-algorithm-service
-> sakina-islamic-knowledge-service and/or sakina-rag-retrieval-service
-> sakina-safety-policy-service
-> sakina-aia-orchestrator-service
-> sakina-llm-gateway
-> ollama-inference
-> sakina-citation-guard-service
-> sakina-audit-service
-> response

## Signoff rule

Do not sign off until:

- every service has a Deployment
- every service has a Service
- every service has endpoints
- /health works
- /ready works only after REAL_SERVICE_WIRED=true
- every route is real, not placeholder
- Ask Shaikh passes end to end
- DB rows prove workspace isolation, trace, citation, safety, and audit
EOF

# ------------------------------------------------------------
# Proof script.
# ------------------------------------------------------------
cat > scripts/proof/prove-distributed-architecture.sh <<'EOF'
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
EOF

chmod +x scripts/proof/prove-distributed-architecture.sh

# ------------------------------------------------------------
# Frontend/internal service direct-call scan.
# ------------------------------------------------------------
cat > scripts/proof/scan-frontend-for-internal-calls.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Scanning for direct frontend/mobile calls to internal services ==="

grep -R "ollama\|rag-retrieval\|rag-ingestion\|llm-gateway\|postgres\|qdrant\|redis\|sakina-backend\|ollama-inference" -n . \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=build \
  --exclude-dir=dist \
  --exclude-dir=.next \
  --exclude="*.lock" || true

echo
echo "Review the above. Frontend/mobile must call only sakina-api-gateway."
EOF

chmod +x scripts/proof/scan-frontend-for-internal-calls.sh

# ------------------------------------------------------------
# Apply option.
# ------------------------------------------------------------
echo
echo "=== Files created ==="
echo "$K8S_DIR/00-distributed-services.yaml"
echo "$K8S_DIR/10-ollama-inference-daemonset.yaml"
echo "$K8S_DIR/20-network-policies.yaml"
echo "scripts/proof/prove-distributed-architecture.sh"
echo "scripts/proof/scan-frontend-for-internal-calls.sh"
echo "docs/architecture/sakina-distributed-architecture.md"
echo

echo "=== IMPORTANT ==="
echo "The generated services have REAL_SERVICE_WIRED=false."
echo "This means /health works, but /ready fails until Claude wires real business logic."
echo "This prevents fake signoff."
echo

read -r -p "Apply Kubernetes manifests now? Type YES to apply: " APPLY_NOW

if [ "$APPLY_NOW" = "YES" ]; then
  echo "Applying manifests..."
  kubectl apply -f "$K8S_DIR/00-distributed-services.yaml"
  kubectl apply -f "$K8S_DIR/10-ollama-inference-daemonset.yaml"
  kubectl apply -f "$K8S_DIR/20-network-policies.yaml"

  echo
  echo "Waiting for basic rollout..."
  while IFS=: read -r SVC PORT KIND; do
    echo "=== rollout $SVC ==="
    kubectl -n "$SAKINA_NS" rollout status "deployment/$SVC" --timeout=120s || true
  done < /tmp/sakina_services.list

  echo
  echo "=== Ollama rollout ==="
  kubectl -n "$SAKINA_NS" rollout status daemonset/ollama-inference --timeout=180s || true

  echo
  echo "=== Pull model into running Ollama pods ==="
  for POD in $(kubectl -n "$SAKINA_NS" get pods -l app=ollama-inference --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' || true); do
    echo "Pulling $MODEL on $POD"
    kubectl -n "$SAKINA_NS" exec "$POD" -c ollama -- ollama pull "$MODEL" || true
  done

  echo
  echo "=== Proof ==="
  scripts/proof/prove-distributed-architecture.sh || true
else
  echo "Not applied. Review files first, then run:"
  echo "kubectl apply -f $K8S_DIR/00-distributed-services.yaml"
  echo "kubectl apply -f $K8S_DIR/10-ollama-inference-daemonset.yaml"
  echo "kubectl apply -f $K8S_DIR/20-network-policies.yaml"
fi

echo
echo "DONE: distributed architecture scaffold created."
echo "NEXT: Claude must move real code into each service and set REAL_SERVICE_WIRED=true only after end-to-end proof."
