# Sakina AI — Go-Live Blockers

Date: 2026-06-22 · Verdict: **SAKINA AI NOT READY — FAILURES REMAIN.**

A blocker = must be closed (or explicitly owner-accepted) before "READY — COMMAND-PROVEN".

## CRITICAL blockers (must fix)
| ID | Blocker | Proof | Owner |
|---|---|---|---|
| SAK-001 | Admin/scholar routes unauthenticated, no RBAC; anonymous audit injection (201, row written) | runtime-proof.txt §7-8 | backend |
| SAK-004 | Crisis/self-harm classifier misses common phrasing → 502 to vulnerable user | runtime-proof.txt (crisis) | safety |
| SAK-005 | Islamic answer can return with zero citations in monolithic mode (no local citation hard-gate) | agent-pipeline.md | safety/RAG |
| SAK-006 | RLS provides no real tenant isolation on the app connection | agent-db-schema.md | DB/security |

## Resolved CRITICAL (verified this session)
| ID | Was | Now |
|---|---|---|
| SAK-002 | Postgres could not boot (init.sql CREATE USER) | FIXED — boots clean |
| SAK-003 | No user could register (ON CONFLICT arbiter) | FIXED — 201 + JWT |

## HIGH blockers
- SAK-007 Cross-user dashboard data leak.
- SAK-008 `public.scholar_accounts` table missing (scholar creation 500s).
- SAK-009 Scholar workflow not a closed loop (no queue read, no answer delivery, crisis not enqueued).
- SAK-010 `/api/sakina/ask` 502s when LLM gateway down instead of degrading.
- SAK-011 No brute-force protection on auth endpoints.
- SAK-012 Subscription/payment schema missing — paid gates half-built.
- SAK-013 Hardcoded secrets in distributed compose.

## UNPROVEN (cannot certify READY without these)
- **Kubernetes/Talos runtime** — no live cluster available this session.
- **Dependency CVE scan** (`cargo audit`) — host cargo blocked by Application Control policy.
- **LLM/Ollama end-to-end** — Ollama not co-located (host :11434 conflict); LLM-compose + Arabic answer paths not runtime-proven.
- **CI/CD** — not independently re-run this session.
- **Full corpus RAG** — Qdrant/embedding-backed retrieval not load-tested with populated corpus.

## Acceptance gate
Do not declare "SAKINA AI READY — COMMAND-PROVEN" until all CRITICAL + HIGH are FIXED or owner-accepted, and the UNPROVEN list is exercised with command output.
