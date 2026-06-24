# AGENT-observability — Hostile QA Audit (SakinaAL)

Scope: trace IDs, audit logging, outbox async jobs, metrics, structured logs.
Method: rg + Read of `F:\sakinaal\sakina-backend\src` + live query of in-cluster staging DB
(`sakina-mobile-staging` / `sakina-postgres-0`, role `sakina_staging_user`, db `sakina_mobile_staging`).
Did NOT run cargo. file:line evidence below. Live evidence: `reports/ultimate-hostile-audit/191-observability-live.txt`.

## Verdicts (summary)

| Area | Verdict | One-line reason |
|------|---------|-----------------|
| Trace IDs | **PARTIAL** | Ask creates+propagates trace_id and code persists it, but **live staging has 0 `sakina_ask` traces** and **0 `ask_shaikh_answers` rows** — Ask persistence is UNPROVEN in staging. |
| Audit logging | **PARTIAL** | HTTP `AuditMiddleware` is **stdout-only** (no DB write). Only deletion/export handlers persist `public.audit_logs`. Live: only `data_export_requested` rows exist. |
| Outbox | **FAIL** | `account_deletion_requested` + `data_export_requested` have **NO consumer** → live staging shows **9/9 export events `DeadLetter`**. Relay also INSERTs into a **non-existent `outbox.dead_letters` table** → background task crashes. |
| Metrics | **PARTIAL** | Real Prometheus exposition, but only 4 static/DB-count gauges. No request/latency/error/trace counters. |

---

## 1. TRACE IDs — PARTIAL

**Creation (Ask path):** `handlers/sakina_ask.rs:373-374` — `let trace_uuid = Uuid::new_v4(); let trace_id = trace_uuid.to_string();`.

**Propagation to brain router:** `sakina_ask.rs:482` passes `request_id: Some(trace_id.clone())` into `BrainRouteRequest`; `services/brain_controller.rs:109-114` reuses that `request_id` (only falls back to a fresh UUID when absent). So the Ask trace_id flows into the brain decision trace.

**Propagation to LLM gateway (over the wire):** `sakina_ask.rs:537` builds `SakinaLlmGatewayRequest { trace_id: trace_id.clone(), ... }`; `services/llm_gateway.rs:14-15` defines `trace_id: String`; `llm_gateway.rs:104-108` POSTs the whole struct as JSON (`.json(&request)`) to `{base_url}/generate`. **Confirmed: trace_id is serialized and sent to the gateway.**

**Persistence to `sakina_ai.brain_decision_traces`:** two independent writers:
- `sakina_ask.rs:203-257` `persist_trace()` — synchronous INSERT with `input_type='sakina_ask'` (literal, line 214), bound `request_id = trace_id`. Also inserts `sakina_ai.ask_shaikh_answers` (`sakina_ask.rs:259-287`).
- `services/brain_audit.rs:50-99` `record_trace()` — async `tokio::spawn` INSERT, `ON CONFLICT DO NOTHING`, **only fires when the audit log has a pool** (`pool: Some`). Pool is supplied only via `BrainAuditLog::with_pool` (`brain_audit.rs:27`), wired in `services/aia_orchestrator.rs:41` (`new_with_pool`). The bare `BrainAuditLog::new()` path (`aia_orchestrator.rs:27`, `brain_controller.rs:446`) has `pool: None` → **silently no-ops** (`brain_audit.rs:51` guards on `Some`).

**LIVE STAGING — Ask path persistence UNPROVEN / effectively absent** (`191-observability-live.txt`):
- `brain_decision_traces` = **9 rows**, but **every row has `input_type='question'`** and `request_id='agent-feedback-<epoch>-<n>-trace'`. **Zero rows with `input_type='sakina_ask'`.** Those 9 rows are fixtures seeded by `reports/final-hardening-evidence/923-agent-feedback-export-proof.txt` (string `agent-feedback-*-trace` only appears in that proof artifact, not in any producer code).
- `sakina_ai.ask_shaikh_answers` = **0 rows** — the Ask path's companion INSERT (`sakina_ask.rs:259`) has **never run successfully in staging**.

**Verdict: PARTIAL.** Code path is real and trace_id genuinely propagates handler→brain→gateway. But there is **no live evidence the Ask path persists a trace**; all 9 staging traces are agent-feedback test fixtures, and `ask_shaikh_answers` is empty. The async `record_trace` writer is a no-op on the non-pool construction paths.

## 2. AUDIT LOGGING — PARTIAL (stdout-only middleware; narrow DB persistence)

**HTTP `AuditMiddleware` is stdout-only.** `middleware/audit.rs:1-5` doc-comment admits it: *"events go to the fmt subscriber (stdout). A later tracing Layer can persist them to the audit.logs table."* The `call` impl (`audit.rs:49-77`) only emits `tracing::info!(event="http_request", ...)` (`audit.rs:66-74`). **No SQL, no `audit_logs` write.** Registered at `main.rs:599` `.wrap(middleware::AuditMiddleware)`. **The security agent's flag is CONFIRMED.**

**`sakina_ai.brain_decision_traces`/brain audit is also stdout-only at the in-memory layer:** `services/brain_audit.rs:34-48` `append()` only `tracing::info!(event="brain_decision", ...)` + pushes to an in-memory `Vec` (`brain_audit.rs:45-47`). Only `record_trace` (separate method) touches DB.

**Which actions actually write `public.audit_logs` rows:**
- `handlers/phase2.rs:500-516` — `request_account_deletion` → `INSERT ... ('account_deletion_requested','user',...)`.
- `handlers/phase2.rs:556-580` — `request_data_export` → `INSERT ... ('data_export_requested','user',...)`.
- `services/phase2.rs:1840-1857` — generic `create_audit_log()` (admin-driven, event_type supplied by caller).
- (Separate table) `services/phase2.rs:1309` admin → `public.admin_audit_logs`; `1863` → `public.security_logs`.

**Table:** `db/migrations/019_agent_feedback.sql:3-11` — `public.audit_logs` is **actor-based, no `user_id` column** (only `actor_id TEXT`), RLS service-role only (`019:19-26`).

**LIVE STAGING** (`191-observability-live.txt`): `public.audit_logs` = **9 rows, all `event_type='data_export_requested', actor_type='user'`**. So in staging only the data-export action has ever written an audit row — deletion has not even fired, and **no HTTP-request audit rows exist** (consistent with stdout-only middleware).

**Verdict: PARTIAL.** Security agent's claim CONFIRMED: middleware is stdout-only; only deletion/export (+admin generic) persist. The HTTP audit trail is **not** in the DB.

## 3. OUTBOX — FAIL

**Relay drains + marks Sent:** `services/outbox_relay.rs:22-90` `relay_events()` loops, `SELECT ... FROM outbox.events WHERE status='Pending' ... FOR UPDATE SKIP LOCKED LIMIT 25` (`outbox_relay.rs:24-30`), then for a **hardcoded allowlist of event types** marks `status='Sent'` (`outbox_relay.rs:35-51`). It does **no real work** — no Qdrant upsert, no deletion, no export, no notification dispatch. "Handling" = flipping status to Sent. Spawned at **`main.rs:517-522`** (`OutboxRelay::new(pool.clone())` + `tokio::spawn`). **Confirmed spawned.**

**Producer → Consumer matrix** (consumer = appears in relay allowlist `outbox_relay.rs:36-42`):

| event_type | Producer (file:line) | In relay allowlist? | Status |
|---|---|---|---|
| `chunk_indexed` | `services/ingestion_producer.rs:68-75` (only via `bin/ingest.rs` CLI, **not the running API**) | YES (`outbox_relay.rs:37`) | Consumer = no-op mark-Sent. Producer is an offline CLI, never runs in-server. |
| `account_deletion_requested` | `handlers/phase2.rs:518-532` | **NO** | **DEAD JOB** → retried 5× → DeadLetter. GDPR deletion never executed. |
| `data_export_requested` | `handlers/phase2.rs:582-597` | **NO** | **DEAD JOB** → DeadLetter. GDPR export never executed. **LIVE: 9/9 DeadLetter.** |
| `user_data_deleted` | **no Rust producer** (only proof scripts) | YES (`outbox_relay.rs:38`) | Consumer with no producer (orphan branch). |
| `backup_disaster_recovery_verified` | **no Rust producer** (only proof scripts) | YES (`outbox_relay.rs:39`) | Orphan branch. |
| `human_review_created` | **no Rust producer** | YES (`outbox_relay.rs:40`) | Orphan branch. |
| `notification_created` | **no Rust producer** | YES (`outbox_relay.rs:41`) | Orphan branch. |

So the **only two event types the running API actually produces** (`account_deletion_requested`, `data_export_requested`) are **exactly the two the relay does NOT handle**. Every allowlisted "consumer" type has no in-server producer.

**Bug — relay crashes on dead-letter path (missing table):** when an unhandled event hits `next_retry >= max_retries`, the relay UPDATEs to `DeadLetter` (`outbox_relay.rs:55-63`) **then** `INSERT INTO outbox.dead_letters (...)` (`outbox_relay.rs:64-71`). **LIVE: `outbox.dead_letters` does not exist** — `information_schema` shows the `outbox` schema contains only `events` (`191-observability-live.txt`). That INSERT errors, `?`-propagates out of `relay_events` (`outbox_relay.rs:71`), the `tokio::spawn` future returns Err and the **background relay task dies** (`main.rs:519-521` just logs and the task ends — no restart). The DeadLetter UPDATE commits first (separate statement), which is why staging rows show `status=DeadLetter, retry_count=5, max_retries=5`, but the relay self-terminates on the very next statement.

**LIVE STAGING** (`191-observability-live.txt`): `outbox.events` = **9 rows, all `data_export_requested` / `DeadLetter`** (retry 5/5). No `Pending`, no `Sent`, no `chunk_indexed`. This is direct proof that the only real producer's events are all dead-lettered.

**Verdict: FAIL.** The outbox is a status-flipper with no real consumers; the two GDPR-critical produced events have no handler and are 100% dead-lettered live; and the dead-letter code path references a non-existent table that crashes the relay.

## 4. METRICS — PARTIAL

`handlers/ops.rs:3-32` `metrics()` returns **real Prometheus text exposition** (`Content-Type: text/plain; version=0.0.4`, `ops.rs:30`). Gauges:
- `sakina_backend_up 1` — hardcoded literal (`ops.rs:15`).
- `sakina_waitlist_total {N}` — live `SELECT COUNT(*) FROM sakina_ai.waitlist` (`ops.rs:5-8`).
- `sakina_build_info{service="sakina-backend"} 1` — static (`ops.rs:21`).
- `sakina_backend_db_up {0|1}` — live `pool.acquire()` probe (`ops.rs:4`).

No request counters, latency histograms, error rates, outbox depth, trace counts, or per-route metrics. The format is genuine Prometheus, but the surface is a 4-gauge liveness/waitlist stub — **not** application observability.

**Verdict: PARTIAL** (real format + 2 live DB-backed gauges, but no RED/USE metrics).

## 5. LIVE DB CHECK — done

Saved to `reports/ultimate-hostile-audit/191-observability-live.txt`. Headline numbers (staging, 2026-06-06T13:11Z):
- `sakina_ai.brain_decision_traces` = **9** (all agent-feedback fixtures, `input_type='question'`; **0** `sakina_ask`).
- `sakina_ai.ask_shaikh_answers` = **0** (Ask path companion table empty).
- `public.audit_logs` = **9** (all `data_export_requested`/`user`; no HTTP-request rows).
- `outbox.events` = **9**, all `data_export_requested` / **DeadLetter** (retry 5/5).
- `outbox.dead_letters` table **does not exist**.

**Does `brain_decision_traces` have real Ask-path rows?** **NO.** It has rows, but none are from the Ask path (`input_type='sakina_ask'` count = 0); all 9 are agent-feedback proof fixtures. The Ask path's persistence is therefore **UNPROVEN in staging** (and its `ask_shaikh_answers` sibling is empty, suggesting it has not run end-to-end there).

## 6. Structured logs

Tracing is used consistently for structured events: `audit.rs:66` (`http_request`), `brain_audit.rs:35` (`brain_decision`), `outbox_relay.rs:51/72/83` (`outbox_event_sent`/`_dead_lettered`/`_retry_scheduled`). These are stdout structured logs only — **none are queryable/persisted** except where a separate explicit SQL INSERT exists. No central log sink wired in code reviewed.

## 7. Discrepancies / hostile flags

- **DB-persisting brain trace has different schema than the in-handler one.** `brain_audit.rs:57-74` inserts 14 columns *without* `workspace_id`; `sakina_ask.rs:209-216` inserts a 15-column variant *with* `workspace_id`, `request_id`, literal `'Mother Algorithm'`. Two writers, two shapes, one table.
- **Async trace writer silently disabled** on `BrainAuditLog::new()` paths (`brain_audit.rs:51` `if let Some(pool)`). Easy to think traces persist when they don't.
- **The relay's allowlist is inverted vs reality**: it handles 5 types, 4 of which have no in-server producer, and skips the 2 it actually receives.

## 8. UNPROVEN / could not confirm

- Whether the Ask endpoint persists a trace at runtime: **UNPROVEN** — no live `sakina_ask` trace exists in staging; not exercised here (no live Ask POST issued).
- Whether the relay task is currently alive or already crashed on the dead-letter insert: **UNPROVEN by query alone**; code path (`outbox_relay.rs:64-71` → missing table) strongly implies it errors out and the task ends after first dead-letter attempt. Pod-log inspection would confirm.
- Whether any out-of-band worker (k8s Job/cron) consumes `account_deletion_requested`/`data_export_requested`: searched Rust only; no in-repo consumer found. A non-Rust consumer is not ruled out, but events being 100% `DeadLetter` live indicates none is draining them.

## 9. Evidence index (file:line)

- Trace create/propagate: `handlers/sakina_ask.rs:373-374,482,537`; `services/brain_controller.rs:109-114`; `services/llm_gateway.rs:14-15,104-108`.
- Trace persist: `handlers/sakina_ask.rs:203-289`; `services/brain_audit.rs:34-99`; `services/aia_orchestrator.rs:27,41`.
- Audit middleware stdout-only: `middleware/audit.rs:1-5,49-77`; registered `main.rs:599`.
- Audit DB writers: `handlers/phase2.rs:500-516,556-580`; `services/phase2.rs:1840-1857,1309,1863`.
- Audit schema: `db/migrations/019_agent_feedback.sql:3-26`.
- Outbox relay: `services/outbox_relay.rs:22-90`; spawn `main.rs:517-522`; missing dead_letters table `outbox_relay.rs:64-71`.
- Outbox producers: `handlers/phase2.rs:518-532,582-597`; `services/ingestion_producer.rs:68-75` (CLI `bin/ingest.rs`).
- Metrics: `handlers/ops.rs:3-32`.
- Live DB: `reports/ultimate-hostile-audit/191-observability-live.txt`.
