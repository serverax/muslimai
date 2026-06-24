# Module Contract Shell Status (Phase-2)

Date: 2026-05-28  
Branch: `qa-security-hardening`

## Status

Quran, Prayer, Knowledge, and Community are currently **read-only contract shells**.

They are **not** production-complete Islamic services.

## Current behavior

- Modules are disabled by default behind feature flags.
- Disabled modules show explicit “coming soon / under review” style messaging.
- Enabled modules return contract payloads in `requires_review` state.
- No fabricated religious content is returned.
- If payload entries exist, provenance fields are mandatory.
- RAG is contract-first only in this phase:
  - `GET /v1/rag/status`
  - `GET /v1/rag/sources`
  - `GET /v1/rag/search`
  - `POST /v1/rag/decide`
  - verified-only filtering required for any user-visible retrieval
  - deterministic decision algorithm must remain auditable and gated

## Non-negotiable release guardrails

Do not present these modules as complete product features until:

1. Verified data ingestion exists
2. Source provenance is complete
3. License terms are documented
4. Review workflow is implemented
5. Entitlement and safety checks pass end-to-end

## Not included yet

- Real Quran content ingestion
- Real prayer timetable ingestion
- Real knowledge corpus ingestion
- Real community feed/service ingestion
- Real Islamic answer generation from RAG

## Deployment policy

- Do not enable these modules by default.
- Do not deploy module-enabled behavior to production without explicit approval.
