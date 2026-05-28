# SakinaAI Mobile Phased Delivery Plan (No-Fake Policy)

Date: 2026-05-27  
Principle: mobile-first delivery with strict honesty at every phase.

---

## Core delivery rules (non-negotiable)

1. No fake production behavior:
   - no mock AI answers
   - no static/demo guidance pretending to be real
   - no fake dashboard data
   - no fake login/profile/subscription
2. Mocks only in tests.
3. Incomplete features must be:
   - hidden, or
   - disabled, or
   - explicit 501 backend contract.
4. No production deployment from planning tasks.
5. No PVC/data deletion without explicit approval.

---

## Delivery architecture style (modular programming)

- `sakina-frontend` modules by feature:
  - `auth/`, `onboarding/`, `dashboard/`, `prayer/`, `quran/`, `guidance/`, `profile/`, `settings/`, `subscription/`
- `sakina-backend` modules by bounded context:
  - `handlers/auth.rs`, `handlers/profile.rs`, `handlers/prayer.rs`, `handlers/quran.rs`, `handlers/guidance.rs`, `handlers/subscription.rs`, `handlers/admin.rs`
  - services split per domain and interface-backed for testing
- Contract-first:
  - OpenAPI/JSON schema per phase
  - frontend and backend integration tests against same contracts
- Feature flags:
  - release incomplete modules as hidden/disabled (not fake)

---

## Phase-by-phase implementation plan

## Phase 0 — Current production baseline (keep stable)

### Objective
Preserve working public entry funnel.

### Scope
- Landing (`7jzi.com`, `/lander`)
- API baseline (`/health`, `/ready`, `/metrics`, `/waitlist`, `/v1/waitlist`)
- DB-backed waitlist writes

### Exit gate
- Endpoint smoke tests pass
- Waitlist write + duplicate behavior verified
- No regression in baseline uptime paths

---

## Phase 1 — Mobile app foundation

### Objective
Produce a real installable Android app shell.

### Frontend tickets
- FE-P1-001: finalize Android scaffold and release signing prep
- FE-P1-002: welcome/login-choice screen (luxury Islamic design)
- FE-P1-003: onboarding shell and route structure
- FE-P1-004: global loading/error/empty/offline states
- FE-P1-005: AR/EN language selector and persistence
- FE-P1-006: production environment wiring (no localhost default in release)

### Backend tickets
- BE-P1-001: health/readiness consistency and error contract baseline
- BE-P1-002: CORS policy implementation for intended domains

### Exit gate
- `flutter analyze`, `flutter test`, `flutter build apk --release` all pass
- app launch smoke on real Android device
- no demo/mock text in user-facing production build

---

## Phase 2 — Auth and user identity foundation

### Objective
Implement real identity and protected access.

### Frontend tickets
- FE-P2-001: registration/login/logout/forgot-password screens
- FE-P2-002: secure token/session storage and refresh handling
- FE-P2-003: auth route guards for dashboard/profile

### Backend tickets
- BE-P2-001: auth endpoints (`/v1/auth/register`, `/v1/auth/login`, `/v1/auth/refresh`, `/v1/auth/logout`)
- BE-P2-002: JWT/session middleware for protected routes
- BE-P2-003: `users` + profile persistence model
- BE-P2-004: consistent 401/403 error shapes

### Exit gate
- dashboard inaccessible without valid session
- register/login flow persisted in DB
- invalid credentials handled safely
- if incomplete: protected features return 501 or remain hidden

---

## Phase 3 — Mobile dashboard + profile

### Objective
Deliver real post-login user home.

### Frontend tickets
- FE-P3-001: dashboard shell with real API data only
- FE-P3-002: profile/settings/language switch
- FE-P3-003: notification preferences UI only where backend exists

### Backend tickets
- BE-P3-001: profile read/update endpoints
- BE-P3-002: user settings/preferences endpoints

### Exit gate
- no fake dashboard cards
- no fake stats/recommendations
- incomplete cards marked “Coming soon” and non-clickable

---

## Phase 4 — Prayer companion

### Objective
First complete Islamic utility.

### Frontend tickets
- FE-P4-001: prayer times screen + next prayer countdown
- FE-P4-002: manual city/country/timezone selector
- FE-P4-003: reminder controls
- FE-P4-004: qibla UI (only if source data/logic real)

### Backend tickets
- BE-P4-001: prayer-time calculation endpoint/service
- BE-P4-002: timezone/location mapping support

### Exit gate
- prayer times verified against documented method
- offline/error behavior implemented
- no fabricated prayer data

---

## Phase 5 — Quran basic module

### Objective
Real Quran reading foundation.

### Frontend tickets
- FE-P5-001: surah list + ayah reader
- FE-P5-002: translation toggle + search
- FE-P5-003: bookmarks
- FE-P5-004: audio controls (only if real source integrated)

### Backend tickets
- BE-P5-001: Quran/translation retrieval APIs
- BE-P5-002: bookmark CRUD APIs
- BE-P5-003: content provenance metadata APIs

### Exit gate
- source/license documented
- no unsourced tafsir/audio shown as real

---

## Phase 6 — AI chat / Islamic guidance foundation

### Objective
Real companion capability.

### Frontend tickets
- FE-P6-001: chat UI wired to backend endpoint
- FE-P6-002: source/citation rendering + confidence display
- FE-P6-003: unsafe/uncertain fallback UX
- FE-P6-004: AR/EN guidance UX parity

### Backend tickets
- BE-P6-001: production chat endpoint contract
- BE-P6-002: real RAG retrieval chain (no static response path)
- BE-P6-003: citation provenance and guardrails
- BE-P6-004: model availability/fallback strategy

### Exit gate
- no fake AI success
- no static demo answers in production
- failure path returns explicit honest errors
- required citation paths available when applicable

---

## Phase 7 — Knowledge base / Duas

### Objective
Trusted Islamic content module.

### Frontend tickets
- FE-P7-001: dua library by categories
- FE-P7-002: favorites + reminders

### Backend tickets
- BE-P7-001: verified content repository and APIs
- BE-P7-002: source metadata exposure

### Exit gate
- no fabricated hadith/dua attribution
- source verification documented

---

## Phase 8 — Subscription and entitlement

### Objective
Honest premium gating.

### Frontend tickets
- FE-P8-001: free vs premium UX states
- FE-P8-002: usage limits indicator
- FE-P8-003: upgrade prompts (no fake checkout completion)

### Backend tickets
- BE-P8-001: plans/subscriptions/entitlements schema
- BE-P8-002: server-side entitlement enforcement middleware
- BE-P8-003: usage counters and throttling

### Exit gate
- premium routes blocked without entitlement (server-side)
- no client-only bypassable gating

---

## Phase 9 — Admin and moderation

### Objective
Safe operational controls.

### Frontend tickets
- FE-P9-001: admin portal screens (approval/content/moderation)

### Backend tickets
- BE-P9-001: admin RBAC middleware
- BE-P9-002: moderation/content workflows
- BE-P9-003: audit log APIs

### Exit gate
- admin surfaces inaccessible to non-admin users
- no public admin data exposure

---

## Phase 10 — Play Store / public beta readiness

### Objective
Release-ready Android public testing package.

### Tickets
- FE-P10-001: AAB packaging/signing/release channel setup
- FE-P10-002: privacy policy + terms + data safety disclosures
- FE-P10-003: crash reporting/release analytics decision
- BE-P10-001: production config audit (no localhost/no debug)

### Exit gate
- installable signed build
- no debug flags
- no localhost dependencies
- public beta scope explicitly documented

---

## Program board: MVP vs post-MVP

### MVP (must complete for real product alpha)
- Phase 0
- Phase 1
- Phase 2
- Phase 3
- Phase 4
- Phase 5 (basic reader + bookmarks only)
- Phase 6 (core guidance path with guardrails and honest fallback)

### Post-MVP
- Phase 7
- Phase 8
- Phase 9
- Phase 10 hardening + broad public scale

---

## Execution order starting now

1. Lock Phase 0 regression suite (landing/waitlist baseline)
2. Phase 1 implementation sprint
3. Phase 2 auth foundation sprint
4. Phase 3 dashboard/profile sprint
5. Phase 6 architecture spike in parallel (to avoid fake-chat trap)

---

## Immediate next sprint checklist (start right away)

### Sprint A (1-2 weeks)
- FE-P1-002, FE-P1-003, FE-P1-004, FE-P1-005, FE-P1-006
- BE-P1-001, BE-P1-002
- FE-P2-001 design stub screens hidden behind feature flag until backend ready

### Sprint B (2 weeks)
- BE-P2-001..004
- FE-P2-001..003
- FE-P3-001 baseline shell with real profile data only

### Sprint C (2 weeks)
- BE/FE prayer + Quran basic modules
- guidance endpoint contract hardening (no static responses)

---

## Success criteria summary

- Each phase ships only real functionality.
- Incomplete features are not presented as complete.
- No fake functionality reaches production.
- Mobile app quality gates pass before any scope expansion.
