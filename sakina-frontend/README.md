# Sakina Frontend (Mobile App)

Flutter mobile client for Sakina AI. The website is landing/waitlist only; this app is the primary product surface.

## Local Run

```bash
flutter pub get
flutter run --dart-define=SAKINA_API_BASE_URL=https://api.7jzi.com/v1
```

## Release Build

```bash
flutter build apk --release --dart-define=SAKINA_API_BASE_URL=https://api.7jzi.com/v1
```

## Android Signing Preparation

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Fill real keystore values (do not commit `android/key.properties`).
3. Place your keystore file at the path specified by `storeFile`.
4. Build release APK/AAB.

If `android/key.properties` is missing, release builds fall back to debug signing for local verification only.

## Phase-2 Module Shells

Quran, Prayer, Knowledge, and Community are currently read-only contract shells.

- They are disabled by default behind feature flags.
- They must not be presented as complete Islamic product services.
- When enabled for testing, they should only show gated/review states until verified ingestion and review pipelines are implemented.
