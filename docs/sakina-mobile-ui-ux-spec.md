# Sakina Mobile UI/UX Specification (Phase 24D)

## 1) Purpose and Scope

This UX spec defines the target mobile experience for Sakina while reflecting current repository evidence. It covers onboarding, language, account setup, home shell, chat, Islamic Q&A, Quran/Prayer/Knowledge/Community modules, iman journey, reminders, privacy, subscription gating, family context, and offline/data controls.

## 2) Product Principles

- Trust first: no fabricated confidence; authoritative fallback required when evidence is missing.
- Privacy by default: user control over personalization, reminders, and stored journey data.
- Progressive delivery: modules can be visible in controlled read-only or coming-soon states.
- Accessibility and localization as baseline: English/Arabic, clear hierarchy, legible controls.

## 3) Information Architecture

- Entry: `WelcomeScreen` -> `OnboardingScreen` -> `AccountIntroScreen` -> `HomeShellScreen`.
- Primary shell destinations: Chat, Quran, Prayer, Community, Knowledge, Iman Journey.
- Current routing pattern is imperative (`Navigator.push`/`pushReplacement`), no centralized named-route registry.

## 4) Current UX Baseline (Evidence-Based)

- Implemented screens: welcome, onboarding, account intro, home shell, chat, module read-only state, iman journey.
- Modules (Quran/Prayer/Knowledge/Community) are contract shells with feature and entitlement gating.
- Library/Hadith/Dua dedicated browsing screens are not implemented despite API client support.
- Dedicated settings/profile/subscription/privacy/family/offline screens are not implemented.

## 5) Required Screen Groups (Target)

1. Onboarding + language + guest continuation.
2. Account/auth bootstrap and profile setup.
3. Home dashboard and module status hub.
4. Chat with evidence, feedback, report.
5. Islamic Q&A and source exploration (Hadith/Quran/Dua/library views).
6. Prayer times, qibla, and calendar experiences.
7. Reminders/notifications center.
8. Family profiles and consent controls.
9. Subscription/paywall and entitlement transparency.
10. Settings/privacy/offline/data export-delete controls.

## 6) Interaction and Navigation Rules

- Preserve one clear primary action per screen.
- Use explicit loading/error/empty states for every API-backed panel.
- Avoid dead ends: every placeholder must include explain-why and next-step CTA.
- For dangerous or irreversible actions (data delete/subscription change), require confirmation.

## 7) Safety and Religious Guidance Constraints

- Never present a religious answer as definitive without verified evidence fields.
- If evidence is malformed or missing, present a safe fallback and advisory language.
- Display provenance metadata (source type, reference, review status) where guidance is shown.
- Keep "under review/coming soon" states explicit for incomplete modules.

## 8) Localization and Accessibility Constraints

- Full RTL support for Arabic including alignment and typography behavior.
- Persist language preference locally and apply across app restarts.
- Provide semantic labels for interactive controls in critical flows.
- Ensure contrast and touch targets conform to mobile accessibility best practices.

## 9) Data, Privacy, and Consent UX

- User-visible controls required for:
  - personalization consent
  - reminders consent
  - journey data storage consent
  - notification channel preferences
  - data export and deletion requests
- Family reminder UX must require explicit consent artifacts.

## 10) Offline and Sync UX Direction

- Chat history and key user context should degrade gracefully offline.
- When offline, show read-only cached content and explicit sync status.
- Backup/restore flows must communicate encryption and key handling at UX level.

## 11) Performance and Reliability Requirements

- Initial app entry should provide immediate loading feedback.
- Each API call path should expose recoverable retry actions.
- Navigation between shell tabs should remain responsive and stateful.

## 12) Design Direction Constraints (Mandatory)

- No claim of completed Islamic feature without UI + API + data evidence.
- Use status labels consistently: `BUILT` / `PARTIAL` / `PLACEHOLDER` / `NOT STARTED`.
- Keep module shells honest: do not disguise gated/disabled states as active features.
- Preserve a calm, trustworthy visual tone (clean hierarchy, low-noise surfaces, clear warnings).
- Avoid introducing new route systems until a migration plan is approved.

## 13) Out of Scope for Phase 24

- Deployment changes.
- Kubernetes or namespace updates.
- Production release claims.

## 14) Implementation Evidence References

- App entry and routing: `sakina-frontend/lib/main.dart`, `sakina-frontend/lib/screens/welcome_screen.dart`, `sakina-frontend/lib/screens/onboarding_screen.dart`.
- Home shell/modules: `sakina-frontend/lib/screens/home_shell_screen.dart`, `sakina-frontend/lib/screens/module_read_only_state_screen.dart`.
- Chat and safety behavior: `sakina-frontend/lib/screens/chat_screen.dart`.
- Iman/privacy/dua: `sakina-frontend/lib/screens/iman_journey_screen.dart`.
- API surface: `sakina-frontend/lib/services/api_service.dart`.
- Feature gating: `sakina-frontend/lib/app/feature_flags.dart`, `sakina-frontend/lib/services/module_service.dart`.
