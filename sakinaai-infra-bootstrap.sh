#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " SAKINA AI INFRA BOOTSTRAP"
echo "=================================================="

APP_NAME="sakina"
APP_NS="sakina-prod"
DEV_NS="sakina-dev"
STAGING_NS="sakina-staging"
MONITORING_NS="sakina-monitoring"
INGRESS_NS="sakina-ingress"
SECURITY_NS="sakina-security"

FRONTEND_APP="sakina-frontend"
BACKEND_APP="sakina-backend"

FRONTEND_IMAGE="${FRONTEND_IMAGE:-ghcr.io/serverax/sakina-frontend:replace-with-real-tag}"
BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/serverax/sakina-backend:replace-with-real-tag}"

ADMIN_HOST="${ADMIN_HOST:-admin.sakinaapp.com}"
API_HOST="${API_HOST:-api.sakinaapp.com}"

INGRESS_CLASS="${INGRESS_CLASS:-traefik}"
CLUSTER_ISSUER="${CLUSTER_ISSUER:-letsencrypt-prod}"

FRONTEND_PORT="80"
BACKEND_PORT="8080"

echo "Using:"
echo "  APP_NS=$APP_NS"
echo "  DEV_NS=$DEV_NS"
echo "  STAGING_NS=$STAGING_NS"
echo "  MONITORING_NS=$MONITORING_NS"
echo "  ADMIN_HOST=$ADMIN_HOST"
echo "  API_HOST=$API_HOST"
echo "  FRONTEND_IMAGE=$FRONTEND_IMAGE"
echo "  BACKEND_IMAGE=$BACKEND_IMAGE"
echo ""

echo "Checking kubectl access..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

kubectl version --client >/dev/null

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach the Kubernetes cluster."
  echo "Check your kubeconfig first."
  exit 1
fi

echo "kubectl access OK."
echo ""

echo "Creating namespaces..."

kubectl apply -f - <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NS}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${DEV_NS}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/environment: development
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${STAGING_NS}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/environment: staging
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${MONITORING_NS}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/component: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${INGRESS_NS}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/component: ingress
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${SECURITY_NS}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/component: security
YAML

echo "Creating ConfigMaps..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sakina-frontend-config
data:
  APP_ENV: "production"
  APP_NAME: "SakinaAI"
  API_BASE_URL: "https://${API_HOST}"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: sakina-backend-config
data:
  APP_ENV: "production"
  RUST_LOG: "info"
  SERVER_HOST: "0.0.0.0"
  SERVER_PORT: "${BACKEND_PORT}"
  CORS_ALLOWED_ORIGINS: "https://${ADMIN_HOST}"
YAML

echo "Creating placeholder secrets..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: sakina-supabase-secret
type: Opaque
stringData:
  SUPABASE_URL: "replace-with-real-supabase-url"
  SUPABASE_DB_URL: "replace-with-real-supabase-db-url"
  SUPABASE_ANON_KEY: "replace-with-real-anon-key"
  SUPABASE_SERVICE_ROLE_KEY: "replace-with-real-service-role-key"
---
apiVersion: v1
kind: Secret
metadata:
  name: sakina-object-storage-secret
type: Opaque
stringData:
  OBJECT_STORAGE_ENDPOINT: "replace-with-real-endpoint"
  OBJECT_STORAGE_BUCKET: "sakina-prod"
  OBJECT_STORAGE_ACCESS_KEY: "replace-with-real-access-key"
  OBJECT_STORAGE_SECRET_KEY: "replace-with-real-secret-key"
  OBJECT_STORAGE_REGION: "eu-central-1"
YAML

echo "Creating service accounts and RBAC..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sakina-frontend-sa
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sakina-backend-sa
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sakina-deployer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sakina-deployer-role
rules:
  - apiGroups: ["", "apps", "networking.k8s.io", "autoscaling"]
    resources:
      - configmaps
      - services
      - deployments
      - replicasets
      - pods
      - ingresses
      - horizontalpodautoscalers
      - networkpolicies
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources:
      - secrets
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sakina-deployer-rolebinding
subjects:
  - kind: ServiceAccount
    name: sakina-deployer
    namespace: ${APP_NS}
roleRef:
  kind: Role
  name: sakina-deployer-role
  apiGroup: rbac.authorization.k8s.io
YAML

echo "Creating frontend Deployment and Service..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${FRONTEND_APP}
  labels:
    app: ${FRONTEND_APP}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${FRONTEND_APP}
  template:
    metadata:
      labels:
        app: ${FRONTEND_APP}
    spec:
      serviceAccountName: sakina-frontend-sa
      containers:
        - name: frontend
          image: ${FRONTEND_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: ${FRONTEND_PORT}
          envFrom:
            - configMapRef:
                name: sakina-frontend-config
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /
              port: ${FRONTEND_PORT}
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: ${FRONTEND_PORT}
            initialDelaySeconds: 30
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: ${FRONTEND_APP}
  labels:
    app: ${FRONTEND_APP}
spec:
  type: ClusterIP
  selector:
    app: ${FRONTEND_APP}
  ports:
    - name: http
      port: 80
      targetPort: ${FRONTEND_PORT}
YAML

echo "Creating backend Deployment and Service..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${BACKEND_APP}
  labels:
    app: ${BACKEND_APP}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${BACKEND_APP}
  template:
    metadata:
      labels:
        app: ${BACKEND_APP}
    spec:
      serviceAccountName: sakina-backend-sa
      containers:
        - name: backend
          image: ${BACKEND_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: ${BACKEND_PORT}
          envFrom:
            - configMapRef:
                name: sakina-backend-config
            - secretRef:
                name: sakina-supabase-secret
            - secretRef:
                name: sakina-object-storage-secret
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /ready
              port: ${BACKEND_PORT}
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: ${BACKEND_PORT}
            initialDelaySeconds: 30
            periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: ${BACKEND_APP}
  labels:
    app: ${BACKEND_APP}
spec:
  type: ClusterIP
  selector:
    app: ${BACKEND_APP}
  ports:
    - name: http
      port: 8080
      targetPort: ${BACKEND_PORT}
YAML

echo "Creating Ingress..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sakina-ingress
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: ${INGRESS_CLASS}
  tls:
    - hosts:
        - ${ADMIN_HOST}
        - ${API_HOST}
      secretName: sakina-tls
  rules:
    - host: ${ADMIN_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${FRONTEND_APP}
                port:
                  number: 80
    - host: ${API_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${BACKEND_APP}
                port:
                  number: 8080
YAML

echo "Creating HPA resources..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sakina-frontend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${FRONTEND_APP}
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sakina-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${BACKEND_APP}
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
YAML

echo "Creating NetworkPolicies..."

kubectl -n "${APP_NS}" apply -f - <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sakina-default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-frontend
spec:
  podSelector:
    matchLabels:
      app: ${FRONTEND_APP}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-backend
spec:
  podSelector:
    matchLabels:
      app: ${BACKEND_APP}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-egress
spec:
  podSelector:
    matchLabels:
      app: ${BACKEND_APP}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 5432
YAML

echo "Creating monitoring baseline..."

kubectl -n "${MONITORING_NS}" apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sakina-monitoring-baseline
data:
  monitoring_stack: "prometheus-grafana-loki-recommended"
  backend_metrics_path: "/metrics"
  backend_health_path: "/health"
  backend_ready_path: "/ready"
  frontend_health_path: "/"
YAML

echo "Creating security baseline..."

kubectl -n "${SECURITY_NS}" apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sakina-security-baseline
data:
  no_latest_images: "true"
  use_kubernetes_secrets: "true"
  service_role_key_frontend_exposure_allowed: "false"
  require_tls: "true"
  require_network_policies: "true"
  require_namespace_rbac: "true"
  production_namespace: "${APP_NS}"
YAML

echo ""
echo "=================================================="
echo " VERIFICATION"
echo "=================================================="

kubectl get ns | grep -E "sakina|NAME" || true

echo ""
echo "Resources in ${APP_NS}:"
kubectl -n "${APP_NS}" get deploy,svc,ingress,hpa,secret,configmap,networkpolicy || true

echo ""
echo "Pods in ${APP_NS}:"
kubectl -n "${APP_NS}" get pods -o wide || true

echo ""
echo "=================================================="
echo " NEXT STEPS"
echo "=================================================="
echo "1. Replace placeholder secrets."
echo "2. Replace placeholder Docker image tags."
echo "3. Configure DNS:"
echo "   ${ADMIN_HOST} -> 148.251.247.56"
echo "   ${API_HOST}   -> 148.251.247.56"
echo "4. Confirm cert-manager ClusterIssuer exists: ${CLUSTER_ISSUER}"
echo "5. Confirm ingress class exists: ${INGRESS_CLASS}"
echo "6. Confirm backend exposes /health, /ready, and /metrics."
echo "7. Confirm frontend container serves on port 80."
echo ""
echo "Bootstrap complete."
