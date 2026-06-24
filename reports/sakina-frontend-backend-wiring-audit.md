# Sakina AI — Frontend ↔ Backend Wiring Audit

Date: 2026-06-22. Detail: `test-results/audit-2026-06-22/agent-frontend.md`. App: `sakina-frontend` (Flutter).

## Verdict: genuinely wired (not a facade). Critical constraints PASS.

## Wiring
- Real `package:http` client → api-gateway. Base URL `lib/config/api_config.dart` default `http://localhost:8080/v1`, `--dart-define` overridable. No mock HTTP client in `lib/`.
- Endpoints called: `/auth/*`, `/api/sakina/ask`, `/classify`, `/islamic/*`, `/chat/*`, `/notifications/*`, `/support/*`, `/iman-journey/*`, `/api/memory/*`, `/api/multimodal/analyze`, `/subscriptions/*`, `/profiles/*`, `/account/*`, `/modules/*`.

## Critical checks
- **Direct-LLM: PASS.** grep ollama|11434|openai|chat/completions|api/generate|anthropic → zero direct calls. Only `ollamaStatus` status fields deserialized from backend. Inference = `POST /api/sakina/ask` → backend only.
- **Token storage: secure.** `flutter_secure_storage` for access+refresh JWT; sent as `Authorization: Bearer`; refresh on 401/403.

## Screens
- Wired: Login/Register, Ask Shaikh, Islamic Library (sources/search/ask), Quran/Prayer/Knowledge/Community modules (entitlement-gated read-only), Mental Wellness, Multimodal, Iman Journey, Compliance (GDPR export/delete), Support, Notifications.
- **Violations:** Kids Quran = static stub; **Tajweed Coach fabricates feedback** ("makhraj for 'Qaf' is 92% accurate") — SAK-019, breaks the no-fake rule.
- **Missing screens:** qibla, zakah, inheritance, masjid-near-me, scholar/admin (do not exist).

## State / i18n / citations
- Loading + error states solid on wired screens (`ChatErrorType`, `_humanizeError`, offline retry).
- **RTL gap (SAK-023):** `Directionality(rtl)` only in Islamic Library; Ask/Chat screen not RTL-aware; no app-level locale.
- Citations: `CitationBadge` used by Islamic Library/Multimodal; **Ask/Chat renders citations as plain text** (`chat_screen.dart:307-311`). Wired end-to-end via `SakinaAskResponse.citations`.

## Backend confirmation (runtime)
`/api/sakina/ask` returns the exact shape the Flutter client parses (`answer`, `trace_id`, `safety_state`, `citations[]`), with a real Quran 5:6 citation on the wudu query — so the contract the frontend depends on is satisfied by the live backend.
