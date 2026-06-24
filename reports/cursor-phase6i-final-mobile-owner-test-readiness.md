# CURSOR Phase 6I — Final Mobile Owner Test Readiness

**Date:** 2026-06-24  
**Branch:** `qa-security-hardening`  
**Verdict:** **PARTIAL** (APK build blocked in cloud VM — owner machine ready)

## Summary

Phase 6I closes Phase 6H gaps: owner PowerShell script with complete APK commands, local admin seed, idempotent migrations, and admin feature control proof.

## Fixes delivered

| Fix | Status |
|-----|--------|
| Owner script `-BuildApk` with full dart-defines | PASS |
| No `http://:28080/v1` or `...` in commands | PASS |
| Local admin seed `owner@sakina.local` | PASS |
| Migration 037 idempotent policies | PASS |
| Migration repeat on existing DB | PASS (40 migrations) |
| Admin feature update + reset | PASS |
| Normal user 403 on admin API | PASS |
| Flutter analyze/test | PASS (42) |
| APK build in cloud VM | BLOCKED (no Android SDK) |

## Local admin (QA only)

- **Email:** owner@sakina.local
- **Password:** SakinaLocalOwner2026!
- Seeded when `SAKINA_SEED_LOCAL_ADMIN=true` (docker-compose.qa.yml + owner scripts)
- **Not for production**

## Owner command

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

## Full emulator APK command

```
cd sakina-frontend && flutter pub get && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1 --dart-define=SAKINA_LOCAL_TEST=true --dart-define=SAKINA_FEATURE_QURAN=true --dart-define=SAKINA_FEATURE_PRAYER=true --dart-define=SAKINA_FEATURE_KNOWLEDGE=true --dart-define=SAKINA_FEATURE_COMMUNITY=true --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

## Full phone APK command

Replace `YOUR_LAN_IP` with machine IPv4 from `ipconfig` (Windows) or `ip route get 1.1.1.1` (Linux):

```
cd sakina-frontend && flutter pub get && flutter build apk --debug --dart-define=SAKINA_API_BASE_URL=http://YOUR_LAN_IP:28080/v1 --dart-define=SAKINA_LOCAL_TEST=true --dart-define=SAKINA_FEATURE_QURAN=true --dart-define=SAKINA_FEATURE_PRAYER=true --dart-define=SAKINA_FEATURE_KNOWLEDGE=true --dart-define=SAKINA_FEATURE_COMMUNITY=true --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

## Install

```
adb install -r sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk
```

## PASS/FAIL matrix

| # | Check | Result |
|---|-------|--------|
| 1 | Docker backend build | PASS |
| 2 | Docker services | PASS |
| 3 | Migrations (existing DB) | PASS (40) |
| 4 | API health | PASS |
| 5 | GET /v1/features (25) | PASS |
| 6 | Admin login | PASS |
| 7 | Admin feature update | PASS |
| 8 | Normal user admin blocked | PASS (403) |
| 9 | Reset defaults | PASS (25) |
| 10 | Flutter analyze | PASS |
| 11 | Flutter test | PASS |
| 12 | APK build (cloud VM) | BLOCKED |
| 13 | Owner script commands complete | PASS |
| 14 | No secrets committed | PASS |

## Known limitations

- APK must be built on owner Windows/Mac/Linux machine with Android SDK
- Clean DB (`docker compose down -v`) takes longer; idempotent migrate verified on existing DB
- Not APP_STORE_READY

## Owner next steps

1. Run owner script with `-BuildApk`
2. Install APK on phone/emulator
3. Login as owner@sakina.local and test Admin Tools feature gates
4. Test guest and normal user journeys per runbook
