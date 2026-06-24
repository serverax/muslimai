# AGENT-multimodal — Hostile QA Audit: SakinaAL Multimodal Upload Flow

**Verdict: PARTIAL (PASS for image/document/text; audio is honestly DISABLED-FAIL-CLOSED; one non-blocking gap: no DB RLS, app-layer isolation only).**

No fake "analysis complete" path was found. The feature is real and grounded, with vision/OCR gated behind a real configured provider and honest `503 service_unavailable` when not configured. This is NOT a critical fake-result blocker.

---

## 1. Files inspected
- `sakina-frontend/lib/screens/multimodal_analysis_screen.dart` (UI screen, 1-199)
- `sakina-frontend/lib/screens/home_shell_screen.dart` (nav wiring, 11, 55, 99-102)
- `sakina-frontend/lib/services/api_service.dart` (HTTP client + response model, 811-850, 2222-2271)
- `sakina-backend/src/handlers/multimodal.rs` (HTTP handlers, 1-177)
- `sakina-backend/src/services/multimodal.rs` (service logic, 1-451)
- `sakina-backend/src/services/auth.rs` (JWT/session auth, 29-159)
- `sakina-backend/src/main.rs` (route registration, 552, 578, 779-788, 1011-1020)
- `sakina-backend/db/migrations/015_user_memory_multimodal.sql` (schema, 19-39)
- `sakina-backend/chunking.py` (1-20 — NOT in multimodal flow; Arabic ingestion only)

## 2. Line-number evidence

**Frontend screen is REAL and calls backend:**
- `multimodal_analysis_screen.dart:98` calls `widget.api.analyzeMultimodal(...)` — no local fake.
- `:39-58` camera/gallery via `image_picker`; `:60-84` document via `file_picker` (txt/pdf only).
- `:172-192` renders `result.redactedText` + real `result.citations` from backend; NO hardcoded "analysis complete" string anywhere.
- `:118-130` error handling maps real HTTP codes (401/403/413/415/422/429/500).

**Frontend reachable from nav:**
- `home_shell_screen.dart:55` `MultimodalAnalysisScreen(session: widget.session)` in screens list; `:99-102` bottom nav "Analyze" destination (`document_scanner` icon). Reachable.

**Frontend HTTP call is a real multipart POST:**
- `api_service.dart:823-840` `http.MultipartRequest('POST', .../api/multimodal/analyze)`, sets `Authorization: Bearer`, `x-request-id`, fields `asset_type/mime_type/language`, `MultipartFile.fromBytes('file', ...)`.
- `:845` parses 200 into `MultimodalAnalysisResponse.fromJson`; `:849` throws on non-200.
- `:2245-2270` `fromJson` requires non-empty `asset_id` (`:2247-2249` throws `FormatException` if missing) and pulls citations from `islamic_answer.citations` — grounded in backend output, not synthesized.

**Backend handler validates JWT + ownership:**
- `handlers/multimodal.rs:87` `authenticated_user_id(&req, service.pool())` (analyze), `:157` (get_asset), `:171` (delete_asset) — all three gated.
- `auth.rs:121-158` real validation: `validate_jwt` (`:131`) verifies HS256 signature (`auth.rs:100-103`) + exp (`:112-113`), then DB session lookup against `public.auth_sessions` (`:134-148`) with `expires_at > now()` and `revoked_at IS NULL`, plus JWT-sub/session-sub equality check (`:155-157`). Test-only header bypass is guarded `if !cfg!(test) { return None }` (`auth.rs:30-32`) — not reachable in release.

**File type + size validation (two layers):**
- Handler stream cap: `handlers/multimodal.rs:67-69` rejects > 10 MiB during multipart read; text fields capped 4096 bytes (`:30-32`).
- Service `validate_media` (`services/multimodal.rs:86-109`): empty reject (`:87`), size reject vs `SAKINA_MULTIMODAL_MAX_BYTES` default 5 MiB (`:75-80`, `:90-94`), and magic-byte checks: PNG (`:96`), JPEG (`:97`), PDF `%PDF-` (`:99`), `text/plain` (`:98`). Mismatched/unknown → `bad_request` (`:105`).

**Private storage + owner-only retrieval:**
- `persist_private_file` (`:111-135`) writes under `storage_root()/<user_id>/<sha256>-<sanitized_name>`; filename sanitized via `sanitize_filename::sanitize` (`:120`), capped 96 chars. Storage root from `SAKINA_MULTIMODAL_STORAGE_DIR` (`:69-73`).
- `get_asset` (`:384-401`) `WHERE id = $1 AND user_id = $2` — owner-scoped.
- `delete_asset` (`:417-429`) `WHERE id = $1 AND user_id = $2` — owner-scoped.
- DB row insert binds `user_id` (`:347`); `storage_scope='user'` (`:343`).

## 3. Commands run
- `rg -n -i "upload|multipart|file|image|audio|document|ocr|vision|camera|gallery|multimodal|mime|size|asset" sakina-frontend/lib sakina-backend/src` → `reports/ultimate-hostile-audit/100-multimodal-scan.txt` (676 lines)
- `rg -ln -i "multimodal|upload|MultipartFile|..." sakina-frontend/lib`
- `rg -n -i "multimodal" sakina-backend/src/main.rs` (route registration)
- `rg -rn -i "multimodal_assets" sakina-backend/db --glob "*.sql" | rg -i "ROW LEVEL|POLICY|RLS"` → empty (no RLS)

## 4. Evidence files
- `reports/ultimate-hostile-audit/100-multimodal-scan.txt` (saved, 676 lines)

## 5. Failures / blockers
- **None CRITICAL.** No fake-analysis path exists.

## 6. Not-wired
- None. Frontend → `analyzeMultimodal` → `/api/multimodal/analyze` → `MultimodalService::analyze` → DB insert + citations is fully wired end to end. `get_asset`/`delete_asset` routes registered (`main.rs:783-788`) but no frontend caller observed (read-back/delete UI not implemented — minor, not a blocker for the upload flow).

## 7. Fake / mock / bypass
- **No fake analysis result.** The OCR/vision extraction is REAL and provider-gated:
  - `provider_extract_text` (`services/multimodal.rs:137-161`): `text/plain` → real local UTF-8 extraction (`:140-147`); otherwise dispatches to `SAKINA_MULTIMODAL_PROVIDER`.
  - `openai_compatible_vision` (`:227-299`): real HTTP POST to `/v1/chat/completions` with base64 data-url image; **requires `SAKINA_MULTIMODAL_API_KEY`/`OPENAI_API_KEY` or returns `503 service_unavailable`** (`:233-239`). Empty provider output → `503` (`:292-294`). NOT faked.
  - `local_tesseract_ocr` (`:163-225`): real `tesseract` subprocess; missing binary → `503` (`:196-200`); empty OCR → `503` (`:219-223`).
  - **Audio is fail-closed**: `validate_media` (`:100-104`) returns `503 "speech-to-text provider is not configured"` for audio/mpeg|wav|mp4 — honest disable, no fake transcript.
- Test-only auth bypass (`auth.rs:29-38`) and test JWT secret (`:53-55`) are `cfg!(test)`-gated — not present in release builds.

## 8. Repairs
- None applied (audit-only, no cargo).

## 9. Proof / grounding & open issues
- **Grounding/citations DO run on extracted text** (answers the "ungrounded?" question — it is grounded):
  - After extraction, PII redaction runs (`services/multimodal.rs:312`, `redact_text` → `pii_redaction::redact_pii`), then the REDACTED text is fed into the verified Islamic pipeline via `aia.answer_islamic(...)` (`:324-335`). The system prompt forbids religious rulings from the vision model (`:257`) and routes ruling-generation only through the cited Islamic service.
  - Persisted metadata records `citations_count`, `generated_from_verified_sources`, `retrieval_strategy` (`:363-365`); frontend surfaces `result.citations` (`api_service.dart:2266-2270`). Multimodal output is therefore grounded, not free-form.
  - Mother-Brain gate before analysis: `aia.route(...)` and `if !route.can_generate` → `401` (`handlers/multimodal.rs:114-130`).
- **Open issue (non-blocking, NOT fake):** `multimodal_assets` table (migration `015_user_memory_multimodal.sql:19-32`) has **NO `ENABLE ROW LEVEL SECURITY` and NO RLS policy** (grep for `ROW LEVEL|POLICY|RLS` returns nothing). User isolation depends entirely on app-layer `WHERE user_id = $2` (which IS present and correct in `get_asset`/`delete_asset`). Defense-in-depth gap if the table is ever queried by code lacking the user filter, but current code paths are owner-scoped.

### UNPROVEN (static analysis limits — cannot run cargo/flutter)
- Runtime confirmation that a real PNG/JPEG yields real OCR text (provider/tesseract not executed here).
- Runtime confirmation the 503 paths actually fire when keys/binaries are absent (code shows they should).
- Runtime confirmation of cross-user 404 on `get_asset` for a non-owner (query is correct; not executed).
