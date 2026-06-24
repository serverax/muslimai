# Sakina AI App Store / Play Store Compliance Checklist

This document records the current publication readiness of Sakina AI for Apple App Store and Google Play.

## Scope

- App: Sakina AI mobile app
- Repo root: `/mnt/f/SakinaAl`
- Backend: `sakina-backend`
- Frontend: `sakina-frontend`

## Current status summary

- Apple App Store readiness: PARTIAL
- Google Play readiness: PARTIAL
- Security readiness: PARTIAL
- Workspace isolation readiness: PARTIAL

## Notes

- Android release builds succeed with the current workspace, but `android/key.properties` is missing so release signing falls back to debug signing.
- `flutter doctor -v` shows only Windows/Android/web/desktop tooling in this environment; iOS build/signing cannot be proven here because macOS/Xcode is not available.
- Backend tests prove the presence of auth, profile, subscription, RAG, and moderation-style enforcement paths, but live production signing, account deletion, App Store privacy labels, and Play Data Safety form completion still need product/legal review.
- No obvious hardcoded mobile secrets were found in `sakina-frontend/lib/config/api_config.dart` or `sakina-frontend/lib/services/api_service.dart`.

