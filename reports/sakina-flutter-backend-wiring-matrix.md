# Sakina Flutter Backend Wiring Matrix

| Screen | Flutter file | Backend endpoint | Auth required | Real API service | Fake client removed | Test proof | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account intro/login/register | `sakina-frontend/lib/screens/account_intro_screen.dart` | `/auth/register`, `/auth/login`, `/auth/logout` | Login/register public; logout authenticated | `AuthService`, `ApiService` | Yes | `flutter analyze`, `flutter test`, `flutter build apk --debug` | Wired |
| Chat/Q&A | `sakina-frontend/lib/screens/chat_screen.dart` | `/chat/conversations`, `/chat/conversations/{id}/messages`, `/api/brain/trace` | Yes for chat | `ApiService` | Demo bootstrap removed | `flutter analyze`, `flutter test` | Wired to real backend; LLM provider disabled closed locally |
| Profile | `sakina-frontend/lib/services/api_service.dart` | `/v1/profiles/{user_id}` | Yes | `ApiService` | Yes | E2E profile upsert succeeded | Wired |
| Memory consent/write | `sakina-frontend/lib/services/api_service.dart` | `/api/memory/write`, `/api/memory/read`, `/api/memory/delete` | Yes | `ApiService` | Yes | E2E memory write succeeded after backend auth enforcement | Wired |
| Subscriptions/entitlements | `sakina-frontend/lib/services/api_service.dart` | `/v1/subscriptions/*`, `/v1/entitlements/*` | Yes | `ApiService` | Static subscription bootstrap removed from chat UI | Backend tests | Partial / payments disabled closed |
| Multimodal | `sakina-frontend/lib/services/api_service.dart` | `/api/multimodal/analyze` | Should be authenticated for enabled flows | `ApiService` | No fake mobile client found | Security script negative check | Safe-disabled / not closed-beta feature |
| Settings/legal/privacy | `sakina-frontend/lib/app/app_strings.dart`, screens under `lib/screens` | Backend legal/config endpoints where present | Mixed | `ApiService` | No fake client found | Flutter tests/build | Partial store readiness |

## Proof Commands

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
git grep -n -i "FakeModuleApiClient\|SAKINA_API_TOKEN\|demo-token\|test-token\|placeholder\|dummy\|TODO\|localhost\|127.0.0.1" sakina-frontend/lib
```

Scanner result after fixes: no fake client/static token/localhost hits; remaining `confidence ?? 0.0` parsing defaults are response-shape fallbacks, not fake API clients.
