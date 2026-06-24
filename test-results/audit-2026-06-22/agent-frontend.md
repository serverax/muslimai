# Frontend wiring audit (agent result, 2026-06-22)

Verdict: frontend largely REAL/wired. Direct-LLM PASS. Secure token storage. Some stubs.

## API wiring
- Base URL `lib/config/api_config.dart:2-5`: default `http://localhost:8080/v1`, overridable via `--dart-define=SAKINA_API_BASE_URL`.
- Staging `lib/config/staging_client_config.dart:3-6` + `mobile/.env.staging.example:1` → `https://api.sakina-mobile-staging.example` (PLACEHOLDER host).
- Real `package:http` client. No mock client in lib/.
- Endpoints: `/auth/{register,login,refresh,me,logout,sessions}`, `/api/sakina/ask`, `/api/user-learning/*`, `/classify`, `/islamic/*`, `/chat/*`, `/notifications/*`, `/support/*`, `/iman-journey/*`, `/dua-list/*`, `/api/memory/*`, `/api/multimodal/analyze`, `/subscriptions/{userId}/*`, `/profiles/{userId}*`, `/account/{delete,export}-request`, `/modules/*`.

## Direct-LLM check — PASS
grep ollama|11434|OpenAI|chat/completions|api/generate|anthropic → ZERO direct calls. Only `ollamaStatus` status fields deserialized. Inference = POST `/api/sakina/ask` → backend.

## Token storage — secure
flutter_secure_storage for access+refresh JWT (`auth_service.dart:32,114-118`). Bearer attached `api_service.dart:854-864`. Refresh on 401/403.

## Screens
- Wired: Login/Register, Ask Shaikh chat, Quran/Prayer/Knowledge/Community modules (gated), Islamic Library, Mental Wellness, Multimodal, Iman Journey, Compliance(GDPR), Support/Notifications.
- STUBS: Kids Quran static (`kids_quran_screen.dart:25-30,76` injects ApiService, never calls). Tajweed Coach FABRICATED feedback "makhraj for 'Qaf' is 92% accurate" (`tajweed_coach_screen.dart:85-87`) — fake feature.
- NOT PRESENT: qibla, zakah, inheritance, masjid-near-me, scholar/admin screens.

## State/RTL/citations
- Loading+error good on wired screens.
- RTL only in `islamic_library_screen.dart:99-100`. Chat/Ask NOT RTL-aware (`chat_screen.dart:289-291`). No app-level locale.
- Citations: CitationBadge in Islamic Library/Multimodal; Chat renders plain text `'- title | chapter | grade'` (`chat_screen.dart:307-311`). Wired via SakinaAskResponse.citations.
