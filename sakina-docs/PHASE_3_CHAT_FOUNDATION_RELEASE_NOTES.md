# Phase 3 Chat Foundation Release Notes

Date: 2026-05-28  
Branch: `qa-security-hardening`

## What was implemented

### Backend
- Added module status contract models and chat request/response models in:
  - `sakina-backend/src/models/mod.rs`
- Added module status endpoints and tests in:
  - `sakina-backend/src/handlers/modules.rs`
- Added chat foundation handlers and tests in:
  - `sakina-backend/src/handlers/chat.rs`
- Wired handlers in:
  - `sakina-backend/src/handlers/mod.rs`
  - `sakina-backend/src/main.rs`
- Kept normalized backend errors under:
  - `sakina-backend/src/error.rs`

### Frontend
- Added typed module status DTO/client and local+backend status resolution:
  - `sakina-frontend/lib/services/module_service.dart`
- Replaced non-chat tabs with placeholder-only status screen (no content screens):
  - `sakina-frontend/lib/screens/home_shell_screen.dart`
  - `sakina-frontend/lib/screens/module_status_placeholder_screen.dart`
- Added tests for status parsing and disabled short-circuit behavior:
  - `sakina-frontend/test/module_service_test.dart`

### DB migrations
- Added migration:
  - `sakina-backend/db/20260528_phase3_chat_foundation.sql`
- Updated bootstrap SQL:
  - `sakina-backend/db/init.sql`

## New API endpoints

### Module status foundation
- `GET /v1/modules`
- `GET /v1/modules/chat/status`
- `GET /v1/modules/quran/status`
- `GET /v1/modules/prayer/status`
- `GET /v1/modules/community/status`
- `GET /v1/modules/knowledge/status`

Root aliases are also wired (route consistency):
- `/modules`
- `/modules/chat/status`
- `/modules/quran/status`
- `/modules/prayer/status`
- `/modules/community/status`
- `/modules/knowledge/status`

### Chat foundation (no LLM connection)
- `POST /v1/chat/conversations`
- `GET /v1/chat/conversations/{id}`
- `POST /v1/chat/conversations/{id}/messages`

Root aliases are also wired:
- `POST /chat/conversations`
- `GET /chat/conversations/{id}`
- `POST /chat/conversations/{id}/messages`

Message insert returns only this honest placeholder:
- `"This chat module is being prepared. No AI answer has been generated yet."`

## Enabled vs disabled

- Chat: enabled by default (active unless explicitly disabled with `SAKINA_FEATURE_CHAT=false`).
- Quran: disabled by default (`SAKINA_FEATURE_QURAN=false`).
- Prayer: disabled by default (`SAKINA_FEATURE_PRAYER=false`).
- Community: disabled by default (`SAKINA_FEATURE_COMMUNITY=false`).
- Knowledge: disabled by default (`SAKINA_FEATURE_KNOWLEDGE=false`).

Frontend behavior:
- Disabled modules short-circuit locally and do not call backend status/content endpoints.
- Non-chat modules render placeholder states only (no content screens).

## Test commands and outputs

- `cargo fmt -- --check` -> PASS
- `cargo test --all-targets` -> PASS
  - `56 passed; 0 failed` (lib)
  - `1 passed; 0 failed` (main)
- `flutter analyze` -> PASS (`No issues found!`)
- `flutter test` -> PASS (`All tests passed!`, 28 tests)
- `flutter pub get && flutter analyze && flutter test && flutter build apk --release` -> PASS
  - APK built: `sakina-frontend/build/app/outputs/flutter-apk/app-release.apk`

## CI and image evidence

- Frontend CI run proving APK chain steps:
  - <https://github.com/serverax/muslimai/actions/runs/26578239662>

- Latest manual Frontend CI dispatch from `qa-security-hardening`:
  - Dispatch command: `gh workflow run frontend-ci.yml --ref qa-security-hardening`
  - Run URL: <https://github.com/serverax/muslimai/actions/runs/26594172525>
  - Conclusion: `success`
  - Step status (`gh run view 26594172525 --json jobs`):
    - `Get dependencies` -> `success`
    - `Analyze` -> `success`
    - `Run tests` -> `success`
    - `Build APK` -> `success`
  - Log evidence (`gh run view 26594172525 --log`):
    - `Run tests`: `25 tests passed.`
    - `Build APK`: `Built build/app/outputs/flutter-apk/app-release.apk`

- Workflow dispatch trigger verification on branch:
  - Command: `gh api "repos/serverax/muslimai/contents/.github/workflows/frontend-ci.yml?ref=qa-security-hardening"`
  - Evidence: workflow contains `on.workflow_dispatch`.

- SakinaAI Images run:
  - <https://github.com/serverax/muslimai/actions/runs/26579842369>

- Exact image tags observed in CI logs:
  - `ghcr.io/serverax/sakina-backend:9f34c38`
  - `ghcr.io/serverax/sakina-frontend:9f34c38`

## Known limitations

- Chat foundation persists conversations/messages only; no LLM/provider invocation is connected.
- Non-chat modules remain intentionally disabled/coming-soon unless explicitly enabled by release flags.
- Frontend release APK is currently built with debug signing fallback when `android/key.properties` is absent.
- Frontend secret scan workflow step is **PARTIAL** on GitHub runner because `rg` is not installed:
  - exact error: `/home/runner/work/_temp/d8b45dd4-8575-489c-bd62-b1e39a68a65e.sh: line 1: rg: command not found`

## Rollback commands

### App rollback (git)
```bash
git checkout qa-security-hardening
git restore sakina-backend/src sakina-backend/db sakina-frontend/lib sakina-frontend/test sakina-docs
```

### Database rollback (chat tables)
```sql
DROP TABLE IF EXISTS sakina_ai.messages;
DROP TABLE IF EXISTS sakina_ai.conversations;
```

### Container rollback (if deploying image tags)
```bash
kubectl -n sakina set image deploy/sakina-backend sakina-backend=ghcr.io/serverax/sakina-backend:<previous-tag>
kubectl -n sakina set image deploy/sakina-frontend sakina-frontend=ghcr.io/serverax/sakina-frontend:<previous-tag>
```
