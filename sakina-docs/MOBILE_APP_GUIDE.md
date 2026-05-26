# Mobile App Guide — Project Sakina (Flutter)

> **Status (honest):** the Flutter app compiles (`flutter analyze` clean) and its
> unit/widget tests pass on Flutter 3.44 / Dart 3.12. Android debug APK and
> release app bundle builds complete successfully in this environment. It has
> **not** been run on a device/simulator, signed with store credentials, or
> built for iOS (iOS builds require macOS). The steps below are the
> build/publish procedure.

## Verify (works anywhere with the Flutter SDK)
```bash
cd sakina-frontend
flutter pub get
flutter analyze        # expect: No issues found!
flutter test           # expect: all tests pass (LocalDB, Sync crypto, ApiService, Citation UI, widgets)
```

## Build Android (APK) — needs the Android SDK
```bash
flutter doctor                      # resolve any Android toolchain issues
flutter doctor --android-licenses   # accept licenses (interactive)
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
flutter build apk --release --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
flutter build appbundle --release --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
# Install on a connected device:
adb install build/app/outputs/flutter-apk/app-release.apk
```
Android application ID: `com.sakinaai.app`. Store/CI release builds still need
real signing credentials; the checked-in scaffold does not contain private keys.
Use `sakina-frontend/android/key.properties.example` as the template for a
local or CI-provided `android/key.properties` file.

## Build iOS (IPA) — **requires macOS + Xcode**
```bash
# On a Mac:
flutter build ios --release --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
# or run on a simulator:
flutter run -d "iPhone 15 Pro"
```
iOS bundle ID: `com.sakinaai.app`. iOS cannot be built on Windows/Linux, and
App Store builds require a valid Apple team, signing certificate, and
provisioning profile.

## Pointing the app at the backend
`lib/config/api_config.dart` sets `baseUrl` from the `SAKINA_API_BASE_URL`
compile-time value. Release builds default to `https://api.sakinaapp.com`.
For a device hitting a local backend, use a build override and a reachable host
(Android emulator example below uses `10.0.2.2`, not `localhost`):

```bash
flutter run --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:8080
flutter build apk --release --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
flutter build appbundle --release --dart-define=SAKINA_API_BASE_URL=https://api.sakinaapp.com
```

## What the app does (implemented)
- `LocalDBService` — SQLCipher-encrypted local message store.
- `SyncService` — X25519 ECDH + ChaCha20-Poly1305 (verified by round-trip tests).
- `ApiService` — typed client for `/rag/query`, `/classify`, sync endpoints.
- `CitationBadge` — tappable source citations.
- Chat screen wired to `ApiService` for `/v1/rag/query`, with local message
  persistence through `LocalDBService` and citation display for assistant
  answers.
- Five-tab app shell (Home, Tutoring, Quran, Prayer, Parent).
- Five-language localization foundation (`en`, `ar`, `ur`, `tr`, `id`) with RTL
  support for Arabic and Urdu.
- Typed asset-slot registry for brand, tab hero, onboarding, and store-listing
  assets.
- Android and iOS platform scaffolds with app ID/bundle ID `com.sakinaai.app`,
  display name `SakinaAI`, branded launcher icons, and branded launch screens.

## CI
- `.github/workflows/frontend-ci.yml` runs `flutter pub get`,
  `flutter analyze`, `flutter test`, Android debug APK build, and Android
  release app bundle build.
- CI uploads `sakinaai-debug-apk` and `sakinaai-release-aab` artifacts.
- Store release signing still requires a CI-provided `android/key.properties`
  file and keystore secret; do not commit signing keys.

## Publishing (procedure, not yet done)
- **Google Play:** create a signed release (`key.properties` + keystore), `flutter build appbundle --release`, upload the `.aab` to the Play Console internal track.
- **App Store:** archive in Xcode (or `flutter build ipa`), upload via Transporter/`xcrun altool`, submit through App Store Connect.
- A privacy policy is required by both stores. Project Sakina's design is
  privacy-first (local encryption, no telemetry) — document data handling
  accordingly before submission.
