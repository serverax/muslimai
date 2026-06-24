# Sakina Phase 25 UI Implementation Backlog (Phase 24G)

Status values in upstream inventory: `BUILT` / `PARTIAL` / `PLACEHOLDER` / `NOT STARTED`.

## P0 (Critical Foundation)

| Feature | User story | Likely files | Backend dep | DB dep | Acceptance test | Complexity |
|---|---|---|---|---|---|---|
| Route architecture baseline (named routes/go_router) | As a user, I want stable navigation so deep links and testing are consistent. | `lib/main.dart`, `lib/navigation/*` (new), all screen files | None new (routing only) | None | Widget test verifies route map and transitions for welcome->onboarding->account->home | M |
| Missing Islamic library screen implementation | As a user, I want source/document/chunk browsing from UI. | `lib/screens/islamic_library_screen.dart` (new), `lib/screens/home_shell_screen.dart`, `lib/services/api_service.dart` | `/islamic/sources`, `/islamic/documents`, `/islamic/documents/{id}/chunks` | `rag_documents`, `rag_chunks`, `rag_embeddings` | Integration test loads sources/documents/chunks and renders empty/error states safely | L |
| Chat production UX hardening | As a user, I want clear chat states for loading, retry, and citation validity. | `lib/screens/chat_screen.dart`, `lib/widgets/citation_widget.dart` | `/chat/*`, `/rag/query`, feedback/report endpoints | `chat_threads`, `chat_messages`, RAG tables | Widget + API-mock tests for malformed citations, fallback message, feedback/report success | M |
| Dedicated settings shell | As a user, I want one place for profile/privacy/subscription/offline controls. | `lib/screens/settings_screen.dart` (new), `lib/screens/home_shell_screen.dart` | Existing profile/privacy/subscription/sync endpoints | Mixed (users/user_profiles/sync/subscription future tables) | Widget test confirms navigation to each settings subsection and persisted toggles | M |
| Replace broken import and compile blockers | As a developer, I want mobile app to compile with no missing screen imports. | `lib/screens/home_shell_screen.dart`, add missing `lib/screens/islamic_library_screen.dart` | None | None | `flutter test` and analyze complete without missing import/symbol errors | S |

## P1 (Core Product Journeys)

| Feature | User story | Likely files | Backend dep | DB dep | Acceptance test | Complexity |
|---|---|---|---|---|---|---|
| Subscription/paywall screens | As a user, I want to understand premium requirements before blocked actions. | `lib/screens/subscription_screen.dart` (new), `lib/services/module_service.dart` | `/subscriptions/{id}/entitlements`, activate endpoint | Subscription/payment tables (currently gap) | Widget test for free vs premium states and upgrade CTA behavior | M |
| Family profile management screen | As a family user, I want to edit household details and consent controls. | `lib/screens/family_profile_screen.dart` (new), `lib/services/api_service.dart` | `/profiles/{id}/family`, iman privacy/family fields | Family-related tables (currently gap) | Integration test updates family settings and reflects on reload | M |
| Notification center and reminders | As a user, I want to review reminder settings and notification events. | `lib/screens/notifications_screen.dart` (new), `lib/screens/iman_journey_screen.dart` | `/notifications/*`, `/iman-journey/{id}/privacy` | `notifications`, device token/template tables (gaps) | Test toggles reminders and validates message list state handling | M |
| Profile and privacy dedicated screens | As a user, I want explicit privacy controls outside iman journey. | `lib/screens/profile_screen.dart` (new), `lib/screens/privacy_screen.dart` (new) | `/profiles/{id}`, `/iman-journey/{id}/privacy` | `users`, `user_profiles` + privacy schema gap | Widget test saves privacy options and confirms persisted state | M |
| Islamic Q&A dedicated flow | As a user, I want a separate Q&A screen with source filters and safety notices. | `lib/screens/islamic_qa_screen.dart` (new), `lib/services/api_service.dart` | `/islamic/search`, `/islamic/ask` | RAG tables | Integration test checks fallback display when citations absent/malformed | M |

## P2 (Feature Depth)

| Feature | User story | Likely files | Backend dep | DB dep | Acceptance test | Complexity |
|---|---|---|---|---|---|---|
| Prayer times and calendar screen | As a user, I want daily prayer schedule and calendar context. | `lib/screens/prayer_times_screen.dart` (new) | New prayer-times/calendar APIs required | New prayer/calendar schema required | Failsafe UI test with mocked API and timezone variations | L |
| Qibla direction screen | As a user, I want qibla direction guidance with calibration hints. | `lib/screens/qibla_screen.dart` (new) | Sensor/service + qibla API likely needed | none or new config tables | Device/integration test verifies orientation update and fallback text | L |
| Offline mode control center | As a user, I want explicit offline mode and sync status visibility. | `lib/screens/offline_sync_screen.dart` (new), `lib/services/local_db_service.dart`, `lib/services/sync_service.dart` | `/users/pubkey`, `/sync/backup/{id}` | local SQLCipher `messages`, server `sync_state` | Integration test simulates offline, queues actions, syncs when online | L |
| Module detail expansions (Quran/Prayer/Knowledge/Community) | As a user, I want useful content beyond read-only status cards. | `lib/screens/*_module_screen.dart`, new detail widgets | `/modules/*/overview` + additional content APIs | `modules`, `module_lessons`, `user_module_progress` | Widget tests confirm progression cards and provenance rendering | M |
| Admin/support conversation UI | As a user, I want in-app support thread history and responses. | `lib/screens/support_screen.dart` (new), `lib/services/api_service.dart` | `/support/tickets*` | support/admin tables (schema gap) | Integration test create ticket, append message, and reload thread | M |

## P3 (Polish and Governance)

| Feature | User story | Likely files | Backend dep | DB dep | Acceptance test | Complexity |
|---|---|---|---|---|---|---|
| UX consistency and design token pass | As a user, I want consistent typography, spacing, and states across all screens. | `lib/config/theme.dart`, all `lib/screens/*` | none | none | Golden tests for key screen states in EN/AR | M |
| Accessibility hardening pass | As a user with accessibility needs, I want better semantics and focus behavior. | all screens, especially chat/forms | none | none | Semantics tests for labeled controls and screen reader order | M |
| Arabic RTL completion pass | As an Arabic user, I want full RTL parity for all new screens. | all localized screens, `app/app_strings.dart` | none | none | Widget tests assert RTL alignment and mirrored nav where needed | M |
| Telemetry and journey instrumentation | As a product owner, I want measurable funnel and error metrics. | new analytics service + screen hooks | analytics backend required | analytics event store required | Tests verify key events on onboarding/chat/subscription journeys | S |
| Error catalog and fallback copy governance | As a user, I want clear, non-misleading error and safe fallback messaging. | `lib/screens/chat_screen.dart`, `lib/screens/iman_journey_screen.dart`, strings | none | none | Snapshot tests cover standardized error/fallback messages | S |

## Dependency Gaps to Resolve Before P1 Completion

- Subscription/payment persistence schema not visible in current migrations.
- Support ticket and feedback/report persistence schema not visible in current migrations.
- Iman journey and dua-list persistence tables not visible in current migrations.
- Prayer calendar/qibla APIs are not yet represented in mobile client code.
