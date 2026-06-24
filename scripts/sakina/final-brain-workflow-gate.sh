#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cat tasks/sakina-loop-control-rules.md >/dev/null
head -120 tasks/sakina-ultimate-hard-execution-order.md >/dev/null

export SAKINA_EVIDENCE_DIR="${SAKINA_EVIDENCE_DIR:-reports/final-hardening-evidence}"
mkdir -p "$SAKINA_EVIDENCE_DIR"

bash scripts/sakina/sakina-ask-live-workflow-proof.sh
bash scripts/sakina/final-sunni-provenance-gate.sh

printf 'BRAIN_WORKFLOW_GATE_OK live Sakina Mother workflow proved PII redaction, DB/RAG/Graph checking, LLM fail-closed controls, fatwa escalation, and trace persistence.\n'
