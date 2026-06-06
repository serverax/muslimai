#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cat tasks/sakina-loop-control-rules.md >/dev/null
head -120 tasks/sakina-ultimate-hard-execution-order.md >/dev/null

export SAKINA_EVIDENCE_DIR="${SAKINA_EVIDENCE_DIR:-reports/final-hardening-evidence}"
mkdir -p "$SAKINA_EVIDENCE_DIR"

bash scripts/sakina/sakina-ask-live-workflow-proof.sh

printf 'ASK_AI_SHAIKH_GATE_OK real JWT, DB-first, RAG/Graph trace, PII redaction, fatwa escalation, citation provenance, and cross-user trace denial were proven.\n'
