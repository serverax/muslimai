#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is not set" >&2
  exit 1
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "\dt" >/tmp/sakina_db_tables.txt
required=(users user_profiles modules user_module_progress chat_threads chat_messages rag_documents rag_chunks rag_embeddings notifications admin_audit_events)
for t in "${required[@]}"; do
  if ! grep -q "$t" /tmp/sakina_db_tables.txt; then
    echo "missing table: $t" >&2
    exit 1
  fi
done

echo "schema verification completed successfully"
