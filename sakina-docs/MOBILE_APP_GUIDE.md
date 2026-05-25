# Mobile App Guide — Project Sakina (Flutter)

> **Status (honest):** the Flutter app compiles (`flutter analyze` clean) and its
> unit/widget tests pass (10 tests) on Flutter 3.44 / Dart 3.12. It has **not**
> been built into an APK/IPA or run on a device/simulator in this environment
> (no Android SDK, no device, and iOS builds require macOS). The steps below are
> the build/publish *procedure*.

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
flutter build apk --release         # -> build/app/outputs/flutter-apk/app-release.apk
# Install on a connected device:
adb install build/app/outputs/flutter-apk/app-release.apk
```
> The `android/` folder here is **not** a full `flutter create` scaffold (it was
> only partially generated). Run `flutter create .` in `sakina-frontend/` to
> regenerate the platform scaffolding before the first APK build.

## Build iOS (IPA) — **requires macOS + Xcode**
```bash
# On a Mac:
flutter build ios --release
# or run on a simulator:
flutter run -d "iPhone 15 Pro"
```
iOS cannot be built on Windows/Linux. Likewise, run `flutter create .` first to
generate the `ios/` scaffold.

## Pointing the app at the backend
`lib/config/api_config.dart` sets `baseUrl` (default `http://localhost:8080/v1`).
`ApiService` is constructed with a `baseUrl`; for a device hitting a local
backend, use your machine's LAN IP (not `localhost`) and ensure the API is
reachable.

## What the app does (implemented)
- `LocalDBService` — SQLCipher-encrypted local message store.
- `SyncService` — X25519 ECDH + ChaCha20-Poly1305 (verified by round-trip tests).
- `ApiService` — typed client for `/rag/query`, `/classify`, sync endpoints.
- `CitationBadge` — tappable source citations.
- Chat screen (basic). **Note:** the chat screen is not yet wired to `ApiService`/
  `LocalDBService` end-to-end — that integration + a real device run is the next step.

## Publishing (procedure, not yet done)
- **Google Play:** create a signed release (`key.properties` + keystore), `flutter build appbundle --release`, upload the `.aab` to the Play Console internal track.
- **App Store:** archive in Xcode (or `flutter build ipa`), upload via Transporter/`xcrun altool`, submit through App Store Connect.
- A privacy policy is required by both stores. Project Sakina's design is
  privacy-first (local encryption, no telemetry) — document data handling
  accordingly before submission.
