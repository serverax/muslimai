# Sakina Mobile Testing Runbook

Phase 6I — test the **Android APK** as the real product. Web is diagnostic only.

**Status target:** `MOBILE_OWNER_TEST_READY` (not `APP_STORE_READY`).

---

## 1. Pull and start (owner)

```bash
git checkout qa-security-hardening
git pull origin qa-security-hardening
```

### Windows (recommended)

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

### Linux/macOS

```bash
BUILD_APK=1 ./scripts/sakina-owner-local-test.sh
```

The script will:

1. Verify Docker is running
2. Build/start backend
3. Run migrations with local admin seed (`SAKINA_SEED_LOCAL_ADMIN=true`)
4. Check API health and `/v1/features` (25 gates)
5. Run `flutter analyze` and `flutter test` if Flutter is installed
6. Print **complete** emulator and phone APK build commands (no `...` placeholders)
7. Build APK when `-BuildApk` / `BUILD_APK=1` (emulator target by default)
8. Fail clearly if Android SDK is missing

Phone API URL uses detected LAN IP or `YOUR_LAN_IP` placeholder — **never** `http://:28080/v1`.

---

## 2. Local admin login (QA only)

| Field | Value |
|-------|-------|
| Email | `owner@sakina.local` |
| Password | `SakinaLocalOwner2026!` |

This account is seeded only when `SAKINA_SEED_LOCAL_ADMIN=true` (set in `docker-compose.qa.yml` and owner scripts). **Never enable in production.**

Use it to test **Admin Tools** → feature gate edit/save/reset.

---

## 3. Full emulator APK build command

```bash
cd sakina-frontend
flutter pub get
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1 --dart-define=SAKINA_LOCAL_TEST=true --dart-define=SAKINA_FEATURE_QURAN=true --dart-define=SAKINA_FEATURE_PRAYER=true --dart-define=SAKINA_FEATURE_KNOWLEDGE=true --dart-define=SAKINA_FEATURE_COMMUNITY=true --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

---

## 4. Full phone/LAN APK build command

Replace `YOUR_LAN_IP` with your machine IPv4 (Windows: `ipconfig`, Linux: `ip route get 1.1.1.1`):

```bash
cd sakina-frontend
flutter pub get
flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://YOUR_LAN_IP:28080/v1 --dart-define=SAKINA_LOCAL_TEST=true --dart-define=SAKINA_FEATURE_QURAN=true --dart-define=SAKINA_FEATURE_PRAYER=true --dart-define=SAKINA_FEATURE_KNOWLEDGE=true --dart-define=SAKINA_FEATURE_COMMUNITY=true --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

---

## 5. Install APK

```bash
adb install -r sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk
```

APK path: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`

---

## 6. Owner test journeys

| # | Journey | Steps | Expected |
|---|---------|-------|----------|
| 1 | Guest | Open APK → guest home → Quran Study | Surah list loads |
| 2 | Guest protected | Tap Bookmarks | Login-required luxury card |
| 3 | Register | Register normal user → dashboard | Journey cards, email shown |
| 4 | Admin login | Login `owner@sakina.local` → Admin Tools | Feature list, edit toggles |
| 5 | Admin control | Disable a feature → guest sees disabled card | No red error screen |
| 6 | Reset defaults | Admin Tools → Reset | 25 features restored |
| 7 | Ask AI | Ask tab → safe question | Answer + disclaimer |
| 8 | Premium gate | Tafsir without premium | Premium locked card |
| 9 | Prayer | Prayer hub → times | Fajr–Isha shown |
| 10 | Scholar | Scholar review (if account exists) | Queue or permission state |

---

## 7. Admin feature control

| Action | Who | API |
|--------|-----|-----|
| Public gates | Anyone | `GET /v1/features` |
| List/edit features | Admin JWT | `GET/PUT /v1/admin/features/{key}` |
| Reset defaults | Admin JWT | `POST /v1/admin/features/reset-defaults` |
| App status | Admin JWT | `GET /v1/admin/app-status` |

Normal users receive **403** on admin endpoints.

---

## 8. Android SDK setup (if build fails)

1. Install [Android Studio](https://developer.android.com/studio)
2. SDK Manager → install Android SDK Platform + build-tools
3. Accept licenses: `flutter doctor --android-licenses`
4. Verify: `flutter doctor` shows Android toolchain OK
5. Re-run: `pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk`

---

## 9. What is NOT production/live

- Live payment checkout (Stripe not configured locally)
- Masjid map (coming-soon by default)
- App Store signing / release keystore
- Hosted privacy policy URL
- HTTPS production API

See [sakina-app-store-readiness-checklist.md](./sakina-app-store-readiness-checklist.md).

---

## 10. Manual backend (optional)

```bash
cd sakina-infra
docker compose -f docker-compose.qa.yml up -d --build
docker compose -f docker-compose.qa.yml run --rm -e SAKINA_SEED_LOCAL_ADMIN=true api sakina-migrate
curl http://localhost:28080/health
curl http://localhost:28080/v1/features
```
