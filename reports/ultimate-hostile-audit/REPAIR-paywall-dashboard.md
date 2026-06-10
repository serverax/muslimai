# REPAIR: Forgeable Paywall + Fake Dashboard Data

Scope: edited only `sakina-backend/src/handlers/rag.rs` and `sakina-backend/src/handlers/dashboard.rs`.
No `cargo` was run. Fixes follow the existing authenticated DB-entitlement pattern in `handlers/modules.rs` and the auth helper `services::auth::authenticated_user_id`.

---

## BLOCKER #13 — Forgeable paywall (handlers/rag.rs)

### Before
Premium access was gated on a client-supplied, trivially forged header:

```rust
fn has_entitlement(req: &HttpRequest) -> bool {
    req.headers()
        .get("x-sakina-subscription-tier")
        .and_then(|v| v.to_str().ok())
        .map(|v| {
            matches!(
                v.trim().to_ascii_lowercase().as_str(),
                "premium" | "pro" | "founding"
            )
        })
        .unwrap_or(false)
}
```

Any caller could send `x-sakina-subscription-tier: premium` and read premium RAG
sources/search results without paying.

### After
The header is no longer read. Access is gated on the **authenticated user's DB
entitlement**, mirroring `modules.rs::user_has_entitlement` / `enforce_module_gate`:

```rust
fn module_entitlement_key(module: &str) -> Option<&'static str> {
    match module {
        "quran" => Some("quran_access"),
        "prayer" => Some("prayer_access"),
        "knowledge" => Some("knowledge_access"),
        "community" => Some("community_access"),
        _ => None,
    }
}

async fn has_entitlement(
    req: &HttpRequest,
    pool: &sqlx::PgPool,
    module: &str,
) -> Result<bool, ApiError> {
    let Some(entitlement_key) = module_entitlement_key(module) else {
        return Ok(false);
    };
    let user_id = crate::services::auth::authenticated_user_id(req, pool).await?;
    let row = sqlx::query(
        r#"
        SELECT 1
        FROM public.user_entitlements ue
        JOIN public.entitlements e ON e.id = ue.entitlement_id
        WHERE ue.user_id = $1
          AND e.entitlement_key = $2
          AND e.is_active = true
          AND ue.revoked_at IS NULL
          AND (ue.expires_at IS NULL OR ue.expires_at > now())
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(entitlement_key)
    .fetch_optional(pool)
    .await
    .map_err(|_| ApiError::internal("failed to verify rag entitlement"))?;
    Ok(row.is_some())
}
```

Both call sites (`rag_sources`, `rag_search`) now:
- propagate the auth error (no JWT/session => `401 unauthorized`),
- return `402 subscription_required` when authenticated but not entitled,
- never 500 on the normal not-entitled path.

Anonymous/free behavior for non-premium content is unchanged (feature-flag /
module-validation paths are untouched and still run before the entitlement check).

### Behavior matrix (after)
| Caller | Result |
|---|---|
| Forged `x-sakina-subscription-tier: premium`, no JWT | `401 unauthorized` (header ignored) |
| Valid JWT, no entitlement row | `402 subscription_required` |
| Valid JWT, active entitlement | premium sources returned |
| Feature flag disabled | `403 feature_disabled` (unchanged, runs first) |

### Tests
- Replaced `missing_entitlement_blocks_rag` with `missing_jwt_blocks_rag` (now expects `401`, matching fail-closed auth-first ordering used by `modules.rs` tests).
- Added `forged_tier_header_does_not_bypass_rag_paywall` (sends the premium header, asserts `401` — proves the header is no longer trusted).
- `disabled_module_cannot_query_rag` unchanged (still `403`; feature gate runs before auth).

---

## BLOCKER #14 — Fake dashboard data (handlers/dashboard.rs)

### Before
`get_guardrails` returned a hardcoded, fabricated array with no DB and no auth:

```rust
pub async fn get_guardrails() -> HttpResponse {
    HttpResponse::Ok().json(json!([
        {
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "query": "example",
            "trigger_reason": "SIMILARITY_THRESHOLD_FAILED",
            "user_id": null
        }
    ]))
}
```

### After
Option (a) implemented — a real query against an existing table
(`sakina_ai.safety_classifications`, the actual safety-event store written by
`services::phase2::log_safety_classification`), gated behind authentication.
Returns real rows; honest empty list when none exist. Never fabricates data.

```rust
pub async fn get_guardrails(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let _user_id = crate::services::auth::authenticated_user_id(&req, pool.get_ref()).await?;

    let rows = sqlx::query(
        r#"
        SELECT
            sc.created_at::text AS timestamp,
            sc.request_id::text AS request_id,
            sc.user_id::text AS user_id,
            sc.safety_level AS safety_level,
            sc.islamic_sensitivity AS islamic_sensitivity,
            sc.classifier_version AS classifier_version
        FROM sakina_ai.safety_classifications sc
        ORDER BY sc.created_at DESC
        LIMIT 100
        "#,
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load guardrail events"))?;

    // ...map rows to JSON...

    Ok(HttpResponse::Ok().json(json!({
        "events": events,
        "source": "safety_classifications",
    })))
}
```

- Requires a valid JWT/session (`authenticated_user_id`) before any DB read — fails closed.
- Response shape is `{ "events": [...], "source": "safety_classifications" }`; empty DB => `{ "events": [], "source": "safety_classifications" }`.
- Route registration in `main.rs` (`/dashboard/guardrails`) is unchanged — actix injects `HttpRequest` and the already-registered `web::Data<PgPool>`.

### Tests
- Added `unauthenticated_request_is_rejected` (no auth => `401`, asserts no fabricated data is ever served).

---

## File:line summary

- `sakina-backend/src/handlers/rag.rs`
  - ~185: `module_entitlement_key` helper added.
  - ~199: `has_entitlement(req, pool, module)` — authenticated DB entitlement check replaces forged-header trust.
  - ~316 (`rag_sources`) and ~362 (`rag_search`): call sites updated to await DB check, propagate auth error, return 402 when not entitled.
  - Tests: `missing_jwt_blocks_rag`, `forged_tier_header_does_not_bypass_rag_paywall`.
- `sakina-backend/src/handlers/dashboard.rs`
  - `get_guardrails(req, pool)` — authenticated, real query against `sakina_ai.safety_classifications`, honest empty result, `"source"` marker. Test: `unauthenticated_request_is_rejected`.

No `cargo` run (per instructions).
