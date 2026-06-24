#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'NEW_TECH_MATRIX_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd awk
require_cmd grep
require_cmd sed

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

matrix="reports/final-hardening-evidence/sakina-all-advanced-technologies-implementation-matrix.md"
[[ -s "$matrix" ]] || fail "missing or empty advanced technologies implementation matrix: $matrix"

required_technologies=(
  "Brain Mother Algorithm / Central Orchestrator"
  "AIA / Agentic AI Workflow Engine"
  "RAG for Islamic Sources"
  "Graph RAG / Islamic Knowledge Graph"
  "Hybrid Search"
  "Islamic Source Trust Ranking"
  "Citation Validator"
  "Hallucination Validator"
  "Islamic Safety Guard / Policy-as-Code"
  "Context Compression"
  "AI Router / Model Router"
  "Evaluation AI / Islamic Quality Gate"
  "Semantic Cache"
  "Redis / Valkey Performance Cache"
  "WASM Module"
  "MCP / Connector Layer"
  "Event Bus / Queue / Outbox"
  "OpenTelemetry Observability"
  "OWASP API Security Gate"
  "OWASP MASVS Mobile Security Gate"
  "SAST / SCA / Secret / Container Scanning"
  "Kubernetes Restricted / Admission Policy Gate"
  "Prompt Injection / Jailbreak Guard"
  "PII Detection and Redaction"
  "Data Retention and Account Deletion Engine"
  "Backup and Disaster Recovery"
  "Load Testing / Performance Budget"
  "Canary / Feature Rollout"
  "Crash Reporting"
  "Cost Governor"
  "Human Review Queue"
  "Multimodal AI"
)

for technology in "${required_technologies[@]}"; do
  grep -F "Technology: $technology" "$matrix" >/dev/null \
    || fail "matrix missing required technology entry: $technology"
done

accepted_status_count="$(grep -c '^Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN$' "$matrix")"
if [[ "$accepted_status_count" -lt "${#required_technologies[@]}" ]]; then
  fail "matrix has $accepted_status_count accepted statuses but ${#required_technologies[@]} technologies are required"
fi

if grep -nE '^Status: (PARTIAL|FAILED|NOT IMPLEMENTED|SAFE DISABLED|COMPLETE BUT LOCAL ONLY|COMPLETE AND LIVE|LIVE AND PROVEN)' "$matrix"; then
  fail "matrix contains a non-accepted technology status"
fi

missing_required_fields="$(
  awk '
    /^Technology: / { tech=$0; fields=0 }
    /^Workflow position: / { fields++ }
    /^Frontend files: / { fields++ }
    /^Backend files: / { fields++ }
    /^DB tables\/functions\/triggers: / { fields++ }
    /^Qdrant\/cache\/storage objects: / { fields++ }
    /^Brain\/AIA stages: / { fields++ }
    /^Security controls: / { fields++ }
    /^Positive proof script: / { fields++ }
    /^Negative proof script: / { fields++ }
    /^CI proof: / { fields++ }
    /^Docker proof: / { fields++ }
    /^Kubernetes proof: / { fields++ }
    /^Release APK\/AAB proof: / { fields++ }
    /^Evidence file: / { fields++ }
    /^Status: / { fields++ }
    /^Remaining blocker: / {
      fields++
      if (fields < 16) {
        print tech " has only " fields " required fields"
      }
    }
  ' "$matrix"
)"
if [[ -n "$missing_required_fields" ]]; then
  printf '%s\n' "$missing_required_fields" >&2
  fail "matrix entries are missing required fields"
fi

proof_scripts="$(
  grep -oE '`scripts/sakina/[^`]+\.sh`' "$matrix" \
    | sed 's/^`//; s/`$//' \
    | sort -u
)"
while IFS= read -r script; do
  [[ -n "$script" ]] || continue
  [[ -s "$script" ]] || fail "matrix references missing or empty proof script: $script"
  set +e
  fake_hits="$(
    grep -nE 'echo[[:space:]]+["'\'']?(PASS|passed)|Smoke validation passed|continue-on-error|ALLOW_FAKE_CI_PASS[[:space:]]*=[[:space:]]*true|mock_embeddings|mode.:.mock' "$script" \
      | grep -vE 'rg .*echo|grep .*echo|Select-String .*echo|rg .*continue-on-error|grep .*continue-on-error|Select-String .*continue-on-error'
  )"
  set -e
  if [[ -n "$fake_hits" ]]; then
    printf '%s\n' "$fake_hits" >&2
    fail "matrix proof script contains forbidden fake-pass or mock pattern: $script"
  fi
done <<< "$proof_scripts"

evidence_files="$(
  grep -oE '`reports/final-hardening-evidence/[^`]+\.txt`' "$matrix" \
    | sed 's/^`//; s/`$//' \
    | sort -u
)"
while IFS= read -r evidence; do
  [[ -n "$evidence" ]] || continue
  [[ -s "$evidence" ]] || fail "matrix references missing or empty evidence file: $evidence"
  set +e
  evidence_hits="$(
    grep -nE '(^|[[:space:]])[A-Z0-9_]+_BLOCKER|NEW_TECH_GATE_BLOCKER|FakeModuleApiClient|SAKINA_API_TOKEN|demo-token|test-token|mock_embeddings|mode.:.mock' "$evidence" \
      | grep -vE '^[0-9]+:[^[:space:]]+\.(sh|rs|dart|yml|yaml|md):[0-9]+:'
  )"
  set -e
  if [[ -n "$evidence_hits" ]]; then
    printf '%s\n' "$evidence_hits" >&2
    fail "matrix evidence contains a blocker or fake marker: $evidence"
  fi
done <<< "$evidence_files"

printf 'NEW_TECH_MATRIX_OK matrix covers %s technologies with required runtime proof scripts and evidence files.\n' "${#required_technologies[@]}"
