# SakinaAL — Hostile Security Audit (backend auth/isolation/DB)

Auditor stance: guilty until proven. Evidence = file:line + command output. No build/check/test run (orchestrator owns it).
Scan saved: `reports/ultimate-hostile-audit/070-auth-workspace-scan.txt` (1405 lines).

## Executive verdict

The backend is **substantially better than a typical "guilty" target**. Application-layer ownership
enforcement on every path-param route is real and correct. The headline weaknesses are:

1. **CRITICAL — Account deletion never executes.** `/v1/account/delete-request` only enqueues an
   outbox event; there is no consumer in the Rust codebase that deletes/anonymizes. (GDPR/data-deletion gap.)
2. **HIGH — RLS is present but inert for normal traffic.** Policies exist and are FORCEd, but the
   backend connects as `sakina_user`/`postgres`, which `rls_service_role()` treats as full bypass.
   `sakina.current_user_id` is set in exactly ONE narrow helper (event recording), nowhere else.
   Isolation therefore rests entirely on app-layer `WHERE user_id = $1`. Defense-in-depth is effectively absent.
3. **HIGH — No rate limiting on `/auth/login`, `/auth/register`, `/auth/refresh`.** Only the waitlist
   endpoint is rate-limited. Brute-force / credential-stuffing is open.
4. **MEDIUM — Security regression script did not actually run** (missing `jq`); it fails closed (good)
   but provides zero runtime assurance in this environment.
5. **LOW/INFO — Audit middleware logs to stdout only**, not to a DB table (by its own comment). Only
   deletion/export handlers persist to `public.audit_logs`.

---

## JWT — verification logic — PASS

`sakina-backend/src/services/auth.rs`
- `validate_jwt` (auth.rs:93-119): splits 3 parts, recomputes HMAC-SHA256 over `header.payload` and
  compares to provided signature (auth.rs:99-103) — **signature IS verified**.
- Expiry checked: `exp <= now` rejected (auth.rs:112-114). **Expiry IS enforced.**
- `sub` parsed to UUID (auth.rs:115-118).
- Algorithm is fixed HS256 (issue side, auth.rs:76); validate side does not read `alg` from token, so
  no `alg=none` confusion (it always recomputes HS256). PASS.
- Secret: requires `JWT_SECRET`/`SAKINA_JWT_SECRET` >= 32 chars or fails service_unavailable in prod
  (auth.rs:45-60). Test-only fallback gated by `cfg!(test)`. PASS.

Status: **PASS** (signature + expiry verified; HS256 fixed; min-length secret enforced).

## Revocation / session / logout — PASS

`authenticated_user_id` (auth.rs:121-159): after JWT validation, looks up
`public.auth_sessions WHERE session_token_hash=$1 AND expires_at>now() AND revoked_at IS NULL`
(auth.rs:134-148) and rejects if absent (auth.rs:150-152). Also checks `session_user_id == jwt_user_id`
(auth.rs:155-157). **Revoked/expired/unknown tokens are rejected against the DB.**
- Logout (`handlers/phase2.rs:87-136`): sets `auth_sessions.revoked_at` AND revokes matching
  `auth_refresh_tokens` in one tx. PASS.
- Refresh (`services/phase2.rs:278-315`): refresh tokens are single-use (`used_at IS NULL`, `FOR UPDATE`,
  rotated) with `revoked_at`/`expires_at`/`is_active` checks — token-theft resistant. PASS.

Caveat: `cfg!(test)` `x-sakina-user-id` header bypass (auth.rs:29-38, 125-127) is compiled out of release
builds. Acceptable.

Status: **PASS**.

## Workspace / User isolation (BOLA / IDOR) — PASS (app-layer)

Every path-param route validates the JWT subject OWNS the id. The path/body id is overwritten with the
authenticated id; mismatches are rejected. Table below.

| Route | Handler (file:line) | Ownership enforced? | Evidence |
|---|---|---|---|
| `PUT /v1/profiles/{user_id}` | phase2.rs:138 | YES | auth vs path check 147-151; `request.user_id = auth_user_id` 152 |
| `POST /v1/profiles/{user_id}/family` | phase2.rs:157 | YES | check 166-170; overwrite 171 |
| `POST /v1/subscriptions/{user_id}/activate` | phase2.rs:179 | YES | grant-secret 185-201 + auth check 206-210 |
| `GET /v1/subscriptions/{user_id}/entitlements` | phase2.rs:216 | YES | check 223-227 |
| `GET /api/workspaces/{workspace_id}/memory` | memory.rs:122 | YES | workspace owner lookup 129-138 (404 if not owner) |
| `GET /api/multimodal/assets/{asset_id}` | multimodal.rs:152 | YES | `get_asset(user_id, …)` → SQL `WHERE id=$1 AND user_id=$2` (services/multimodal.rs:394) |
| `DELETE /api/multimodal/assets/{asset_id}` | multimodal.rs:166 | YES | `delete_asset` → `WHERE id=$1 AND user_id=$2` (services/multimodal.rs:421) |
| `POST /v1/sync/backup/{user_id}` | sync.rs:18 | YES | check 22-27 |
| `GET /v1/sync/backup/{user_id}` (restore) | sync.rs:65 | YES | check 68-73 |
| `POST .../messages/{message_id}` feedback | phase2.rs:232 | YES (uses auth id, not trusting path for owner) | user_id from auth 239 |

Non-path user-data routes also scope by `authenticated_user_id`: memory list/read/write/delete
(memory.rs:23,50,69,87), user_learning (user_learning.rs:20,86,130,163).

Status: **PASS** — no BOLA found at the application layer. (DB layer does not back this up — see RLS.)

## RLS (row level security) — PARTIAL / effectively bypassed

Policies DO exist and tables are `ENABLE` + `FORCE ROW LEVEL SECURITY`:
- Bulk loop over `public`,`sakina_ai`,`audit`,`outbox` (017_rls_user_isolation.sql:35-81): every table
  gets a service-role policy; tables with a `user_id` column also get
  `USING (user_id = sakina_ai.current_user_id() OR rls_service_role())` (017:60-78).
- Named policies: `public.users` self (017:84-87), `password_credentials` (017:89-93),
  `sakina_ai.messages` (017:95+), child_profiles, notification_delivery_attempts,
  support_ticket_messages, payment_methods, subscription_events, refunds (017:124-253).
- audit_logs / outbox.events / agent_feedback (019_agent_feedback.sql:19-77).
- workspace/learning tables (020_workspace_learning_core.sql:173-183), mother local topics (021:167-183).
- Public read-only reference tables intentionally `USING (true)` (017:290-336) — acceptable for
  islamic_sources/feature_flags/etc.

**The defeater** (017:11-18):
```
sakina_ai.rls_service_role(): ... OR current_user IN ('sakina_user','postgres')
```
The backend connects via `DATABASE_URL` / `POSTGRES_*` (main.rs:18-50, 481-492). The regression script's
default URL is `postgres://sakina_user:...` (security-regression.sh:27). As `sakina_user`,
`rls_service_role()` = TRUE, so **every policy short-circuits to allow-all**. `set_config('sakina.current_user_id', …)`
is called in exactly one place — the event-recording helper (services/phase2.rs:1945-1954) — and is
cleared/service-on everywhere else. No `after_connect` / per-request `SET LOCAL sakina.current_user_id`.

Consequence: RLS provides NO runtime isolation for the app's own queries; it would only help an attacker
who obtained a *different, non-privileged* DB role. Isolation is 100% dependent on the app-layer checks above.

Tables that LACK a per-user policy entirely (only service-role policy, which is moot anyway): any
`sakina_ai`/`public` table whose owner key is NOT literally `user_id` (e.g. workspace_id-keyed child
tables, conversation-keyed tables other than `messages`) — the generic loop keys only on a `user_id`
column (017:52-78).

Status: **PARTIAL** — policies authored correctly but inert in the deployed role model.

## CORS — PASS (with note)

`build_cors()` main.rs:404-428. Default origins: `https://7jzi.com`, `www`, and **http** variants
(main.rs:407). Methods restricted to GET/POST/OPTIONS (main.rs:416). Headers: Authorization/Content-Type/Accept.
No `allow_any_origin`, no `send_wildcard`, no `allow_credentials(true)+wildcard`. Origins overridable via
`CORS_ALLOWED_ORIGINS`.
Notes: (a) `http://7jzi.com` allowed (cleartext origin) — minor; (b) allowed_methods omit PUT/DELETE while
routes use them — irrelevant for native mobile clients, but a browser caller of `PUT /profiles/{id}` /
`DELETE /multimodal/assets/{id}` would be blocked by CORS preflight. Not a security hole.

Status: **PASS**.

## Rate limiting — FAIL

`rg rate.?limit` → only `WaitlistRateLimiter` (handlers/waitlist.rs:25-45; main.rs:555,1211). `/auth/login`,
`/auth/register`, `/auth/refresh` (handlers/phase2.rs:31,58,70) have **no throttling**. Brute-force and
credential-stuffing are unmitigated. (`cost_governor` in brain_controller is LLM budget, not auth.)

Status: **FAIL** (auth brute-force exposure).

## Secrets — PASS

- `bash scripts/sakina/verify-no-secret-leak.sh` → EXIT 0 BUT "No files selected" because it only scans
  `git diff --cached` (none staged). Trivial/meaningless pass. (`reports/.../111-secret-scan.txt`)
- Re-run `verify-no-secret-leak.sh --all-files` → EXIT 0, "secret leak verification completed"
  (`reports/.../111b-secret-scan-allfiles.txt`) — this is the meaningful run.
- Direct repo grep for private keys / AKIA / sk- / ghp_ / xox- / hardcoded passwords (excluding
  reports,target,md): only matches are (a) regex patterns inside the scanner scripts themselves, and
  (b) `StrongPassword123!` test literals in proof scripts, and (c) a kubectl command that *reads* a k8s
  secret at runtime (final-staging-...:237). **No committed private keys or real credentials found.**

Status: **PASS** (no real secrets committed; but the pre-commit scanner only guards staged diffs).

## PII redaction — PASS (basic)

`services/pii_redaction.rs:7 redact_pii` redacts emails, phone-like numbers, name/address phrases
(tests at :132-155). Multimodal stores `redacted_text` (services/multimodal.rs:340-347). Adequate but
heuristic (token/phrase based, not exhaustive). PASS for stated scope.

## Audit logging — PARTIAL

- HTTP audit middleware (`middleware/audit.rs:1-50`) logs method/path/status/latency to **stdout via
  tracing only** — its own comment (audit.rs:4-5) says DB persistence is "a later layer", i.e. not done.
- Security-relevant events DO persist: account deletion + data export write `public.audit_logs`
  (phase2.rs:500-516, 556-563). 
- No tamper-evidence/append-only guarantee beyond RLS (which is inert).

Status: **PARTIAL** — request audit not durably stored; only specific GDPR events are.

## Data deletion — FAIL (CRITICAL)

- `/v1/account/delete-request` → `request_account_deletion` (phase2.rs:486-540): writes an audit row and
  inserts `outbox.events('account_deletion_requested', …, 'Pending')` (phase2.rs:518-532). Returns
  `202 queued`. **No code consumes this event.** `rg account_deletion_requested sakina-backend/src` →
  only the two INSERT sites; **no consumer/relay handler that deletes or anonymizes user data.**
- `DELETE /api/user-learning/profile` (user_learning.rs:126-150) only **soft-deletes the learning
  preferences row** (`SET deleted_at = NOW()`) for one table — not an account deletion.

Consequence: a user-requested account deletion is recorded but **never executed**. PII persists
indefinitely. GDPR "right to erasure" not fulfilled.

Status: **FAIL (CRITICAL)** — deletion is enqueue-only with no executor.

## File upload (`POST /api/multimodal/analyze`) — PASS

handlers/multimodal.rs:80 + services/multimodal.rs.
- JWT/auth: `authenticated_user_id` (multimodal.rs:87). YES.
- File size: handler caps at 10 MiB (multimodal.rs:67-68); service re-validates against
  `SAKINA_MULTIMODAL_MAX_BYTES` (services/multimodal.rs:75-92). Multipart text fields capped at 4096
  (multimodal.rs:30-31). YES.
- Type validation: `validate_media` enforces asset_type/mime pairs, rejects unsupported/mismatched
  (services/multimodal.rs:86-108). YES.
- Private storage: `persist_private_file` writes under per-user dir `storage_root/{user_id}/...` with
  `sanitize_filename` + sha256 prefix (services/multimodal.rs:111-135) — path-traversal mitigated. YES.
- Owner-only retrieval/delete: SQL scoped `WHERE id=$1 AND user_id=$2` (services/multimodal.rs:394, 421). YES.

Status: **PASS**.

---

## Script run results (raw)

- `bash scripts/sakina/security-regression.sh` → **EXIT 1**. Output: `SAKINA_SECURITY_FAIL: required
  command missing: jq` (`reports/.../110-security-regression.txt`). The script IS a real runtime test
  (registers users, asserts weak-password rejection at :67-71, spins backend via cargo build at :51-53),
  but it **never ran the assertions** here — it fails closed on the missing-tool precheck (:12-19). NOT a
  pass, NOT a fake pass.
- `verify-no-secret-leak.sh` EXIT 0 (no staged files — meaningless); `--all-files` EXIT 0 (meaningful, clean).

## Findings ordered by severity

1. CRITICAL — Account deletion never executes (enqueue-only, no consumer). phase2.rs:486-540; no consumer for `account_deletion_requested`.
2. HIGH — RLS inert: backend role `sakina_user`/`postgres` short-circuits `rls_service_role()`; `current_user_id` set in one helper only. 017_rls_user_isolation.sql:11-18; services/phase2.rs:1945-1954.
3. HIGH — No rate limiting on login/register/refresh. handlers/phase2.rs:31,58,70 (only waitlist limited).
4. MEDIUM — Security regression suite unverified in this env (missing jq); no runtime assurance.
5. MEDIUM — Request audit logging is stdout-only, not durable. middleware/audit.rs:4-5.
6. LOW — CORS allows cleartext `http://7jzi.com`; allowed_methods omit PUT/DELETE (no security impact for native clients).
7. INFO — Pre-commit secret scanner only checks staged diff by default (use `--all-files` in CI).

## What is genuinely solid (proven PASS)
JWT signature+expiry+fixed-HS256; DB-backed session revocation; single-use rotating refresh tokens;
Argon2id password hashing (services/phase2.rs:2065-2084); application-layer ownership on 100% of
path-param routes (no BOLA); file-upload auth/size/type/private-storage/owner-scoped retrieval; no
committed secrets.
