#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SakinaAI Infrastructure Installer
# ==============================================================================
# Creates the required Kubernetes infrastructure for SakinaAI mobile app.
#
# Creates:
# - sakina-prod namespace
# - developer RBAC
# - resource quota and limits
# - configmap
# - secrets from env vars or placeholder mode
# - Redis cache
# - API deployment/service
# - Admin web deployment/service
# - Worker deployment
# - HPA autoscaling
# - Network policies
# - Ingress with TLS annotations
# - Supabase Storage buckets
# - Supabase/Postgres backup CronJob
# - Smoke test job
# - Developer handover commands
#
# Run test mode:
#   export ALLOW_PLACEHOLDER_SECRETS=true
#   bash sakinaai-infra.sh
#
# Run production mode:
#   export SUPABASE_URL="https://xxxxx.supabase.co"
#   export SUPABASE_ANON_KEY="xxxxx"
#   export SUPABASE_SERVICE_ROLE_KEY="xxxxx"
#   export DATABASE_URL="postgresql://user:password@host:5432/postgres?sslmode=require"
#   export JWT_SECRET="$(openssl rand -hex 48)"
#   bash sakinaai-infra.sh
# ==============================================================================

NS="${NS:-sakina-prod}"
MONITORING_NS="${MONITORING_NS:-sakina-monitoring}"

SAKINA_DOMAIN="${SAKINA_DOMAIN:-sakinaapp.com}"
API_HOST="${API_HOST:-api.${SAKINA_DOMAIN}}"
ADMIN_HOST="${ADMIN_HOST:-admin.${SAKINA_DOMAIN}}"

API_IMAGE="${API_IMAGE:-ghcr.io/serverax/sakinaai-api:0.1.0}"
ADMIN_IMAGE="${ADMIN_IMAGE:-ghcr.io/serverax/sakinaai-admin-web:0.1.0}"
WORKER_IMAGE="${WORKER_IMAGE:-ghcr.io/serverax/sakinaai-worker:0.1.0}"

INGRESS_CLASS="${INGRESS_CLASS:-traefik}"
CERT_MANAGER_ISSUER="${CERT_MANAGER_ISSUER:-letsencrypt-prod}"

AI_GATEWAY_URL="${AI_GATEWAY_URL:-http://ollama.ordinox-ai.svc.cluster.local:11434}"

ALLOW_PLACEHOLDER_SECRETS="${ALLOW_PLACEHOLDER_SECRETS:-false}"
CREATE_SUPABASE_BUCKETS="${CREATE_SUPABASE_BUCKETS:-true}"
RUN_SMOKE_TEST="${RUN_SMOKE_TEST:-true}"
WAIT_FOR_ROLLOUT="${WAIT_FOR_ROLLOUT:-true}"

BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"

APPLE_CLIENT_ID="${APPLE_CLIENT_ID:-}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
AI_GATEWAY_API_KEY="${AI_GATEWAY_API_KEY:-}"

CONFIGURE_CLOUDFLARE_DNS="${CONFIGURE_CLOUDFLARE_DNS:-false}"
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-}"
CLUSTER_PUBLIC_IP="${CLUSTER_PUBLIC_IP:-}"

section() {
  echo
  echo "============================================================================="
  echo "$1"
  echo "============================================================================="
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

require_env_or_placeholder() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    if [[ "$ALLOW_PLACEHOLDER_SECRETS" == "true" ]]; then
      export "$name"="REPLACE_ME_${name}"
    else
      fail "Missing required env var: $name. Set it, or use ALLOW_PLACEHOLDER_SECRETS=true for test only."
    fi
  fi
}

apply_yaml() {
  kubectl apply -f -
}

section "1. Preflight"

need_cmd kubectl

if ! kubectl cluster-info >/dev/null 2>&1; then
  fail "kubectl cannot reach your Kubernetes cluster. Check kubeconfig first."
fi

if [[ "$CREATE_SUPABASE_BUCKETS" == "true" || "$CONFIGURE_CLOUDFLARE_DNS" == "true" ]]; then
  need_cmd curl
fi

if [[ "$CONFIGURE_CLOUDFLARE_DNS" == "true" ]]; then
  need_cmd jq
fi

require_env_or_placeholder SUPABASE_URL
require_env_or_placeholder SUPABASE_ANON_KEY
require_env_or_placeholder SUPABASE_SERVICE_ROLE_KEY
require_env_or_placeholder DATABASE_URL
require_env_or_placeholder JWT_SECRET

echo "Kubernetes context: $(kubectl config current-context 2>/dev/null || echo unknown)"
echo "Namespace: ${NS}"
echo "API host: ${API_HOST}"
echo "Admin host: ${ADMIN_HOST}"
echo "API image: ${API_IMAGE}"
echo "Admin image: ${ADMIN_IMAGE}"
echo "Worker image: ${WORKER_IMAGE}"

if [[ "$ALLOW_PLACEHOLDER_SECRETS" == "true" ]]; then
  echo "WARNING: placeholder secrets enabled. Do not use for production."
fi

section "2. Namespaces"

cat <<YAML | apply_yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS}
  labels:
    app.kubernetes.io/name: sakinaai
    app.kubernetes.io/part-of: sakinaai-mobile
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${MONITORING_NS}
  labels:
    app.kubernetes.io/name: sakinaai-monitoring
    app.kubernetes.io/part-of: sakinaai-mobile
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
YAML

section "3. Developer RBAC"

cat <<YAML | apply_yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sakinaai-developer
  namespace: ${NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sakinaai-developer-readonly-plus-exec
  namespace: ${NS}
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "endpoints", "configmaps", "events", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sakinaai-developer-access
  namespace: ${NS}
subjects:
  - kind: ServiceAccount
    name: sakinaai-developer
    namespace: ${NS}
roleRef:
  kind: Role
  name: sakinaai-developer-readonly-plus-exec
  apiGroup: rbac.authorization.k8s.io
YAML

section "4. Quotas and limits"

cat <<YAML | apply_yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: sakinaai-prod-quota
  namespace: ${NS}
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "40"
    persistentvolumeclaims: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: sakinaai-prod-default-limits
  namespace: ${NS}
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        cpu: 500m
        memory: 512Mi
      max:
        cpu: "4"
        memory: 4Gi
YAML

section "5. ConfigMap and Secret"

cat <<YAML | apply_yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sakinaai-config
  namespace: ${NS}
data:
  NODE_ENV: "production"
  APP_NAME: "SakinaAI"
  APP_REGION: "uk"
  LOG_LEVEL: "info"
  REDIS_HOST: "sakinaai-redis"
  REDIS_PORT: "6379"
  API_PUBLIC_BASE_URL: "https://${API_HOST}"
  ADMIN_PUBLIC_BASE_URL: "https://${ADMIN_HOST}"
  SUPABASE_STORAGE_BUCKET_PUBLIC: "sakinaai-public-assets"
  SUPABASE_STORAGE_BUCKET_UPLOADS: "sakinaai-user-uploads"
  SUPABASE_STORAGE_BUCKET_BACKUPS: "sakinaai-backups"
  AI_PROVIDER_MODE: "local-or-gateway"
  AI_GATEWAY_URL: "${AI_GATEWAY_URL}"
YAML

kubectl -n "${NS}" create secret generic sakinaai-secrets \
  --from-literal=SUPABASE_URL="${SUPABASE_URL}" \
  --from-literal=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --from-literal=SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}" \
  --from-literal=DATABASE_URL="${DATABASE_URL}" \
  --from-literal=JWT_SECRET="${JWT_SECRET}" \
  --from-literal=APPLE_CLIENT_ID="${APPLE_CLIENT_ID}" \
  --from-literal=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  --from-literal=AI_GATEWAY_API_KEY="${AI_GATEWAY_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created/updated. Values not printed."

section "6. Supabase Storage buckets"

if [[ "$CREATE_SUPABASE_BUCKETS" == "true" ]]; then
  create_bucket() {
    local bucket="$1"
    local public_flag="$2"

    echo "Creating/checking bucket: ${bucket}"

    http_code="$(curl -sS -o /tmp/sakinaai_bucket_response.json -w "%{http_code}" \
      -X POST "${SUPABASE_URL}/storage/v1/bucket" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      --data "{\"id\":\"${bucket}\",\"name\":\"${bucket}\",\"public\":${public_flag},\"file_size_limit\":52428800}")" || true

    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
      echo "Bucket created: ${bucket}"
    elif grep -qi "already exists\|Duplicate" /tmp/sakinaai_bucket_response.json 2>/dev/null; then
      echo "Bucket already exists: ${bucket}"
    else
      echo "WARNING: bucket response HTTP ${http_code} for ${bucket}"
      cat /tmp/sakinaai_bucket_response.json || true
    fi
  }

  create_bucket "sakinaai-public-assets" "true"
  create_bucket "sakinaai-user-uploads" "false"
  create_bucket "sakinaai-backups" "false"
else
  echo "Supabase buckets skipped."
fi

section "7. Redis"

cat <<YAML | apply_yaml
apiVersion: v1
kind: Service
metadata:
  name: sakinaai-redis
  namespace: ${NS}
  labels:
    app: sakinaai-redis
spec:
  type: ClusterIP
  selector:
    app: sakinaai-redis
  ports:
    - name: redis
      port: 6379
      targetPort: 6379
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sakinaai-redis
  namespace: ${NS}
spec:
  serviceName: sakinaai-redis
  replicas: 1
  selector:
    matchLabels:
      app: sakinaai-redis
  template:
    metadata:
      labels:
        app: sakinaai-redis
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
      containers:
        - name: redis
          image: redis:7.4-alpine
          imagePullPolicy: IfNotPresent
          args: ["redis-server", "--appendonly", "yes", "--save", "60", "1000"]
          ports:
            - containerPort: 6379
              name: redis
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: redis-data
              mountPath: /data
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["redis-cli", "ping"]
            initialDelaySeconds: 20
            periodSeconds: 20
  volumeClaimTemplates:
    - metadata:
        name: redis-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
YAML

section "8. API, Admin Web, Worker"

cat <<YAML | apply_yaml
apiVersion: v1
kind: Service
metadata:
  name: sakinaai-api
  namespace: ${NS}
  labels:
    app: sakinaai-api
spec:
  type: ClusterIP
  selector:
    app: sakinaai-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sakinaai-api
  namespace: ${NS}
  labels:
    app: sakinaai-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sakinaai-api
  template:
    metadata:
      labels:
        app: sakinaai-api
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: sakinaai-api
          image: ${API_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
          envFrom:
            - configMapRef:
                name: sakinaai-config
            - secretRef:
                name: sakinaai-secrets
          env:
            - name: PORT
              value: "8080"
          resources:
            requests:
              cpu: 250m
              memory: 384Mi
            limits:
              cpu: "1"
              memory: 1Gi
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 15
            timeoutSeconds: 3
            periodSeconds: 10
            failureThreshold: 6
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            timeoutSeconds: 3
            periodSeconds: 20
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
---
apiVersion: v1
kind: Service
metadata:
  name: sakinaai-admin-web
  namespace: ${NS}
  labels:
    app: sakinaai-admin-web
spec:
  type: ClusterIP
  selector:
    app: sakinaai-admin-web
  ports:
    - name: http
      port: 3000
      targetPort: 3000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sakinaai-admin-web
  namespace: ${NS}
  labels:
    app: sakinaai-admin-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sakinaai-admin-web
  template:
    metadata:
      labels:
        app: sakinaai-admin-web
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: sakinaai-admin-web
          image: ${ADMIN_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: http
          envFrom:
            - configMapRef:
                name: sakinaai-config
            - secretRef:
                name: sakinaai-secrets
          env:
            - name: PORT
              value: "3000"
          resources:
            requests:
              cpu: 150m
              memory: 256Mi
            limits:
              cpu: "1"
              memory: 1Gi
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 20
            timeoutSeconds: 3
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 40
            timeoutSeconds: 3
            periodSeconds: 20
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sakinaai-worker
  namespace: ${NS}
  labels:
    app: sakinaai-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sakinaai-worker
  template:
    metadata:
      labels:
        app: sakinaai-worker
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: sakinaai-worker
          image: ${WORKER_IMAGE}
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: sakinaai-config
            - secretRef:
                name: sakinaai-secrets
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 2Gi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
YAML

section "9. HPA"

cat <<YAML | apply_yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sakinaai-api-hpa
  namespace: ${NS}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sakinaai-api
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 65
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 75
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sakinaai-worker-hpa
  namespace: ${NS}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sakinaai-worker
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
YAML

section "10. Network Policies"

cat <<YAML | apply_yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sakinaai-default-deny-ingress
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-api-and-admin
  namespace: ${NS}
spec:
  podSelector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - sakinaai-api
          - sakinaai-admin-web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 3000
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-apps-to-redis
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: sakinaai-redis
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - sakinaai-api
                  - sakinaai-worker
                  - sakinaai-smoke-test
      ports:
        - protocol: TCP
          port: 6379
YAML

section "11. Ingress"

cat <<YAML | apply_yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sakinaai-ingress
  namespace: ${NS}
  annotations:
    kubernetes.io/ingress.class: ${INGRESS_CLASS}
    cert-manager.io/cluster-issuer: ${CERT_MANAGER_ISSUER}
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  tls:
    - hosts:
        - ${API_HOST}
        - ${ADMIN_HOST}
      secretName: sakinaai-tls
  rules:
    - host: ${API_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sakinaai-api
                port:
                  number: 8080
    - host: ${ADMIN_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sakinaai-admin-web
                port:
                  number: 3000
YAML

section "12. Backup CronJob"

cat <<YAML | apply_yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sakinaai-supabase-db-backup
  namespace: ${NS}
spec:
  schedule: "${BACKUP_SCHEDULE}"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: postgres:16-alpine
              imagePullPolicy: IfNotPresent
              envFrom:
                - secretRef:
                    name: sakinaai-secrets
                - configMapRef:
                    name: sakinaai-config
              command:
                - sh
                - -c
                - |
                  set -eu
                  apk add --no-cache curl gzip >/dev/null
                  TS="\$(date -u +%Y%m%dT%H%M%SZ)"
                  FILE="/tmp/sakinaai-db-\${TS}.sql.gz"
                  echo "Starting pg_dump backup at \${TS}"
                  pg_dump "\$DATABASE_URL" | gzip > "\$FILE"
                  echo "Uploading backup to Supabase Storage"
                  curl -fsS -X POST "\${SUPABASE_URL}/storage/v1/object/\${SUPABASE_STORAGE_BUCKET_BACKUPS}/db/\${TS}.sql.gz" \
                    -H "Authorization: Bearer \${SUPABASE_SERVICE_ROLE_KEY}" \
                    -H "apikey: \${SUPABASE_SERVICE_ROLE_KEY}" \
                    -H "Content-Type: application/gzip" \
                    --data-binary @"\$FILE"
                  echo "Backup uploaded"
YAML

section "13. Optional Cloudflare DNS"

if [[ "$CONFIGURE_CLOUDFLARE_DNS" == "true" ]]; then
  [[ -n "$CF_API_TOKEN" ]] || fail "Missing CF_API_TOKEN"
  [[ -n "$CF_ZONE_ID" ]] || fail "Missing CF_ZONE_ID"
  [[ -n "$CLUSTER_PUBLIC_IP" ]] || fail "Missing CLUSTER_PUBLIC_IP"

  create_or_update_cf_record() {
    local name="$1"
    local type="A"
    local content="$CLUSTER_PUBLIC_IP"

    existing_id="$(curl -fsS -X GET \
      "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=${type}&name=${name}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json" | jq -r '.result[0].id // empty')"

    if [[ -n "$existing_id" ]]; then
      echo "Updating DNS: ${name} -> ${content}"
      curl -fsS -X PUT \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${existing_id}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"ttl\":120,\"proxied\":false}" >/dev/null
    else
      echo "Creating DNS: ${name} -> ${content}"
      curl -fsS -X POST \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"ttl\":120,\"proxied\":false}" >/dev/null
    fi
  }

  create_or_update_cf_record "${API_HOST}"
  create_or_update_cf_record "${ADMIN_HOST}"
else
  echo "Cloudflare DNS skipped."
fi

section "14. Rollout"

if [[ "$WAIT_FOR_ROLLOUT" == "true" ]]; then
  kubectl -n "${NS}" rollout status statefulset/sakinaai-redis --timeout=180s || true
  kubectl -n "${NS}" rollout status deploy/sakinaai-api --timeout=180s || true
  kubectl -n "${NS}" rollout status deploy/sakinaai-admin-web --timeout=180s || true
  kubectl -n "${NS}" rollout status deploy/sakinaai-worker --timeout=180s || true
fi

section "15. Smoke test"

if [[ "$RUN_SMOKE_TEST" == "true" ]]; then
  kubectl -n "${NS}" delete job sakinaai-smoke-test --ignore-not-found=true

  cat <<YAML | apply_yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sakinaai-smoke-test
  namespace: ${NS}
spec:
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        app: sakinaai-smoke-test
    spec:
      restartPolicy: Never
      containers:
        - name: smoke-test
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              set -e
              echo "Testing API health..."
              wget -qO- http://sakinaai-api:8080/health
              echo "Testing API readiness..."
              wget -qO- http://sakinaai-api:8080/ready
              echo "Testing Redis TCP..."
              nc -vz -w 5 sakinaai-redis 6379
              echo "PASS: SakinaAI internal smoke test completed"
YAML

  kubectl -n "${NS}" wait --for=condition=complete job/sakinaai-smoke-test --timeout=120s || true
  kubectl -n "${NS}" logs job/sakinaai-smoke-test || true
fi

section "16. Final status"

kubectl get ns "${NS}" "${MONITORING_NS}" || true
kubectl get all -n "${NS}" || true
kubectl get ingress -n "${NS}" || true
kubectl get networkpolicy -n "${NS}" || true
kubectl get hpa -n "${NS}" || true
kubectl get cronjob -n "${NS}" || true
kubectl get pvc -n "${NS}" || true

section "17. Developer handover"

cat <<EOF

SakinaAI infrastructure completed.

Namespace:
  ${NS}

Internal services:
  API:        http://sakinaai-api.${NS}.svc.cluster.local:8080
  Admin Web: http://sakinaai-admin-web.${NS}.svc.cluster.local:3000
  Redis:     sakinaai-redis.${NS}.svc.cluster.local:6379

Public endpoints:
  https://${API_HOST}
  https://${ADMIN_HOST}

Developer account:
  sakinaai-developer

Create developer token:
  kubectl -n ${NS} create token sakinaai-developer

Useful commands:
  kubectl get pods -n ${NS}
  kubectl get svc -n ${NS}
  kubectl get ingress -n ${NS}
  kubectl logs -n ${NS} deploy/sakinaai-api --tail=100
  kubectl logs -n ${NS} deploy/sakinaai-worker --tail=100

Important:
  - If pods show ImagePullBackOff, your Docker images do not exist or registry auth is missing.
  - If TLS is not issued, check cert-manager and DNS.
  - If smoke test fails, check whether API exposes /health and /ready.
  - Developer RBAC cannot read Kubernetes secrets.

EOF

echo "DONE."
