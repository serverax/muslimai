# Sakina AI — PHASE 1: Scholar Workflow (closed, Docker-proven)

Date: 2026-06-22 · Stack: local Docker (api :28080, Postgres 15). Owner SAK-006 = option 1 (app-layer isolation).
Evidence: `test-results/audit-2026-06-22/phase1-scholar-proof.txt`.

## What was built
- `services/phase2.rs`: `list_scholar_queue`, `get_scholar_review_detail`, `get_user_review_status` (ownership via brain_decision_traces); audit-log insert into `public.audit_logs` on resolve (state transition with trace id).
- `handlers/phase2.rs`: `scholar_queue`, `scholar_review_detail`, `user_review_status`.
- `main.rs`: scholar-gated `/scholar` scope (`GET /queue`, `GET /reviews/{id}`, `POST /reviews/resolve`) wrapped with `scholar_guard` (scholar OR admin); user `GET /api/sakina/review-status/{trace_id}` (root + /v1).
- `handlers/sakina_ask.rs`: SAK-022 — `enqueue_scholar_review` now returns bool + logs failure (no swallowed escalation error).

## Lifecycle (end to end)
ask high-risk -> enqueue scholar_review_queue (pending/high, request_id=trace) -> scholar lists queue -> scholar opens detail -> scholar resolves (status + final_answer -> scholar_resolved_answers) -> audit_logs row -> user polls review-status -> receives scholar_answered + final answer.

## Hard-exit proof
| # | Requirement | Command | Result |
|---|---|---|---|
| 1 | high-risk fatwa creates queue row | ask -> DB scholar_review_queue | PASS (pending/high) |
| 2 | scholar reads queue | GET /scholar/queue (scholar JWT) | PASS — 200, trace present |
| 3 | scholar review detail | GET /scholar/reviews/{trace} | PASS — pending, no answer yet |
| 4 | scholar resolve | POST /scholar/reviews/resolve | PASS — 200 |
| 5 | user sees final answer | GET /api/sakina/review-status/{trace} | PASS — scholar_answered + answer text |
| 6 | non-scholar blocked | A GET /scholar/queue / anon | PASS — 403 / 401 |
| 7 | user B cannot see A review | B GET /api/sakina/review-status/{A trace} | PASS — 404 |
| 8 | audit trail | SELECT … audit_logs WHERE event_type='scholar_review_resolved' | PASS — scholar/approved row |
| 9 | SAK-022 not swallowed | grep enqueue_scholar_review -> bool + tracing::error | PASS |
| 10 | no mock queue / real Docker | all via api :28080 + real Postgres | PASS |

## Result: PHASE 1 = PASS (backend loop closed + command-proven).

## Remaining (not in Phase 1 hard-exit, follow-up)
- Mobile UI: a dedicated "pending scholar review / scholar answered" screen polling `/api/sakina/review-status/{trace}` (chat already surfaces ESCALATED_TO_HUMAN; backend delivery endpoint is live). Wire in a later mobile batch.
- Assign/reassign UI (assign endpoint exists; queue-read now enables it).
