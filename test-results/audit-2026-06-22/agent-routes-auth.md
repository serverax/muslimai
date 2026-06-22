# Routes / Auth / RBAC / Isolation audit (agent result, 2026-06-22)

## Executive
- NO auth middleware. Only .wrap() is AuditMiddleware = logging-only (audit.rs:14-79), always logs "anonymous".
- Auth enforced PER-HANDLER via authenticated_user_id()/ensure_user_scope() (auth.rs:121,198). Inconsistent.
- NO RBAC anywhere. admin_roles/scholar_accounts tables exist but NO handler checks caller role.
- JWT hand-rolled HS256; verifies sig+expiry + DB session cross-check.

## CRITICAL — ungated admin/scholar routes (main.rs:822-852, /v1 1135-1210)
Handlers have NO HttpRequest param, NO authenticated_user_id, NO role check (phase2.rs:318-371):
- POST /admin/roles (mint admin unauthenticated), /admin/audit-actions, GET/POST /admin/source-approval-queue
- POST /admin/scholars (create scholar), /admin/scholar-assignments, /admin/scholar-reviews/resolve
- POST /v1/safety/scholar-assignments, /v1/safety/scholar-reviews/resolve
Any unauthenticated client mints admins, creates scholars, resolves reviews. MOST SEVERE FINDING.

## Anonymous log/event injection (no auth)
/v1/audit/logs, /v1/security/logs, /v1/events/*, /v1/rag/audit/*, /v1/safety/classifications+mastermind-decisions+wasm-events (phase2.rs:270-316,478-492; main.rs:1201-1210). /v1/notifications/templates unauthenticated (373). /v1/auth/sessions accepts token hashes in body no auth (43).

## Cross-user leak — dashboard
dashboard::get_guardrails (dashboard.rs:17-35) authenticates A but returns last 100 sakina_ai.safety_classifications ACROSS ALL USERS, NO user filter, NO admin gate.

## Auth mechanism
- Secret ≥32 else 503 (auth.rs:45-60). validate_jwt (93-119): HMAC + NON-CONSTANT-TIME compare (101), exp check (112), does NOT verify iss/aud/alg.
- Session binding (121-159): non-revoked auth_sessions row, SHA256 token hash, session.user_id==jwt.sub. Forged-but-unstored token rejected at DB. Good.
- Test backdoor x-sakina-user-id gated cfg!(test), compiled out of release.

## User isolation — app-layer REAL where present
- brain trace: user B CANNOT read user A. brain_traces.rs:14-27 WHERE request_id=$1 AND user_id=$2 → 404.
- chat id=$1 AND user_id=$2 (545-554), reject mismatched body (480-488). memory/multimodal/sync/profiles/subs/support/iman scoped.
- RLS bypassed for app connection (sakina_user=service role). App-layer user_id filter IS the real boundary. Dashboard forgets it → leaks.

## Red flags
1. Ungated admin/scholar routes (CRITICAL). 2. Anonymous log/event injection. 3. Cross-user dashboard leak. 4. /api/sakina/ask forwards before auth in gateway mode (357-371). 5. No auth middleware backstop. 6. Hand-rolled JWT non-constant-time, no alg/iss/aud (DB-session mitigates). 7. create_session unauthenticated. 8. /health/observability + /api/brain/audit/recent public.
