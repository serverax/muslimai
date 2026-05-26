# SakinaAI Mobile

Flutter mobile app for SakinaAI.

## Verify

```bash
flutter pub get
flutter analyze
flutter test
```

## API Target

Release builds default to `https://api.sakinaapp.com`.

Use `SAKINA_API_BASE_URL` for local or staging builds:

```bash
flutter run --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:8080
flutter build appbundle --release --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
```

## App Identity

- Android application ID: `com.sakinaai.app`
- iOS bundle ID: `com.sakinaai.app`
- Display name: `SakinaAI`

Release signing must be supplied by CI or the store release environment.
