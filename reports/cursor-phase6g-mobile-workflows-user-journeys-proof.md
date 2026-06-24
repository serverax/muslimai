# Cursor Phase 6G — Mobile Workflows User Journeys Proof (updated)

Date: 2026-06-24  
Branch: `qa-security-hardening`  
Commit: `804397a` (+ continuation proof)

## Final verdict

**PARTIAL** — Mobile workflows implemented and documented. Backend Docker + API smoke **PASS** on continuation run. `flutter analyze` + `flutter test` **PASS**. APK build requires Android SDK on owner machine (cloud VM SDK download did not complete in time).

## PASS/FAIL table (updated)

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Docker backend build | PASS | `sudo docker compose -f docker-compose.qa.yml up -d --build` |
| 2 | Docker services | PASS | api, postgres, redis, qdrant, ollama, llm-gateway Up |
| 3 | API health | PASS | `curl http://localhost:28080/health` → 200 |
| 3b | Quran endpoint | PASS | `GET /v1/quran/surahs` → 200 |
| 3c | Prayer endpoint | PASS | `GET /v1/api/tools/prayer-times` → 200 |
| 3d | Subscription plans | PASS | `GET /v1/subscription/plans` → 200 |
| 4 | flutter analyze | PASS | No issues found |
| 5 | flutter test | PASS | 39 tests |
| 6 | APK build | BLOCKED (env) | Android SDK platforms not installed in cloud VM |
| 7–18 | Mobile journeys (code) | PASS/PARTIAL | See prior report |
| 19 | No feature-flag dead ends | PASS | SAKINA_LOCAL_TEST defaults |
| 20 | No secrets committed | PASS | |

## Docker services (continuation run)

```
sakina-infra-api-1           Up   0.0.0.0:28080->8080/tcp
sakina-infra-postgres-1      Up   0.0.0.0:5433->5432/tcp
sakina-infra-redis-1         Up   0.0.0.0:6380->6379/tcp
sakina-infra-qdrant-1        Up   6333/tcp
sakina-infra-ollama-1        Up
sakina-infra-llm-gateway-1   Up
```

## Owner commands

**Windows:**
```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

**Linux:**
```bash
BUILD_APK=1 ./scripts/sakina-owner-local-test.sh
```

**Backend only:**
```bash
cd sakina-infra && docker compose -f docker-compose.qa.yml up -d
```

## APK build (owner machine)

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

Output: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`

## Documentation

- `docs/sakina-mobile-workflows-and-button-map.md`
- `docs/sakina-mobile-testing-runbook.md`

## Owner next steps

1. `BUILD_APK=1 ./scripts/sakina-owner-local-test.sh` (Linux) or `pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk` (Windows)
2. `adb install -r sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`
3. Test journeys per runbook
