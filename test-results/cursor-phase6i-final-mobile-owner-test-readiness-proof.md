# Phase 6I Test Results

**Verdict:** PARTIAL (owner APK path ready; cloud VM has no Android SDK)  
**Status:** MOBILE_OWNER_TEST_READY  
**Branch:** qa-security-hardening  
**API:** http://localhost:28080/v1  

## Proof commands run

```bash
docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .
docker compose run --rm -e SAKINA_SEED_LOCAL_ADMIN=true api sakina-migrate  # 40 migrations
curl http://localhost:28080/v1/features  # count=25
curl -X POST /v1/auth/login owner@sakina.local  # PASS
curl -X PUT /v1/admin/features/masjid_near_me  # PASS (admin JWT)
curl -X POST /v1/admin/features/reset-defaults  # count=25
curl /v1/admin/features with normal user JWT  # 403
flutter analyze  # PASS
flutter test     # PASS 42
flutter build apk  # BLOCKED: No Android SDK
```

## APK

- Path: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`
- Not built in cloud VM (no Android SDK)
- Owner builds via `pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk`

## Local admin

- Email: owner@sakina.local
- Password: SakinaLocalOwner2026!
