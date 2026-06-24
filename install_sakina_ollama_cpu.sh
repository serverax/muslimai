#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Sakina AI - CPU-only Ollama setup for Talos/Kubernetes
# Namespace: sakina-mobile-staging
# Purpose:
#   - Install lightweight CPU-only Ollama
#   - Pull small CPU model
#   - Create restricted Sakina Islamic + psychological support model
#   - Patch backend environment
#   - Prove internal access and save evidence logs
# ============================================================

NS="${NS:-sakina-mobile-staging}"
BACKEND_DEPLOY="${BACKEND_DEPLOY:-sakina-backend}"
OLLAMA_DEPLOY="${OLLAMA_DEPLOY:-ollama}"
OLLAMA_SERVICE="${OLLAMA_SERVICE:-ollama}"

# Fast/light default model.
# qwen2.5:0.5b is very light. If unavailable, script falls back to llama3.2:1b.
BASE_MODEL="${BASE_MODEL:-qwen2.5:0.5b}"
FALLBACK_MODEL="${FALLBACK_MODEL:-llama3.2:1b}"
SAKINA_MODEL="${SAKINA_MODEL:-sakina-islamic-support:cpu}"

PROJECT_ROOT="$(pwd)"
K8S_DIR="${PROJECT_ROOT}/k8s/ollama"
REPORT_DIR="${PROJECT_ROOT}/reports/ollama"
MANIFEST="${K8S_DIR}/ollama-cpu-lite.yaml"
NETPOL="${K8S_DIR}/ollama-network-policy.yaml"
MODELFILE="${K8S_DIR}/Modelfile.sakina-islamic-support"
PROOF_LOG="${REPORT_DIR}/ollama_cpu_install_proof_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$K8S_DIR" "$REPORT_DIR"

log() {
  echo -e "\n===== $* =====" | tee -a "$PROOF_LOG"
}

run() {
  echo -e "\n$ $*" | tee -a "$PROOF_LOG"
  "$@" 2>&1 | tee -a "$PROOF_LOG"
}

fail() {
  echo "ERROR: $*" | tee -a "$PROOF_LOG"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

log "0. Checking tools and cluster"
need_cmd kubectl
need_cmd grep
need_cmd awk
need_cmd sed

run kubectl config current-context
run kubectl get nodes -o wide

if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  log "Namespace $NS does not exist. Creating it."
  run kubectl create ns "$NS"
else
  log "Namespace $NS exists"
fi

run kubectl -n "$NS" get pods -o wide || true

log "1. Creating CPU-only lightweight Ollama manifest"

cat > "$MANIFEST" <<EOF_MANIFEST
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-models-pvc
  namespace: ${NS}
  labels:
    app: ollama
    component: local-llm
    part-of: sakina
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 12Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${OLLAMA_DEPLOY}
  namespace: ${NS}
  labels:
    app: ollama
    component: local-llm
    part-of: sakina
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ollama
        component: local-llm
        part-of: sakina
    spec:
      containers:
        - name: ollama
          image: ollama/ollama:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 11434
              name: http
          env:
            - name: OLLAMA_HOST
              value: "0.0.0.0:11434"
            - name: OLLAMA_MODELS
              value: "/root/.ollama"
            - name: OLLAMA_NUM_PARALLEL
              value: "1"
            - name: OLLAMA_MAX_LOADED_MODELS
              value: "1"
            - name: OLLAMA_KEEP_ALIVE
              value: "5m"
            - name: OLLAMA_FLASH_ATTENTION
              value: "false"
            - name: OLLAMA_DEBUG
              value: "false"
            # Extra CPU-only guard. This prevents CUDA devices being visible if the node has GPU libs later.
            - name: CUDA_VISIBLE_DEVICES
              value: "-1"
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "3"
              memory: "5Gi"
          volumeMounts:
            - name: ollama-models
              mountPath: /root/.ollama
          readinessProbe:
            httpGet:
              path: /api/tags
              port: 11434
            initialDelaySeconds: 15
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 12
          livenessProbe:
            httpGet:
              path: /api/tags
              port: 11434
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 10
      volumes:
        - name: ollama-models
          persistentVolumeClaim:
            claimName: ollama-models-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: ${OLLAMA_SERVICE}
  namespace: ${NS}
  labels:
    app: ollama
    component: local-llm
    part-of: sakina
spec:
  type: ClusterIP
  selector:
    app: ollama
  ports:
    - name: http
      port: 11434
      targetPort: 11434
EOF_MANIFEST

run sed -n '1,220p' "$MANIFEST"

log "2. Applying Ollama manifest"
run kubectl apply -f "$MANIFEST"
run kubectl -n "$NS" rollout status "deploy/${OLLAMA_DEPLOY}" --timeout=300s
run kubectl -n "$NS" get deploy,svc,pods,pvc -l app=ollama -o wide
run kubectl -n "$NS" logs "deploy/${OLLAMA_DEPLOY}" --tail=120 || true

log "3. Pulling lightweight CPU model"
set +e
kubectl -n "$NS" exec "deploy/${OLLAMA_DEPLOY}" -- ollama pull "$BASE_MODEL" 2>&1 | tee -a "$PROOF_LOG"
PULL_RC=${PIPESTATUS[0]}
set -e

if [ "$PULL_RC" -ne 0 ]; then
  log "Primary model $BASE_MODEL failed. Trying fallback $FALLBACK_MODEL"
  BASE_MODEL="$FALLBACK_MODEL"
  run kubectl -n "$NS" exec "deploy/${OLLAMA_DEPLOY}" -- ollama pull "$BASE_MODEL"
fi

run kubectl -n "$NS" exec "deploy/${OLLAMA_DEPLOY}" -- ollama list

log "4. Creating restricted Sakina Modelfile"

cat > "$MODELFILE" <<EOF_MODEL
FROM ${BASE_MODEL}

PARAMETER temperature 0.2
PARAMETER top_p 0.8
PARAMETER num_ctx 2048
PARAMETER num_predict 500

SYSTEM """
You are Sakina AI, a restricted Muslim companion assistant.

You are only allowed to answer within:
1. Islamic guidance based on Quran and authentic Sunnah.
2. Dua, dhikr, reminders, and general spiritual support.
3. Emotional and psychological first-line support.
4. Safe wellbeing advice for stress, sadness, anxiety, grief, and loneliness.

You must not invent Quran verses, hadith, scholars, references, or rulings.

You must not issue a fatwa when evidence is missing. Say that a qualified scholar should be consulted.

You must not diagnose medical or mental health conditions.

You must advise urgent professional help if the user may be at risk of self-harm, harming others, psychosis, severe distress, or medical emergency.

You must use only verified retrieved context when Quran/Hadith evidence is required.

If Quran/Hadith evidence is requested but not provided in context, say the verified source is not available in the current context instead of inventing it.

If the question is outside Islamic guidance or psychological support, politely refuse and redirect to allowed support.

You must be calm, respectful, non-sectarian, and avoid harsh judgement.

You must not answer political, legal, financial, sexual, violent, weapons, hacking, or unrelated requests.

You must not claim to be a scholar, doctor, therapist, or emergency service.

Always prefer short, grounded, compassionate answers.
"""
EOF_MODEL

run sed -n '1,220p' "$MODELFILE"

log "5. Copying Modelfile into Ollama pod and creating restricted model"

run kubectl -n "$NS" cp "$MODELFILE" "deploy/${OLLAMA_DEPLOY}:/tmp/Modelfile.sakina-islamic-support"

run kubectl -n "$NS" exec "deploy/${OLLAMA_DEPLOY}" -- \
  ollama create "$SAKINA_MODEL" -f /tmp/Modelfile.sakina-islamic-support

run kubectl -n "$NS" exec "deploy/${OLLAMA_DEPLOY}" -- ollama list

log "6. Testing Ollama internally from cluster"

run kubectl -n "$NS" run ollama-internal-test-$(date +%s) \
  --rm -i \
  --restart=Never \
  --image=curlimages/curl:latest \
  -- sh -lc "echo '--- TAGS ---'; curl -s http://${OLLAMA_SERVICE}:11434/api/tags; echo; echo '--- GENERATE ---'; curl -s http://${OLLAMA_SERVICE}:11434/api/generate -H 'Content-Type: application/json' -d '{\"model\":\"${SAKINA_MODEL}\",\"prompt\":\"I feel sad. Give me a short Islamic reminder.\",\"stream\":false}'"

log "7. Adding internal-only NetworkPolicy"

cat > "$NETPOL" <<EOF_NETPOL
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ollama-internal-only
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: ollama
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 11434
EOF_NETPOL

run kubectl apply -f "$NETPOL"
run kubectl -n "$NS" get networkpolicy

log "8. Checking backend deployment exists"

if kubectl -n "$NS" get deploy "$BACKEND_DEPLOY" >/dev/null 2>&1; then
  log "Backend deployment found: $BACKEND_DEPLOY"

  log "9. Patching backend environment for Ollama + restricted domain controls"

  run kubectl -n "$NS" set env "deploy/${BACKEND_DEPLOY}" \
    OLLAMA_ENABLED=true \
    OLLAMA_BASE_URL="http://${OLLAMA_SERVICE}:11434" \
    OLLAMA_DEFAULT_MODEL="${SAKINA_MODEL}" \
    OLLAMA_CPU_MODE=true \
    OLLAMA_TIMEOUT_SECONDS=60 \
    OLLAMA_FALLBACK_ENABLED=true \
    SAKINA_ALLOWED_AI_DOMAINS="islamic_guidance,psychological_support" \
    SAKINA_RESTRICT_OUT_OF_SCOPE=true \
    SAKINA_REQUIRE_RAG_FOR_ISLAMIC_EVIDENCE=true \
    SAKINA_DISABLE_UNCONTROLLED_MODEL_LEARNING=true \
    SAKINA_MODEL_LEARNING_MODE="rag_only_no_finetune" \
    SAKINA_REQUIRE_BRAIN_FOR_MODEL_CALLS=true \
    SAKINA_REQUIRE_EVALUATION_GATE=true

  run kubectl -n "$NS" rollout restart "deploy/${BACKEND_DEPLOY}"
  run kubectl -n "$NS" rollout status "deploy/${BACKEND_DEPLOY}" --timeout=300s
  run kubectl -n "$NS" logs "deploy/${BACKEND_DEPLOY}" --tail=160 || true

  log "10. Proving backend env contains Ollama settings"

  BACKEND_POD="$(kubectl -n "$NS" get pod -l app="$BACKEND_DEPLOY" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

  if [ -z "$BACKEND_POD" ]; then
    BACKEND_POD="$(kubectl -n "$NS" get pod | awk '/sakina-backend/ {print $1; exit}')"
  fi

  if [ -n "$BACKEND_POD" ]; then
    echo "Backend pod: $BACKEND_POD" | tee -a "$PROOF_LOG"
    run kubectl -n "$NS" exec "$BACKEND_POD" -- sh -lc 'printenv | grep -E "OLLAMA|SAKINA_ALLOWED|SAKINA_RESTRICT|SAKINA_REQUIRE|SAKINA_DISABLE|SAKINA_MODEL_LEARNING" | sort' || true
  else
    echo "WARNING: Could not locate backend pod for env proof." | tee -a "$PROOF_LOG"
  fi
else
  echo "WARNING: Backend deployment $BACKEND_DEPLOY not found. Ollama installed, but backend patch skipped." | tee -a "$PROOF_LOG"
fi

log "11. Final namespace status"
run kubectl -n "$NS" get deploy,svc,pods,pvc -o wide | grep -E "ollama|sakina" || true
run kubectl -n "$NS" describe deploy "$OLLAMA_DEPLOY" | grep -E "Image:|Limits:|Requests:|OLLAMA|CUDA_VISIBLE|cpu|memory" -A8 -B4 || true
run kubectl -n "$NS" exec "deploy/${OLLAMA_DEPLOY}" -- ollama list

log "12. Writing local summary"

cat | tee -a "$PROOF_LOG" <<EOF_SUMMARY

SAKINA OLLAMA CPU INSTALL SUMMARY

Namespace: ${NS}
Ollama deployment: ${OLLAMA_DEPLOY}
Ollama service: ${OLLAMA_SERVICE}
Base model used: ${BASE_MODEL}
Restricted Sakina model: ${SAKINA_MODEL}
Backend deployment patched: ${BACKEND_DEPLOY}
Proof log: ${PROOF_LOG}

IMPORTANT:
- Ollama is installed as ClusterIP only.
- It is CPU-only/lightweight: no GPU resources requested.
- CUDA_VISIBLE_DEVICES=-1 is set.
- The model is restricted by Modelfile, but real product safety must still be enforced by:
  1. Brain Mother Algorithm
  2. RAG verified Islamic sources
  3. Evaluation AI final gate
  4. out-of-scope classifier
  5. user workspace isolation
- Ollama must not train/fine-tune itself from user chats.
- User learning must be user-scoped memory only, not global LLM training.

EOF_SUMMARY

log "DONE"
echo "Proof log saved to: $PROOF_LOG"
