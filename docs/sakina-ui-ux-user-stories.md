# Sakina UI/UX User Stories (Phase 24C)

Status legend used in this document: `BUILT` / `PARTIAL` / `PLACEHOLDER` / `NOT STARTED`.

## Story Group 1 - Onboarding Introduction
Current status: `PARTIAL`

- **Story:** As a first-time user, I want a short onboarding flow so I understand Sakina's purpose and limits.
- **Given** the app launches with onboarding incomplete
- **When** I tap `Get Started` on `WelcomeScreen` and complete slides on `OnboardingScreen`
- **Then** onboarding completion is persisted and I am taken to account intro.

## Story Group 2 - Language Selection
Current status: `BUILT`

- **Story:** As a bilingual user, I want to switch between English and Arabic from the entry screen.
- **Given** I am on `WelcomeScreen`
- **When** I change the language dropdown
- **Then** localized text updates and the selection is stored in app preferences.

## Story Group 3 - Authentication and Account Bootstrap
Current status: `PARTIAL`

- **Story:** As a new user, I want account/session/profile bootstrapping so backend-dependent features can operate.
- **Given** I open chat workspace and trigger initialization
- **When** `Init User Flows` runs
- **Then** register/session/profile/family/subscription/device-token APIs are called and entitlements are shown.

## Story Group 4 - Guest Preview Entry
Current status: `PARTIAL`

- **Story:** As a guest user, I want a limited preview path before full account setup.
- **Given** I am on `WelcomeScreen`
- **When** I tap `Continue with limited preview`
- **Then** I reach `AccountIntroScreen` without a dedicated guest account model.

## Story Group 5 - Home Navigation Shell
Current status: `PARTIAL`

- **Story:** As a user, I want a persistent bottom navigation shell to switch between primary modules.
- **Given** I am on `HomeShellScreen`
- **When** I tap nav destinations (Chat, Quran, Prayer, Community, Knowledge, Iman Journey)
- **Then** the selected content view is shown in-place.

## Story Group 6 - Chat with Evidence
Current status: `PARTIAL`

- **Story:** As a user, I want chat answers backed by verified evidence.
- **Given** I submit a question in `ChatScreen`
- **When** chat message and RAG query APIs succeed
- **Then** evidence rows are displayed only for verified-shape citations; otherwise safe fallback text is shown.

## Story Group 7 - Islamic Q&A Safety Guardrails
Current status: `PARTIAL`

- **Story:** As a user, I want Islamic answers to enforce citation shape and safe fallback behavior.
- **Given** a backend response has malformed or empty sources
- **When** chat or iman reminder data is rendered
- **Then** malformed evidence is discarded and non-authoritative fallback language is shown.

## Story Group 8 - Quran Module View
Current status: `PLACEHOLDER`

- **Story:** As a Quran learner, I want Quran module insights when the feature is enabled and entitlement is valid.
- **Given** Quran feature flag and subscription checks pass
- **When** module overview API responds
- **Then** read-only provenance and review status are shown.

## Story Group 9 - Prayer Module View
Current status: `PLACEHOLDER`

- **Story:** As a user, I want prayer guidance availability and provenance transparency.
- **Given** Prayer feature is enabled and entitled
- **When** Prayer overview API responds
- **Then** read-only module state and source provenance are rendered.

## Story Group 10 - Hadith/Dua/Islamic Library Exploration
Current status: `NOT STARTED`

- **Story:** As a user, I want dedicated Hadith/Dua/library browse/search screens.
- **Given** Islamic data endpoints exist in API client
- **When** I open library features
- **Then** I should be able to browse sources/documents/chunks and ask Islamic Q&A from UI screens (currently no connected screen implementation).

## Story Group 11 - Iman Journey and Privacy Controls
Current status: `PARTIAL`

- **Story:** As a user, I want a daily iman dashboard with privacy toggles and personal dua management.
- **Given** I open `ImanJourneyScreen`
- **When** I load journey data, toggle privacy switches, or add dua
- **Then** journey cards update and privacy/dua APIs persist changes.

## Story Group 12 - Reminders and Notifications
Current status: `PARTIAL`

- **Story:** As a user, I want reminder preferences and delivery pathways.
- **Given** reminder/privacy controls and notification APIs exist
- **When** I save privacy settings or trigger notification flow
- **Then** reminder/privacy state persists and notification APIs can be invoked.

## Story Group 13 - Family Features
Current status: `PARTIAL`

- **Story:** As a family user, I want household profile and consent-based family reminders.
- **Given** family profile APIs and iman family reminder fields exist
- **When** user bootstrapping runs and journey data is loaded
- **Then** family profile creation and reminder consent states are available (without dedicated family management screens).

## Story Group 14 - Subscription and Entitlements
Current status: `PARTIAL`

- **Story:** As a user, I want clear entitlement gating for premium modules.
- **Given** module access is evaluated by entitlement and flags
- **When** subscription tier is free or features are disabled
- **Then** module states present `subscription required` or `coming soon/disabled` messaging.

## Story Group 15 - Settings, Privacy, Offline, and Data Controls
Current status: `NOT STARTED`

- **Story:** As a privacy-conscious user, I want dedicated settings screens for profile, privacy exports/deletion, offline mode, and app preferences.
- **Given** local DB and backup primitives exist in services
- **When** I open settings or offline controls
- **Then** I should be able to manage data and offline behavior from UI (currently no dedicated settings/profile/offline screens).

## Evidence Snapshot

- Entry and onboarding flow: `sakina-frontend/lib/main.dart`, `sakina-frontend/lib/screens/welcome_screen.dart`, `sakina-frontend/lib/screens/onboarding_screen.dart`.
- Account intro and waitlist: `sakina-frontend/lib/screens/account_intro_screen.dart`.
- Main shell and modules: `sakina-frontend/lib/screens/home_shell_screen.dart`, `sakina-frontend/lib/screens/module_read_only_state_screen.dart`.
- Chat and safety checks: `sakina-frontend/lib/screens/chat_screen.dart`.
- Iman journey/privacy/dua: `sakina-frontend/lib/screens/iman_journey_screen.dart`.
- API capability breadth (including Islamic library/search/ask and support/notifications/subscriptions): `sakina-frontend/lib/services/api_service.dart`.
- Feature flags default disabled for module shells: `sakina-frontend/lib/app/feature_flags.dart`.
