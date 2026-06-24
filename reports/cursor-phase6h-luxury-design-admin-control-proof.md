# CURSOR Phase 6H — Luxury Design + Admin Feature Control Proof

**Date:** 2026-06-24  
**Branch:** `qa-security-hardening`  
**Baseline:** `27ce57f` (Phase 6G)  
**Target status:** `MOBILE_OWNER_TEST_READY`  
**Final verdict:** **PARTIAL**

## Summary

Phase 6H delivers luxury Islamic mobile design, server-driven feature gates for 25 features, admin tools upgrade, app-store readiness checklist foundation, disclaimer messaging, and fixed owner APK scripts (no empty LAN host).

Cloud VM: Flutter analyze/test PASS, Docker backend PASS, `/v1/features` PASS (25 features). APK build BLOCKED (no Android SDK). Admin feature update with admin JWT: PARTIAL (no admin seed in QA DB; 403 proof for normal user PASS).

## Design changes

- Luxury palette: deep navy, emerald, gold, cream (`lib/design/sakina_colors.dart`, `sakina_luxury_theme.dart`)
- Components: dashboard card, feature tile, section header, status/role badges, gate state screens, loading/error, disclaimer banner
- Applied: splash, guest home, logged-in dashboard, Ask AI disclaimer, admin tools, terms/privacy placeholder

## Backend

- Migration `037_app_feature_flags.sql` — 25 seeded features
- Endpoints: `GET /v1/features`, `GET /v1/admin/features`, `PUT /v1/admin/features/{key}`, `POST /v1/admin/features/reset-defaults`, `GET /v1/admin/app-status`
- Handler: `handlers/app_features.rs`

## Feature gate table (defaults)

| Feature | Enabled | Login | Premium | Coming soon |
|---------|---------|-------|---------|-------------|
| ask_ai_shaikh | ✓ | ✓ | | |
| quran_reader/search | ✓ | | | |
| tafsir | ✓ | | ✓ | |
| masjid_near_me | ✓ | | | ✓ |
| bookmarks/reminders/kids | ✓ | ✓ | | |
| (others) | ✓ | varies | | |

## PASS/FAIL matrix

| # | Check | Result |
|---|-------|--------|
| 1 | Docker backend build | PASS |
| 2 | Docker services | PASS |
| 3 | Migration 037 (manual apply on existing DB) | PASS |
| 4 | API health | PASS |
| 5 | GET /v1/features | PASS (25) |
| 6 | GET /v1/admin/features | PASS (401/403 without admin) |
| 7 | Admin update blocked normal user | PASS (403) |
| 8 | Admin update with admin JWT | PARTIAL (no admin seed) |
| 9 | Mobile reads feature gates | PASS (FeatureService) |
| 10–14 | Gate UI states | PASS (unit + luxury cards) |
| 15 | No red placeholder dead ends | PASS |
| 16 | flutter analyze | PASS |
| 17 | flutter test | PASS (42) |
| 18 | APK build | BLOCKED (no Android SDK in cloud VM) |
| 19 | No secrets committed | PASS |
| 20 | App-store checklist | PASS |

## Known limitations

- Admin JWT not seeded in local QA — owner must grant admin via DB or existing admin flow
- APK must be built on owner machine with Android SDK
- Migration 037 on existing volumes may need manual apply if full migrate hits duplicate policy errors
- Masjid near me remains coming-soon by default
- Not `APP_STORE_READY` — signing, screenshots, hosted privacy policy still needed

## Owner next steps

1. `docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .`
2. `./scripts/sakina-owner-local-test.sh` or `pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk`
3. Install APK on phone/emulator; test guest + login + admin (with admin account)
4. Review `docs/sakina-app-store-readiness-checklist.md`
