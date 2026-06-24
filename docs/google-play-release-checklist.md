# Sakina Google Play Release Checklist

## Required

- Android application ID is stable.
- Release signing keystore is provided through GitHub Secrets.
- `android/key.properties` is generated at build time, not committed.
- Data Safety form reflects actual collection and retention.
- Account deletion flow is present.
- Subscription / billing behavior is documented if used.
- AI content and religious safety disclosures are present.
- Notification / background service permissions are justified.

## Review risk areas

- Do not claim compliance for data that is not actually collected or stored.
- Do not ship a release build signed with debug keys.
- Do not hardcode API keys or credentials.

## Current state

- Release APK and AAB build locally.
- Release signing still requires keystore secrets.

