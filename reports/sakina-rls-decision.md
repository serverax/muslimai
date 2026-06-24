# SAK-006 — RLS app-role: decision required

## Current state (safe, not unsafe)
- Tenant isolation is enforced at the **application layer** (`WHERE user_id = $1` in every per-user query). Runtime-proven: user B reading user A's trace returns 404.
- RLS is enabled + FORCED on all tables, but `sakina_ai.rls_service_role()` returns true when `current_user IN ('sakina_user', ...)`. The app connects as `sakina_user`, so RLS is a no-op for the app connection (defence-in-depth only, not the active guard).

## Why not flipped automatically
Removing the `current_user` shortcut from `rls_service_role()` (or switching the app to a non-allowlisted role) **without** first plumbing a per-request `SET LOCAL sakina.current_user_id = <uuid>` into every DB transaction would make every query return **zero rows** — breaking the entire app. That plumbing is a cross-cutting change touching every handler/repo and must be done and tested as one unit. Doing it partially would be more dangerous than the current state.

## Exact decision / work needed (owner)
Choose one:
1. **Accept app-layer isolation** as the production control (RLS = defence-in-depth). Lowest risk; isolation already proven. Recommended for first go-live.
2. **Authorize the DB-role refactor** (scheduled, tested as a unit):
   - Create a dedicated `sakina_app` login role (not in the `rls_service_role()` allowlist).
   - Point `DATABASE_URL` at `sakina_app`.
   - Wrap every request's DB work in a transaction that runs `SET LOCAL sakina.service_role = 'off'; SET LOCAL sakina.current_user_id = '<jwt-user>'`.
   - Remove the `current_user IN (...)` branch from `rls_service_role()`.
   - Re-run the full isolation test matrix.

Until the owner picks (2), Sakina ships with option (1). This does not block any other feature work.
