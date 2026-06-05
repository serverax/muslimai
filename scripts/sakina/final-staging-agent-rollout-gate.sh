#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'STAGING_AGENT_ROLLOUT_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd kubectl
require_cmd python3
require_cmd jq
require_cmd psql

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

NS="${SAKINA_NS:-sakina-mobile-staging}"
KUSTOMIZE_DIR="${SAKINA_KUSTOMIZE_DIR:-infra/k8s/sakina-mobile-staging}"
EVIDENCE_DIR="reports/final-hardening-evidence"
mkdir -p "$EVIDENCE_DIR"

if [[ -z "${KUBECONFIG:-}" && -f /mnt/c/Users/kalsh/.kube/config-hetzner ]]; then
  export KUBECONFIG=/mnt/c/Users/kalsh/.kube/config-hetzner
fi

cleanup_pids=()
cleanup() {
  set +e
  for pid in "${cleanup_pids[@]}"; do
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
}
trap cleanup EXIT

printf '=== STARTING AGENTIC ROLLOUT VERIFICATION ===\n'

printf 'Checking Kubernetes RBAC for deployment creation in %s...\n' "$NS"
can_create="$(kubectl auth can-i create deployments -n "$NS")"
printf 'kubectl auth can-i create deployments -n %s => %s\n' "$NS" "$can_create" \
  | tee "$EVIDENCE_DIR/950-staging-agent-rbac.txt"
[[ "$can_create" = "yes" ]] || fail "kubectl auth cannot create deployments in $NS"

printf 'Validating staging manifests with client dry-run...\n'
kubectl apply --dry-run=client -k "$KUSTOMIZE_DIR" \
  | tee "$EVIDENCE_DIR/951-staging-agent-manifest-dry-run.txt"

printf 'Checking pod rollouts...\n'
kubectl -n "$NS" rollout status deployment/sakina-backend --timeout=120s \
  | tee "$EVIDENCE_DIR/952-staging-agent-backend-rollout.txt"
kubectl -n "$NS" rollout status deployment/sakina-rag-retrieval --timeout=120s \
  | tee "$EVIDENCE_DIR/953-staging-agent-rag-retrieval-rollout.txt"
kubectl -n "$NS" rollout status deployment/sakina-rag-ingestion --timeout=120s \
  | tee "$EVIDENCE_DIR/954-staging-agent-rag-ingestion-rollout.txt"

printf 'Scanning namespace for unhealthy pod states...\n'
kubectl get pods -n "$NS" -o wide | tee "$EVIDENCE_DIR/955-staging-agent-pods.txt"
bad_pods="$(kubectl get pods -n "$NS" --no-headers | awk '$3 ~ /(CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError|Pending|Error)/ {print}')"
if [[ -n "$bad_pods" ]]; then
  printf '%s\n' "$bad_pods" | tee "$EVIDENCE_DIR/956-staging-agent-bad-pods.txt"
  fail "unhealthy pods detected in $NS"
fi
printf 'No unhealthy staging pods detected.\n' | tee "$EVIDENCE_DIR/956-staging-agent-bad-pods.txt"

mapfile -t backend_pods < <(kubectl -n "$NS" get pods -l app=sakina-backend \
  -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}')
if [[ "${#backend_pods[@]}" -lt 2 ]]; then
  fail "Redis session isolation proof requires two running sakina-backend pods; found ${#backend_pods[@]}"
fi

printf 'Port-forwarding backend pods %s and %s...\n' "${backend_pods[0]}" "${backend_pods[1]}"
kubectl -n "$NS" port-forward "pod/${backend_pods[0]}" 18081:8080 \
  >"$EVIDENCE_DIR/957-port-forward-pod-a.log" 2>&1 &
cleanup_pids+=("$!")
kubectl -n "$NS" port-forward "pod/${backend_pods[1]}" 18082:8080 \
  >"$EVIDENCE_DIR/958-port-forward-pod-b.log" 2>&1 &
cleanup_pids+=("$!")

for port in 18081 18082; do
  for _ in $(seq 1 60); do
    if python3 - "$port" <<'PY'
import socket
import sys
sock = socket.socket()
sock.settimeout(0.25)
try:
    sock.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    sock.close()
PY
    then
      break
    fi
    sleep 1
  done
done

printf 'Running Redis cross-pod state, latency, and WASM rejection checks...\n'
python3 - <<'PY' | tee "reports/final-hardening-evidence/959-staging-agent-runtime-proof.txt"
import concurrent.futures
import json
import statistics
import time
import urllib.error
import urllib.request
import uuid

HEADER = {
    "Content-Type": "application/json",
    "x-sakina-rollout-probe": "true",
}
POD_A = "http://127.0.0.1:18081"
POD_B = "http://127.0.0.1:18082"

def post_json(base, path, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=data, headers=HEADER, method="POST")
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body), (time.perf_counter() - started) * 1000
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {"raw": body}
        return exc.code, parsed, (time.perf_counter() - started) * 1000

trace_id = str(uuid.uuid4())
payload = {
    "trace_id": trace_id,
    "query": "Can I shorten prayer while travelling?",
    "language": "en",
}
status_a, body_a, ms_a = post_json(POD_A, "/api/agent/rollout/route", payload)
if status_a != 200:
    raise SystemExit(f"pod A agent route failed: status={status_a} body={body_a}")
status_b, body_b, ms_b = post_json(POD_B, "/api/agent/rollout/route", payload)
if status_b != 200:
    raise SystemExit(f"pod B agent route failed: status={status_b} body={body_b}")
if not body_b.get("redis_shared_state_loaded"):
    raise SystemExit(f"pod B did not load shared Redis state: {body_b}")
if int(body_b.get("memory_load_ms", 999999)) >= 15:
    raise SystemExit(f"Redis shared state load exceeded 15ms: {body_b.get('memory_load_ms')}ms")

print(json.dumps({
    "redis_cross_pod_state": "ok",
    "trace_id": trace_id,
    "pod_a_ms": round(ms_a, 3),
    "pod_b_ms": round(ms_b, 3),
    "backend_reported_memory_load_ms": body_b.get("memory_load_ms"),
    "pod_b_memory_trace": body_b.get("memory_trace"),
}, indent=2))

def latency_request(index):
    status, body, ms = post_json(POD_A, "/api/agent/rollout/route", {
        "query": f"Can I shorten prayer while travelling? request {index}",
        "language": "en",
    })
    if status != 200:
        raise RuntimeError(f"agent latency request {index} failed status={status} body={body}")
    return ms

with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    durations = list(pool.map(latency_request, range(100)))
durations_sorted = sorted(durations)
p99 = durations_sorted[98]
if p99 > 250:
    raise SystemExit(f"P99 latency exceeded 250ms: {p99:.3f}ms")
print(json.dumps({
    "latency_blast": "ok",
    "requests": len(durations),
    "workers": 5,
    "p50_ms": round(statistics.median(durations), 3),
    "p99_ms": round(p99, 3),
    "max_ms": round(max(durations), 3),
}, indent=2))

bad_inputs = [
    "api key: abc123",
    "access token xyz",
    "refresh token xyz",
    "private key begins",
    "bearer secret",
    "password: secret",
    "ignore previous instructions",
    "developer mode enabled",
    "this is a definitive fatwa",
    "no citation needed",
]
rejections = []
for item in bad_inputs:
    status, body, ms = post_json(POD_A, "/api/agent/rollout/validate", {"input": item})
    rejections.append({"input": item, "status": status, "ms": round(ms, 3), "body": body})
if any(result["status"] not in (400, 403) for result in rejections):
    raise SystemExit(f"WASM invalidation did not reject 100% of payloads: {rejections}")
print(json.dumps({
    "wasm_security_invalidation": "ok",
    "rejections": rejections,
}, indent=2))
PY

printf 'Preparing staging DB tunnel for export integrity proofs...\n'
kubectl -n "$NS" port-forward svc/sakina-postgres 15432:5432 \
  >"$EVIDENCE_DIR/960-port-forward-postgres.log" 2>&1 &
cleanup_pids+=("$!")
for _ in $(seq 1 60); do
  if python3 - <<'PY'
import socket
sock = socket.socket()
sock.settimeout(0.25)
try:
    sock.connect(("127.0.0.1", 15432))
except OSError:
    raise SystemExit(1)
finally:
    sock.close()
PY
  then
    break
  fi
  sleep 1
done

postgres_user="$(kubectl -n "$NS" get secret sakina-postgres-secret -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)"
postgres_password="$(kubectl -n "$NS" get secret sakina-postgres-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)"
postgres_db="$(kubectl -n "$NS" get secret sakina-postgres-secret -o jsonpath='{.data.POSTGRES_DB}' | base64 -d)"
export DATABASE_URL="postgres://${postgres_user}:${postgres_password}@127.0.0.1:15432/${postgres_db}"
export SAKINA_API_BASE_URL="http://127.0.0.1:18081"
export SAKINA_REDIS_URL="redis://sakina-redis:6379"

printf 'Running data export integrity proof against staging backend and staging DB...\n'
bash scripts/sakina/product-data-export-proof.sh \
  | tee "$EVIDENCE_DIR/961-staging-product-data-export-proof.txt"

printf 'Running agent feedback export proof against staging backend and staging DB...\n'
bash scripts/sakina/agent-feedback-export-proof.sh \
  | tee "$EVIDENCE_DIR/962-staging-agent-feedback-export-proof.txt"

printf 'STAGING_AGENT_ROLLOUT_GATE_OK\n'
