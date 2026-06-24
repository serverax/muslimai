# Sakina App Store Release Checklist

## Required

- iOS target exists in `sakina-frontend/ios`
- Bundle identifier is set and stable
- Apple signing assets are configured via secrets
- Privacy policy is linked in-app
- Terms and conditions are linked in-app
- Account deletion flow exists
- AI/religious-content disclosure is shown clearly
- Crash reporting is configured
- App review notes explain the Islamic content and safety model

## Review risk areas

- Religious guidance must not claim unsupported fatwas.
- AI-generated text must be disclosed where relevant.
- User-facing moderation / reporting flow must be clear if user-generated content is present.
- Privacy labels must match actual data collection.

## Current state

- Android release artifacts build.
- iOS target still needs to be restored in this environment.
- Apple signing secrets are not committed.

