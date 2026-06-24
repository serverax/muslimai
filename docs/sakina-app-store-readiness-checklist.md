# Sakina AI — App Store / Google Play Readiness Checklist

**Target status for this phase:** `MOBILE_OWNER_TEST_READY`  
**Not claimed:** `APP_STORE_READY`

Use this checklist before any real store submission.

## Identity & branding

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | App name consistency: **Sakina AI** | PARTIAL | Mobile title uses Sakina AI; verify store listing matches |
| 2 | App icon | NEEDED | Production icon asset not finalized |
| 3 | Splash screen | PARTIAL | Luxury splash/environment screen in APK; store assets needed |

## Technical identifiers

| # | Item | Status | Notes |
|---|------|--------|-------|
| 4 | Android `applicationId` | VERIFY | Check `android/app/build.gradle` before release |
| 5 | iOS bundle ID | PLACEHOLDER | iOS build path not owner-tested in cloud VM |

## Legal & support

| # | Item | Status | Notes |
|---|------|--------|-------|
| 6 | Privacy policy | PLACEHOLDER | In-app placeholder screen; hosted URL needed for stores |
| 7 | Terms of use | PLACEHOLDER | In-app placeholder screen; hosted URL needed |
| 8 | Support / contact | NEEDED | Support email or web form required for submission |
| 9 | Account deletion | FUTURE | Documented placeholder; self-service deletion before public release |

## Data & security

| # | Item | Status | Notes |
|---|------|--------|-------|
| 10 | Data safety notes | DRAFT | Location for prayer/Qibla only when granted; account data for sync |
| 11 | Account / session handling | PASS | JWT sessions; logout supported |
| 12 | Payment / subscription notes | PARTIAL | Stripe abstraction; `provider_not_configured` locally |
| 13 | Location permission | DOCUMENTED | Prayer times & Qibla only; no background tracking |
| 14 | No unnecessary permissions | VERIFY | Audit `AndroidManifest.xml` before release |
| 15 | Android cleartext HTTP | DEBUG ONLY | Local QA uses HTTP; release must use HTTPS |
| 16 | Release HTTPS API | NEEDED | Production API + TLS required |
| 17 | No secrets in app | PASS | No production keys in repo |
| 18 | No hardcoded production keys | PASS | Dart-defines / env for local test only |

## Islamic safety & content

| # | Item | Status | Notes |
|---|------|--------|-------|
| 19 | AI Islamic guidance disclaimer | PASS | Splash, Ask AI, terms placeholder |
| 20 | Scholar / fatwa limitation disclaimer | PASS | No “guaranteed fatwa” claims |
| 21 | High-risk escalation | PASS | Escalation to scholar review path |
| 22 | Content safety / moderation | PARTIAL | Backend guardrails; store moderation policy needed |

## Release engineering (later)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 23 | App screenshots | NEEDED | Phone + tablet captures for stores |
| 24 | Release signing | NEEDED | Owner keystore / Play App Signing |
| 25 | Final production API / TLS | NEEDED | Not live in local QA |

## Phase 6H admin feature control

- `GET /v1/features` — mobile feature gates
- `GET /v1/admin/features` — admin list (JWT admin required)
- `PUT /v1/admin/features/{feature_key}` — update gate
- `POST /v1/admin/features/reset-defaults` — restore 25 defaults
- `GET /v1/admin/app-status` — summary counts

## Owner local test

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

```bash
BUILD_APK=1 ./scripts/sakina-owner-local-test.sh
```

**Local admin (QA only):** `owner@sakina.local` / `SakinaLocalOwner2026!` — seeded when `SAKINA_SEED_LOCAL_ADMIN=true`.

Web at `localhost:8090` is **diagnostics only**. The product is the **Android APK**.
