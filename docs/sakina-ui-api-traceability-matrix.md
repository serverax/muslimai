# Sakina UI/API Traceability Matrix (Phase 24F)

Status legend: `BUILT` / `PARTIAL` / `PLACEHOLDER` / `NOT STARTED`.

## Matrix

| Screen / Journey | Current UI evidence | API endpoints (client evidence) | DB tables (migration evidence) | RAG / Payment / Notification / Admin dependency | Status | Gap / risk |
|---|---|---|---|---|---|---|
| Welcome + language | `screens/welcome_screen.dart` | none required | local prefs only (no backend table) | none | BUILT | No analytics traceability yet. |
| Onboarding completion | `screens/onboarding_screen.dart`, `app/app_state.dart` | none required | local prefs only | none | BUILT | No remote onboarding state sync. |
| Waitlist submit | `screens/account_intro_screen.dart` | `POST /waitlist` | No waitlist table in current migrations | none | PARTIAL | API exists, DB schema evidence missing in repo migrations. |
| Home shell navigation | `screens/home_shell_screen.dart` | none directly | none | none | PARTIAL | Imports `islamic_library_screen.dart` but file not found. |
| Chat send + evidence | `screens/chat_screen.dart` | `POST /chat/conversations`, `POST /chat/conversations/{id}/messages`, `POST /rag/query` | `chat_threads`, `chat_messages`, `rag_documents`, `rag_chunks`, `rag_embeddings` | RAG: Yes | PARTIAL | No dedicated transcript persistence wiring in screen to local DB service. |
| Chat feedback/report | `screens/chat_screen.dart` | `POST /chat/messages/{id}/feedback`, `POST /chat/messages/{id}/report` | No feedback/report tables in migrations | Admin: indirect moderation relevance | PARTIAL | Backend contract exists; schema evidence absent for storage. |
| User bootstrap flow | `screens/chat_screen.dart` (`Init User Flows`) | `/auth/register`, `/auth/sessions`, `/profiles/{id}`, `/profiles/{id}/family` | `users`, `user_profiles` | Payment/Notification dependent follow-up | PARTIAL | Auth/session/family tables not fully represented in migrations. |
| Subscription activation / entitlements | `screens/chat_screen.dart`, `services/module_service.dart` | `/subscriptions/{id}/activate`, `/subscriptions/{id}/entitlements` | No subscription tables in migrations | Payment: Yes | PARTIAL | Payment persistence schema not present in current migration set. |
| Notification template/send/token | `screens/chat_screen.dart` | `/notifications/templates`, `/notifications/send`, `/notifications/device-tokens` | `notifications` only | Notification: Yes | PARTIAL | Template/device-token tables not present in migrations. |
| Support ticket flow | `screens/chat_screen.dart` | `/support/tickets`, `/support/tickets/{id}/messages`, `GET /support/tickets/{id}` | No support tables in migrations | Admin: likely support/admin tooling | PARTIAL | API exists; DB schema evidence missing. |
| Quran module overview | `screens/module_read_only_state_screen.dart` + module service | `GET /modules/quran/overview` | `modules`, `module_lessons` (generic), plus RAG tables | RAG: Yes | PLACEHOLDER | Read-only shell, disabled by default feature flag. |
| Prayer module overview | same module shell | `GET /modules/prayer/overview` | `modules`, `module_lessons` (generic) | none explicit | PLACEHOLDER | No prayer-specific UI (times/qibla/calendar). |
| Knowledge module overview | same module shell | `GET /modules/knowledge/overview` | `modules`, `module_lessons` | RAG: possible | PLACEHOLDER | No dedicated topic drill-down UX. |
| Community module overview | same module shell | `GET /modules/community/overview` | `modules` (generic) | Admin/moderation: potential | PLACEHOLDER | No community interaction UI yet. |
| Iman journey dashboard | `screens/iman_journey_screen.dart` | `GET/PUT /iman-journey/{userId}` | No iman-specific tables in migrations | RAG: via evidence bundle fields | PARTIAL | API present but schema tables absent in migration evidence. |
| Iman privacy controls | `screens/iman_journey_screen.dart` | `GET/PUT /iman-journey/{userId}/privacy` | No privacy table evidence | Notification: reminder toggle linkage | PARTIAL | Privacy controls exist only inside journey screen. |
| Personal dua list | `screens/iman_journey_screen.dart` | `GET/POST /dua-list/{userId}` | No dua list table evidence | none | PARTIAL | Works at API layer; no standalone dua module screen. |
| Islamic library browse/search/ask | no connected screen | `/islamic/sources`, `/islamic/documents`, `/islamic/documents/{id}/chunks`, `/islamic/search`, `/islamic/ask` | `rag_documents`, `rag_chunks`, `rag_embeddings` likely backing search | RAG: Yes | NOT STARTED | API client supports it, but no UI screen or route implementation. |
| Offline history + encrypted backup | `chat/chat_controller.dart`, `services/local_db_service.dart`, `services/sync_service.dart` | `/users/pubkey`, `/sync/backup/{userId}` | `sync_state` (server), local SQLCipher `messages` table | none | PARTIAL | No in-app settings UX to trigger backup/restore/offline mode. |
| Settings/profile/privacy/family/subscription dedicated screens | no screen file | mixed APIs already listed | mixed | Payment/Notification/Admin all impacted | NOT STARTED | Missing dedicated routes and UX architecture. |
| Prayer tools (qibla/calendar/reminders center) | no screen file | none implemented in client | none | Notification likely | NOT STARTED | No qibla/calendar/reminder center flows in UI code. |

## Additional Evidence Notes

- Mobile API client endpoints: `sakina-frontend/lib/services/api_service.dart`.
- Existing migration tables: `sakina-backend/db/migrations/002_users_profiles.sql` through `012_seed_reference.sql`.
- Feature gating: `sakina-frontend/lib/app/feature_flags.dart`, `sakina-frontend/lib/services/module_service.dart`.
- Staging OpenAPI file currently minimal and not aligned with full mobile client endpoint surface: `docs/sakina-mobile-openapi.yaml`.
