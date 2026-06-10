# AGENT — Mobile Release Readiness (Hostile QA Audit)

App: SakinaAL (`sakina-frontend`, Flutter) — Android + iOS release configuration
Auditor mode: hostile, file:line evidence, no fake PASS.
Tooling constraint: **`flutter` CLI is NOT installed** (`command -v flutter` → not in PATH). All build/AAB/APK *production* steps are therefore **UNPROVEN**; everything below is a **static** audit of committed config. `cargo` was not run.

Config-file inventory saved to: `reports/ultimate-hostile-audit/200-mobile-config-files.txt`

---

## 1. Android build & signing config

File: `sakina-frontend/android/app/build.gradle.kts`

| Property | Value | Evidence |
|---|---|---|
| applicationId | `com.sakina.app` | build.gradle.kts:32 (namespace also :18) |
| versionCode | `flutter.versionCode` (from pubspec `+1`) | build.gradle.kts:35 |
| versionName | `flutter.versionName` (`1.0.0`) | build.gradle.kts:36; pubspec.yaml:5 |
| minSdk | `flutter.minSdkVersion` (Flutter default, not pinned) | build.gradle.kts:33 |
| targetSdk | `flutter.targetSdkVersion` (Flutter default, not pinned) | build.gradle.kts:34 |
| compileSdk | `flutter.compileSdkVersion` | build.gradle.kts:19 |
| Java/Kotlin target | 17 | build.gradle.kts:23-28 |

**Signing config (the key store-blocker check):**

- Release signing is **conditional on `key.properties` existing** (build.gradle.kts:13-15, 40-48, 52-57).
- `signingConfigs.release` is only created *if* `rootProject.file("key.properties")` exists; it loads `keyAlias/keyPassword/storeFile/storePassword` (lines 42-45).
- The `release` build type sets `signingConfig = signingConfigs.getByName("release")` **only if** key.properties exists, **otherwise `signingConfig = null`** (build.gradle.kts:52-57).

What this means:
- **GOOD:** This is NOT the Flutter scaffold default (which falls back to `signingConfigs.getByName("debug")`). This project explicitly sets `null` when no keystore — so a release build without the keystore is **unsigned and will fail upload**, rather than silently shipping a *debug-signed* release. That is the correct hardening posture.
- `key.properties` is present locally: `sakina-frontend/android/key.properties` — alias `upload`, `storeFile=../keystore/upload-keystore.jks` (key.properties:1-4).
- The keystore is **real**: `sakina-frontend/android/keystore/upload-keystore.jks` is a valid `Java KeyStore` (file type confirmed), 1 `PrivateKeyEntry`, alias `upload`, cert SHA-256 `41:99:D0:3E:53:26:FE:C3:0A:36:47:86:98:76:F9:83:CA:DC:B3:3C:3D:28:BA:91:62:4E:C3:48:C2:A2:D3:95` (verified via `keytool -list`, storepass from key.properties succeeded).

**Signing-config finding:** No debug-signed-release blocker in the *config*. Release path is keystore-or-unsigned, which is safe. **However:**
- `key.properties` and `keystore/` are git-ignored (`sakina-frontend/android/.gitignore:12-14`, root `.gitignore:49`) and **NOT tracked by git** (`git ls-files` returns nothing for both). Correct for secret hygiene, but it means **any clean/CI checkout has no keystore → release build produces an UNSIGNED bundle** unless the secret is injected out-of-band. CI reproducibility = unproven.
- **Secret exposure:** real-looking `storePassword`/`keyPassword` are stored in **plaintext** in `key.properties` on the working tree. Not committed, but anyone with repo-machine access has the upload-key passwords. Treat as a credential-handling concern.

## 2. Android permissions (AndroidManifest)

Main manifest: `sakina-frontend/android/app/src/main/AndroidManifest.xml`

| Permission | Where | Verdict |
|---|---|---|
| `android.permission.CAMERA` | main:2 | Justified — camera image upload feature (matches `image_picker` and iOS NSCamera string). Dangerous perm but used. |
| `android.permission.INTERNET` | **debug:6, profile:6 only** | **Concern — see below** |

- **INTERNET is NOT in the main/release manifest.** It appears only in `src/debug/AndroidManifest.xml:6` and `src/profile/AndroidManifest.xml:6`. The app is a networked client (calls `https://api.7jzi.com/v1`). At runtime Flutter/plugins normally inject `INTERNET` into the merged release manifest, but it is **not explicitly declared for release** in this repo. This is a latent risk: if a future change removes the implicit injection, release networking breaks. Flag = verify the merged `AndroidManifest.xml` in the built AAB actually contains INTERNET (UNPROVEN — flutter not installed, cannot run manifest merger).
- No dangerous/unnecessary perms found (no `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, `READ_CONTACTS`, `WRITE_EXTERNAL_STORAGE`, `QUERY_ALL_PACKAGES`, etc.). Only a scoped `PROCESS_TEXT` `<queries>` block (main:40-45), which is the Flutter default and benign.
- **cleartextTraffic:** No `android:usesCleartextTraffic` attribute anywhere (grep across `sakina-frontend` = no matches), and no `<application>`-level override. On targetSdk ≥ 28 the platform default is **cleartext disabled** — acceptable for prod. No network-security-config file is present (none needed since default is secure).

## 3. iOS config (Info.plist)

File: `sakina-frontend/ios/Runner/Info.plist`

- Bundle id: `$(PRODUCT_BUNDLE_IDENTIFIER)` (Info.plist:13-14) — resolved from the Xcode project, not hardcoded here. Display name `Sakina AI` (Info.plist:10,18).
- Permission usage strings:
  - `NSCameraUsageDescription` — present, meaningful (Info.plist:29-30).
  - `NSPhotoLibraryUsageDescription` — present, meaningful (Info.plist:31-32).
  - `NSMicrophoneUsageDescription` — **absent.** Acceptable: no microphone/audio/speech feature exists in the app (grep for microphone/record/audio/speech in `lib` = no matches; pubspec has no audio plugin). The multimodal feature is image-only (`image_picker`, `file_picker`), so camera+photo strings are sufficient.
- **App Transport Security:** No `NSAppTransportSecurity` key at all (grep = no matches). Therefore ATS is at **secure defaults — arbitrary loads are NOT allowed.** This is the correct prod posture (HTTPS-only). PASS.
- Orientations, scene manifest, launch storyboard are standard Flutter scaffold — no issues.

## 4. App-store compliance scripts

Scripts read: `scripts/sakina/store-readiness-proof.sh`, `scripts/sakina/tech-store-compliance-proof.sh`, `scripts/sakina/tech-crash-reporting-proof.sh`.

These check **real things** (not vacuous):
- `tech-store-compliance-proof.sh` actually runs `flutter build apk --release` + `flutter build appbundle --release` (lines 54-69), asserts non-empty APK & AAB (73-75), greps release source for `localhost/127.0.0.1/10.0.2.2/demo-token/test-token/fake` blockers (77-80), asserts privacy/terms/disclaimer/deletion UI strings + camera/photo permissions exist (82-92), spins up the Rust backend, registers a user, and asserts `POST /v1/account/delete-request` **requires JWT (401 without)** and persists audit + outbox rows (133-156). This is a substantive runtime gate.
- `store-readiness-proof.sh` wraps the above and re-asserts compliance UI + the deletion path across frontend/backend (lines 21-45).
- **Caveat (hostile):** every one of these scripts hard-requires `flutter`/`cargo`/`psql`. In THIS environment flutter and (per instructions) cargo are not run, so **none of these proofs can be executed here → the STORE_COMPLIANCE_OK / STORE_READINESS_OK results are UNPROVEN in this audit.** They are well-designed but unverified now.

**Account deletion (Apple 5.1.1(v) in-app deletion requirement):** Satisfied in code.
- UI: `sakina-frontend/lib/screens/compliance_screen.dart` — "Request account deletion" `FilledButton` (lines 127-133) calling `_requestDeletion()` (55-86) → `api.requestAccountDeletion()` (72).
- API: `sakina-frontend/lib/services/api_service.dart:327-328` → `POST /account/delete-request`. Cross-ref to required `/v1/account/delete-request` confirmed (api_service builds `/v1` prefix at :867-870). Matches the backend endpoint the compliance script exercises.
- Data export also present (compliance_screen.dart:22-53, 119-125). Privacy Policy / Terms / Islamic Advisory Disclaimer text is rendered in-app (compliance_screen.dart:93-117).

**Privacy policy:** Present as **in-app text only** (compliance_screen.dart:93-97). **No hosted Privacy Policy URL** is present in the app or config (grep found no `7jzi`/policy URL). App Store Connect & Google Play Data Safety both require a **publicly hosted privacy-policy URL** — that is a store-submission gap not satisfiable by in-app text alone. **Flag.**

## 5. pubspec.yaml / dependencies

File: `sakina-frontend/pubspec.yaml`

- version `1.0.0+1` (pubspec:5); SDK `>=3.0.0 <4.0.0`, flutter `>=3.16.0` (pubspec:7-9).
- Security-relevant deps look reasonable: `flutter_secure_storage ^9.2.4`, `sqflite_sqlcipher`, `encrypt ^5.0.0`, `cryptography`.
- **Unpinned `any` constraints (concern):** `sqflite_sqlcipher: any` (pubspec:21), `cryptography: any` (pubspec:27). `any` on encryption/crypto packages is a supply-chain / reproducibility risk — a future resolve could pull a breaking or vulnerable version. Should be pinned before store release. (Actual locked versions live in `pubspec.lock`, present, but the manifest intent is unpinned.)
- No obviously dev-only/insecure runtime deps (`build_runner`, `flutter_lints`, `flutter_test` are correctly under `dev_dependencies`).
- Note: custom fonts removed pending real `.ttf` files (pubspec:59-61) — cosmetic, not a blocker.

## 6. Release API endpoint

- File: `sakina-frontend/lib/config/api_config.dart:2-5` — `baseUrl` defaults to **`https://api.7jzi.com/v1`** (overridable via `--dart-define=SAKINA_API_BASE_URL`). HTTPS — good. Reachability **not tested** (no curl per instructions); note only — `api.7jzi.com` should be confirmed as the real prod host (domain does not obviously match the `com.sakina.app` brand).
- A separate staging config exists: `sakina-frontend/lib/config/staging_client_config.dart` defaults to `https://api.sakina-mobile-staging.example` (a placeholder `.example` TLD — fine for staging, must never be the release default; it is not).

## 7. Crash reporting / analytics

- **No crash reporting in the Flutter app.** `main.dart:9-11` is a bare `runApp(...)` with **no `runZonedGuarded`, no `FlutterError.onError`, no `PlatformDispatcher.onError`** (grep for runZonedGuarded/FlutterError.onError/Crashlytics/Sentry across `lib` = **no matches**). No `firebase_crashlytics`/`sentry` in pubspec.
- `tech-crash-reporting-proof.sh` only proves a **backend** error contract + a Postgres `app_events` insert + greps source for crash keywords (lines 66-91). It does **not** prove any on-device crash capture. So mobile crash/analytics telemetry is **effectively absent** — uncaught Flutter/Dart errors on user devices are not reported anywhere. **Flag** (not a hard store blocker, but a release-quality gap).

## 8. Build / AAB / APK status

- `flutter` CLI not installed → **build reproduction UNPROVEN.**
- Artifacts DO exist on disk from a prior local build: `app-release.aab` (~49 MB, Jun 6) and `app-release.apk` (~66 MB, Jun 6) under `sakina-frontend/build/app/outputs/...`. These are **not reproducible here** and **not committed**.
- I attempted to verify the APK's signing certificate: it has **no v1 (`META-INF/*.RSA`) signature block**, i.e. it was signed with APK Signature Scheme v2/v3 only. Without `apksigner`/flutter I **cannot confirm** the artifact was signed by the release keystore (fingerprint `41:99:D0:3E…`) vs a debug key. **Signature of the existing artifact = UNPROVEN.**

## 9. Permissions table (summary)

| Platform | Permission / Key | Declared | Justified by feature | Verdict |
|---|---|---|---|---|
| Android | CAMERA | main manifest:2 | image upload (`image_picker`) | OK |
| Android | INTERNET | debug:6 / profile:6 only — NOT in release manifest | networked client | **Verify merged release manifest (UNPROVEN)** |
| Android | usesCleartextTraffic | not set (secure default) | — | OK (HTTPS-only) |
| iOS | NSCameraUsageDescription | Info.plist:29-30 | camera upload | OK |
| iOS | NSPhotoLibraryUsageDescription | Info.plist:31-32 | photo/document upload | OK |
| iOS | NSMicrophoneUsageDescription | absent | no audio feature exists | OK (not needed) |
| iOS | NSAppTransportSecurity / ArbitraryLoads | absent (secure default) | — | OK (no arbitrary loads) |

---

## VERDICT: **PARTIAL** (not store-ready as committed; no hard signing blocker)

No debug-signed-release blocker: the Gradle config is hardened (keystore-or-unsigned, never debug-signed). The real upload keystore exists and is valid. iOS ATS and permission strings are correct; Android permission surface is minimal and justified.

**Blocking/should-fix before store submission:**
1. **Hosted Privacy Policy URL missing** — only in-app text exists (compliance_screen.dart:93-97). Apple App Store Connect and Google Play Data Safety both require a public privacy-policy URL. **Store-submission blocker.**
2. **Keystore not in any committed/CI-injectable form** (`key.properties` + `keystore/` git-ignored, untracked) → a clean/CI release build is **unsigned**. Signing only works on the one machine that holds the secrets. Define a secret-injection path for CI. Also: upload-key passwords sit in plaintext on disk.
3. **INTERNET permission absent from release manifest** (only debug/profile). Relies on implicit Flutter injection — verify the merged release `AndroidManifest.xml` actually contains it. (UNPROVEN — needs flutter manifest merger.)

**Should-fix (quality, non-blocking):**
4. **No on-device crash reporting** — bare `runApp` in main.dart:10, no error handlers, no Crashlytics/Sentry. Uncaught device errors are invisible.
5. **Unpinned `any` constraints on crypto deps** (`sqflite_sqlcipher`, `cryptography`, pubspec:21,27) — pin before release.
6. **minSdk/targetSdk not pinned** in build.gradle.kts (inherits Flutter defaults) — pin explicitly so Play's targetSdk policy is auditable.

**UNPROVEN (flutter CLI not installed; cargo not run):** release APK/AAB reproducibility; signing of the existing on-disk artifacts; merged-manifest INTERNET; and all of the `store-readiness`/`store-compliance`/`crash-reporting` runtime proof scripts.
