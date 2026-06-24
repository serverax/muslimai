# Cursor Phase 6G — Mobile Workflows User Journeys Proof

Date: 2026-06-24  
Branch: `qa-security-hardening`

## Final verdict

**PARTIAL** — Mobile workflow implementation and documentation complete; `flutter analyze` and `flutter test` PASS. Docker daemon and Android SDK were not available in the cloud proof VM (APK build and live API health blocked here). Owner machine with Docker + Android SDK can complete end-to-end APK testing using the runbook.

## PASS/FAIL table

| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | Docker backend build | SKIP | No docker.sock in proof VM |
| 2 | Docker services | SKIP | No docker.sock in proof VM |
| 3 | API health | SKIP | Backend not started in VM |
| 4 | flutter analyze | PASS | No issues |
| 5 | APK build | BLOCKED (env) | No Android SDK in proof VM |
| 6 | Login/register flow | PASS (code) | AccountIntroScreen + AuthService |
| 7 | Guest journey | PASS (code+test) | GuestHomeDashboardScreen |
| 8 | User dashboard journey | PASS (code) | MobileHomeDashboardScreen 12 cards |
| 9 | Ask AI safe flow | PASS (code) | ChatScreen wired to askSakina |
| 10 | High-risk escalation | PASS (code) | PendingReviewStore + scholar reviews |
| 11 | Quran/Tafsir/Hadith | PASS (code) | StudyHubScreen |
| 12 | Prayer/Qibla/calendar | PASS (code) | PrayerHubScreen |
| 13 | Dua/bookmark/reminder | PASS (code) | Daily essentials + LoginRequired |
| 14 | Zakat/Mirath | PASS (code) | CalculatorsScreen |
| 15 | Kids | PASS (code) | KidsLearningScreen |
| 16 | Subscription/entitlement | PASS (code) | SubscriptionScreen |
| 17 | Scholar review | PARTIAL | User status PASS; scholar resolve needs scholar account |
| 18 | Admin/owner tools | PARTIAL | Honest screen; admin APIs need admin JWT |
| 19 | No feature-flag dead ends | PASS (code) | SAKINA_LOCAL_TEST + founding tier defaults |
| 20 | No secrets committed | PASS | Only placeholder .env template in docs |

## What was broken

- 13-tab developer shell with ModuleReadOnlyStateScreen dead ends
- Feature flags default false → "disabled by feature flag"
- EntitlementGate default `free` blocked modules
- No guest home, no journey documentation, no login-required screens
- Web treated as primary product

## Root cause

Phase 6D optimized web diagnostic UI; mobile shell was never refactored for product journeys. Compile-time flags and entitlement defaults were production-safe but blocked local APK testing.

## Fix applied

- 5-tab mobile shell (Home / Ask / Study / Daily / More)
- GuestHomeDashboardScreen + MobileHomeDashboardScreen (12 cards)
- SplashEnvironmentScreen with health probe + session restore
- LoginRequiredScreen, PremiumLockedScreen, NotImplementedScreen
- StudyHubScreen, PrayerHubScreen, Settings, Admin, Scholar dashboards
- Feature flag local test defaults + APK dart-define bundle in owner script
- `docs/sakina-mobile-workflows-and-button-map.md`
- `docs/sakina-mobile-testing-runbook.md`

## User journeys completed

1. Guest / first-time  
2. Register / login  
3. Logged-in home (12 cards)  
4. Ask AI Shaikh  
5. Scholar review (user); scholar dashboard PARTIAL  
6. Quran / Tafsir / Hadith  
7. Prayer / Qibla / calendar  
8. Dua / bookmarks / reminders  
9. Zakat / Mirath  
10. Kids learning  
11. Subscription / entitlement  
12. Admin / owner tools (honest PARTIAL)

## Button map

Created: `docs/sakina-mobile-workflows-and-button-map.md` (40+ buttons documented)

## APK (owner machine)

```bash
cd sakina-frontend && flutter build apk --debug \
  --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1 \
  --dart-define=SAKINA_LOCAL_TEST=true \
  --dart-define=SAKINA_FEATURE_QURAN=true \
  --dart-define=SAKINA_FEATURE_PRAYER=true \
  --dart-define=SAKINA_FEATURE_KNOWLEDGE=true \
  --dart-define=SAKINA_FEATURE_COMMUNITY=true \
  --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

Path: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`

## Owner commands

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

## Known limitations

- Scholar resolve requires scholar-seeded account
- Admin grant/revoke requires admin JWT
- Payment provider not configured locally
- Masjid near me not implemented (honest screen)
- Docker/APK proof blocked in cloud VM without daemon/SDK

## Owner next steps

1. Run `pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk` on Windows with Docker Desktop
2. Install APK on emulator or phone
3. Walk through journey checklist in `docs/sakina-mobile-testing-runbook.md`
