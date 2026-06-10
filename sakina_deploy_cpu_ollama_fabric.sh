#!/usr/bin/env bash
set -euo pipefail

# Change this only if your active Sakina namespace is different.
NS="${NS:-sakina-mobile-staging}"

# Requested model first. Fallback is official Ollama tag.
REQUESTED_MODEL="${REQUESTED_MODEL:-qwen2.5:3b-instruct-q6_K}"
FALLBACK_MODEL="${FALLBACK_MODEL:-qwen2.5:3b-instruct}"

CPUSET="${CPUSET:-0-3}"

echo "============================================================"
echo "Sakina Sovereign Trinity - CPU Ollama Inference Fabric"
echo "Namespace:        $NS"
echo "Requested model:  $REQUESTED_MODEL"
echo "Fallback model:   $FALLBACK_MODEL"
echo "CPU pinning:      taskset -c $CPUSET"
echo "============================================================"

echo
echo "1) Confirm cluster access"
kubectl cluster-info
kubectl get nodes -o wide

NODE_COUNT="$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"
echo "Detected node count: $NODE_COUNT"

if [ "$NODE_COUNT" -lt 3 ]; then
  echo "FAIL: Expected 3-node cluster. Found $NODE_COUNT."
  exit 1
fi

echo
echo "2) Confirm namespace exists or create it"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

echo
echo "3) Create Sovereign Brain policy ConfigMap"
kubectl -n "$NS" apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sovereign-brain-policy
  labels:
    app.kubernetes.io/name: sovereign-brain-policy
    app.kubernetes.io/part-of: sakina
data:
  LLM_PROVIDER: "ollama-local"
  LLM_BASE_URL: "http://ollama-inference:11434"
  LLM_MODEL_REQUESTED: "$REQUESTED_MODEL"
  LLM_MODEL_FALLBACK: "$FALLBACK_MODEL"

  # Last resort routing mandate
  DETERMINISTIC_FIRST: "true"
  RULES_ENGINE_STAGE: "enabled"
  GRAPHRAG_STAGE: "enabled"
  LLM_LAST_RESORT_ONLY: "true"
  LLM_ESCALATE_ONLY_ON: "INSUFFICIENT_GROUNDING"

  # PII and citation gates
  REQUIRE_DEID_BEFORE_LLM: "true"
  REQUIRE_CITATION_UUID: "true"
  REQUIRE_SQL_CORPUS_UUID: "true"
  REJECT_UNCITED_LLM_OUTPUT: "true"
  NO_AI_AUTHORITY: "true"

  # Legal source authority
  LEGAL_SOURCE_AUTHORITY: "legal_corpus_registry"
  DOMAIN_WHITELIST: "legislation.gov.uk"
  CRAWLER_FAIL_CLOSED: "true"
  INGESTION_CRITIC_REQUIRED: "true"
  REJECT_UNAUTHORIZED_DOMAIN: "true"
  REJECT_MISSING_STATUTORY_REFERENCE: "true"

  # DSPy evolution mandate
  DSPY_CICD_ENABLED: "true"
  DSPY_EVOLVE_PROMPTS_FROM_FAILURES: "true"
  DSPY_NO_PROD_AUTO_PROMOTE_WITHOUT_TEST_PASS: "true"
YAML

echo
echo "4) Deploy Ollama DaemonSet and node-local Service"
kubectl -n "$NS" apply -f - <<YAML
apiVersion: v1
kind: Service
metadata:
  name: ollama-inference
  labels:
    app: ollama-inference
    app.kubernetes.io/part-of: sakina
spec:
  type: ClusterIP
  internalTrafficPolicy: Local
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
  labels:
    app: ollama-inference
    app.kubernetes.io/part-of: sakina
spec:
  selector:
    matchLabels:
      app: ollama-inference
  template:
    metadata:
      labels:
        app: ollama-inference
        app.kubernetes.io/part-of: sakina
    spec:
      terminationGracePeriodSeconds: 30
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
              value: "/root/.ollama/models"
            - name: OLLAMA_NUM_PARALLEL
              value: "1"
            - name: OLLAMA_MAX_LOADED_MODELS
              value: "1"
            - name: OLLAMA_KEEP_ALIVE
              value: "24h"
            - name: CPUSET
              value: "$CPUSET"
          command:
            - /bin/sh
            - -lc
            - |
              set -eu
              echo "Starting Ollama with CPU pinning: taskset -c \${CPUSET}"
              if ! command -v taskset >/dev/null 2>&1; then
                echo "FAIL: taskset not found inside image. CPU pinning cannot be proven."
                exit 91
              fi
              exec taskset -c "\${CPUSET}" ollama serve
          resources:
            requests:
              cpu: "4"
              memory: "6Gi"
            limits:
              cpu: "4"
              memory: "6Gi"
          volumeMounts:
            - name: ollama-model-cache
              mountPath: /root/.ollama
          readinessProbe:
            httpGet:
              path: /api/tags
              port: 11434
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 12
          livenessProbe:
            httpGet:
              path: /api/tags
              port: 11434
            initialDelaySeconds: 30
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 6
      volumes:
        - name: ollama-model-cache
          hostPath:
            path: /var/lib/sakina-ollama
            type: DirectoryOrCreate
YAML

echo
echo "5) Wait for Ollama DaemonSet rollout"
kubectl -n "$NS" rollout status ds/ollama-inference --timeout=10m
kubectl -n "$NS" get ds ollama-inference -o wide
kubectl -n "$NS" get pods -l app=ollama-inference -o wide

READY_COUNT="$(kubectl -n "$NS" get pods -l app=ollama-inference --no-headers | awk '$2 ~ /^1\/1/ {c++} END {print c+0}')"
if [ "$READY_COUNT" -ne "$NODE_COUNT" ]; then
  echo "FAIL: Expected $NODE_COUNT ready Ollama pods, found $READY_COUNT."
  exit 1
fi

echo
echo "6) Pull model on each node-local Ollama pod"
ACTIVE_MODEL=""
for POD in $(kubectl -n "$NS" get pods -l app=ollama-inference -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  NODE="$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.nodeName}')"
  echo "---- Pulling model on pod=$POD node=$NODE ----"

  set +e
  kubectl -n "$NS" exec "$POD" -- ollama pull "$REQUESTED_MODEL"
  RC=$?
  set -e

  if [ "$RC" -eq 0 ]; then
    ACTIVE_MODEL="$REQUESTED_MODEL"
  else
    echo "Requested model failed on $POD. Falling back to $FALLBACK_MODEL"
    kubectl -n "$NS" exec "$POD" -- ollama pull "$FALLBACK_MODEL"
    ACTIVE_MODEL="$FALLBACK_MODEL"
  fi

  kubectl -n "$NS" exec "$POD" -- ollama list
done

if [ -z "$ACTIVE_MODEL" ]; then
  echo "FAIL: No active model was pulled."
  exit 1
fi

echo "ACTIVE_MODEL=$ACTIVE_MODEL"

echo
echo "7) Patch backend with local Ollama and last-resort control env"
if kubectl -n "$NS" get deploy sakina-backend >/dev/null 2>&1; then
  kubectl -n "$NS" set env deploy/sakina-backend \
    LLM_PROVIDER="ollama-local" \
    OLLAMA_BASE_URL="http://ollama-inference:11434" \
    LLM_BASE_URL="http://ollama-inference:11434" \
    OLLAMA_MODEL="$ACTIVE_MODEL" \
    LLM_MODEL="$ACTIVE_MODEL" \
    DETERMINISTIC_FIRST="true" \
    RULES_ENGINE_STAGE="enabled" \
    GRAPHRAG_STAGE="enabled" \
    LLM_LAST_RESORT_ONLY="true" \
    LLM_ESCALATE_ONLY_ON="INSUFFICIENT_GROUNDING" \
    REQUIRE_DEID_BEFORE_LLM="true" \
    REQUIRE_CITATION_UUID="true" \
    REQUIRE_SQL_CORPUS_UUID="true" \
    REJECT_UNCITED_LLM_OUTPUT="true" \
    NO_AI_AUTHORITY="true" \
    LEGAL_SOURCE_AUTHORITY="legal_corpus_registry" \
    --overwrite

  kubectl -n "$NS" rollout restart deploy/sakina-backend
  kubectl -n "$NS" rollout status deploy/sakina-backend --timeout=10m
else
  echo "WARN: deploy/sakina-backend not found in namespace $NS. Backend not patched."
fi

echo
echo "8) Patch RAG ingestion/crawler service with whitelist and critic gate"
if kubectl -n "$NS" get deploy sakina-rag-ingestion >/dev/null 2>&1; then
  kubectl -n "$NS" set env deploy/sakina-rag-ingestion \
    DOMAIN_WHITELIST="legislation.gov.uk" \
    CRAWLER_FAIL_CLOSED="true" \
    INGESTION_CRITIC_REQUIRED="true" \
    REJECT_UNAUTHORIZED_DOMAIN="true" \
    REJECT_MISSING_STATUTORY_REFERENCE="true" \
    NO_AI_AUTHORITY="true" \
    LEGAL_SOURCE_AUTHORITY="legal_corpus_registry" \
    --overwrite

  kubectl -n "$NS" rollout restart deploy/sakina-rag-ingestion
  kubectl -n "$NS" rollout status deploy/sakina-rag-ingestion --timeout=10m
else
  echo "WARN: deploy/sakina-rag-ingestion not found in namespace $NS. RAG ingestion not patched."
fi

echo
echo "9) Deploy node-local benchmark DaemonSet"
kubectl -n "$NS" delete ds ollama-node-benchmark --ignore-not-found=true

kubectl -n "$NS" apply -f - <<YAML
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ollama-node-benchmark
  labels:
    app: ollama-node-benchmark
spec:
  selector:
    matchLabels:
      app: ollama-node-benchmark
  template:
    metadata:
      labels:
        app: ollama-node-benchmark
    spec:
      restartPolicy: Always
      terminationGracePeriodSeconds: 5
      containers:
        - name: bench
          image: python:3.12-alpine
          imagePullPolicy: IfNotPresent
          env:
            - name: MODEL
              value: "$ACTIVE_MODEL"
            - name: OLLAMA_URL
              value: "http://ollama-inference:11434/api/generate"
          command:
            - /bin/sh
            - -lc
            - |
              python - <<'PY'
              import json, os, time, urllib.request, statistics, socket

              model = os.environ["MODEL"]
              url = os.environ["OLLAMA_URL"]

              payload = {
                  "model": model,
                  "stream": False,
                  "format": "json",
                  "options": {
                      "temperature": 0,
                      "num_predict": 24
                  },
                  "prompt": "Extract JSON only: claimant=Ali, days_since_dismissal=80, jurisdiction=England. Return keys claimant, days_since_dismissal, jurisdiction."
              }

              def call_once():
                  data = json.dumps(payload).encode()
                  req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
                  start = time.perf_counter()
                  with urllib.request.urlopen(req, timeout=120) as r:
                      body = r.read().decode()
                  elapsed_ms = (time.perf_counter() - start) * 1000
                  return elapsed_ms, body

              print("BENCH_START host=", socket.gethostname(), "model=", model, flush=True)

              # Warmup loads model into memory. Not counted.
              try:
                  ms, _ = call_once()
                  print("WARMUP_MS", round(ms, 2), flush=True)
              except Exception as e:
                  print("BENCH_FAIL warmup_error=", repr(e), flush=True)
                  time.sleep(3600)
                  raise SystemExit(1)

              samples = []
              for i in range(20):
                  try:
                      ms, body = call_once()
                      samples.append(ms)
                      print("SAMPLE", i + 1, round(ms, 2), flush=True)
                  except Exception as e:
                      print("SAMPLE_FAIL", i + 1, repr(e), flush=True)

              if not samples:
                  print("BENCH_FAIL no_samples", flush=True)
                  time.sleep(3600)
                  raise SystemExit(1)

              ordered = sorted(samples)
              p95 = ordered[int(0.95 * (len(ordered)-1))]
              avg = statistics.mean(samples)
              status = "PASS" if p95 < 300 else "FAIL"

              print("BENCH_RESULT", json.dumps({
                  "host": socket.gethostname(),
                  "model": model,
                  "samples": len(samples),
                  "avg_ms": round(avg, 2),
                  "p95_ms": round(p95, 2),
                  "threshold_ms": 300,
                  "status": status
              }), flush=True)

              time.sleep(3600)
              PY
YAML

echo
echo "10) Wait for benchmark pods"
sleep 20
kubectl -n "$NS" get pods -l app=ollama-node-benchmark -o wide

echo
echo "11) Benchmark logs"
for POD in $(kubectl -n "$NS" get pods -l app=ollama-node-benchmark -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  NODE="$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.nodeName}')"
  echo
  echo "================ BENCHMARK pod=$POD node=$NODE ================"
  kubectl -n "$NS" logs "$POD" --tail=80 || true
done

echo
echo "12) CPU pinning proof from Ollama pods"
for POD in $(kubectl -n "$NS" get pods -l app=ollama-inference -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  NODE="$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.nodeName}')"
  echo
  echo "================ CPU PROOF pod=$POD node=$NODE ================"
  kubectl -n "$NS" exec "$POD" -- sh -lc '
    echo "taskset location:"
    command -v taskset || true
    echo "ollama process:"
    ps -o pid,comm,args | grep "[o]llama" || true
    PID="$(pidof ollama || true)"
    if [ -n "$PID" ]; then
      echo "Cpus_allowed_list:"
      grep Cpus_allowed_list /proc/$PID/status || true
    else
      echo "FAIL: ollama PID not found"
    fi
  '
done

echo
echo "13) Service proof"
kubectl -n "$NS" get svc ollama-inference -o yaml | sed -n '1,120p'
kubectl -n "$NS" get endpointslice -l kubernetes.io/service-name=ollama-inference -o wide || true

echo
echo "14) Final pod status"
kubectl -n "$NS" get deploy,ds,sts,pods,svc -o wide

echo
echo "============================================================"
echo "DONE: Fabric deployment script finished."
echo
echo "No fake PASS rule:"
echo "- If all Ollama pods are 1/1 and one exists per node, Body/Fabric is deployed."
echo "- If ollama list shows the active model on every pod, lite CPU LLM is installed."
echo "- If Cpus_allowed_list is $CPUSET or equivalent allowed CPU set, taskset pinning is proven."
echo "- If benchmark BENCH_RESULT is PASS on all 3 nodes, P95 < 300ms is proven."
echo "- If benchmark fails, the LLM still works, but the 300ms mandate is not met."
echo "============================================================"
