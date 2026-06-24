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

## Phase 21 — Daily Iman Journey — Retention-Safe Personalization

Placement note: this phase is planned immediately after Phase 20 — Islamic Knowledge Foundation.

### Status
Planning only; no implementation claims in this document.

### Scope
- Today's Iman Focus
- Continue Yesterday's Topic
- Prayer / Qur'an / Dhikr Progress
- Personal Dua List
- Family Reminder
- Ask Sakina with today's context
- Tomorrow Follow-up
- Notification/privacy settings
- Evidence bundle enforcement
- Safe fallback if evidence is missing

### Execution structure
- Phase 21A: Data model, migrations, OpenAPI, DTOs
- Phase 21B: Backend journey generation, memory stitching, reminders
- Phase 21C: Flutter UI sections and safe states
- Phase 21D: Notifications, quiet hours, privacy controls
- Phase 21E: Verification gate, contract tests, evidence audits, UX safety checks

### Important rules
- No fabricated Qur'an, hadith, fatwa, scholar quote, or citation metadata.
- If verified evidence missing or confidence low, return safe general encouragement only.
- No guilt/shame/pressure/manipulative streak language.
- Personalization opt-in.
- Dua list privacy respected.
- Family data isolation unless explicitly shared.
- All religious content audit-logged with evidence_bundle_id.

### PASS-only criteria
- 7 UI sections live and contract-wired
- required DB tables migrated/idempotent
- Day1/Day2 continuity
- evidence bundle or safe fallback enforced
- notification opt-out/quiet hours/privacy settings work
- backend/frontend/e2e tests pass
- security review confirms no family-data exposure

---

## PHASE 22: Sakina Competitive Advantage Pack

Placement note: this phase is planned immediately after Phase 21 to deepen trust, evidence integrity, and daily continuity.

### Status
Planning only; no implementation claims in this document.

### Hard requirement coverage
- Trust & Privacy Dashboard
- Evidence Shield
- Daily Iman Journey Plus
- Personal Dua Intelligence
- Student Global Plan
- Human Scholar Review Layer
- Family Iman Mode

### Purpose
Make Sakina stronger than global Muslim companion competitors by combining:
- privacy-first trust
- evidence-first Islamic AI
- daily spiritual continuity
- personal dua intelligence
- family mode
- student global discount
- low-cost subscription model

### Phase 22A - Trust & Privacy Dashboard
Planned screens/contracts for:
- what Sakina remembers
- delete memory
- export data
- reset spiritual profile
- disable personalisation
- disable dua personalisation
- family sharing controls
- no ads / no data sale pledge screen

### Phase 22B - Evidence Shield
Planned backend rules for:
- Quran citation card
- Hadith citation card
- fatwa/scholar source card
- madhhab label
- confidence/review state
- safe fallback when evidence is missing
- religious answer audit log
- no fabricated Islamic content

### Phase 22C - Daily Iman Journey Plus
Extend Phase 21 with:
- 7-day iman path
- mood-aware reminders
- missed-day welcome back copy
- Ramadan mode
- Jumu'ah mode
- new Muslim mode
- student mode
- no guilt/streak pressure

### Phase 22D - Personal Dua Intelligence
Add:
- dua vault
- private dua toggle
- use-for-personalisation toggle
- dua categories
- dua after salah reminders
- Arabic/English dua rewrite assistant
- privacy-safe dua suggestions

### Phase 22E - Student Global Plan
Add product/pricing config for:
- free plan
- student global discount
- standard plan
- family plan
- hardship/refugee/orphan sponsored access
- mosque/university group codes

### Phase 22F - Human Scholar Review Layer
Future design only:
- request human review
- high-risk fiqh routing
- AI guidance label
- human-reviewed answer status
- paid review credits

### Phase 22G - Family Iman Mode
Add:
- family gratitude minute
- shared Quran goal
- family dua board
- Ramadan family tracker
- strict privacy isolation
- explicit shared-scope consent only

### Planned artifacts (for later implementation)

#### Files/modules to change later
- `sakina-backend/src/handlers/privacy.rs` (new)
- `sakina-backend/src/handlers/guidance.rs` (extend for evidence cards and review labels)
- `sakina-backend/src/handlers/subscription.rs` (extend for student/family/sponsored plans)
- `sakina-backend/src/services/evidence_shield/` (new module set)
- `sakina-backend/src/services/dua_intelligence/` (new module set)
- `sakina-backend/src/services/family_mode/` (new module set)
- `sakina-backend/src/services/human_review/` (future-design contracts only)
- `sakina-backend/src/db/migrations/` (new Phase 22 migration set)
- `sakina-frontend/lib/features/privacy/` (new)
- `sakina-frontend/lib/features/iman_journey/` (extend Phase 21 journeys)
- `sakina-frontend/lib/features/dua/` (extend with vault/privacy toggles)
- `sakina-frontend/lib/features/subscription/` (extend plans and student global logic)
- `sakina-frontend/lib/features/family/` (new shared-scope consent UI)

#### Proposed DB tables
- `privacy_memory_items`
- `privacy_export_jobs`
- `privacy_action_audit_log`
- `religious_evidence_cards`
- `religious_answer_audit_log`
- `religious_answer_review_queue`
- `iman_journey_paths`
- `iman_journey_events`
- `dua_vault_items`
- `dua_privacy_preferences`
- `subscription_plan_catalog`
- `subscription_discount_codes`
- `sponsored_access_grants`
- `family_scopes`
- `family_scope_consents`
- `family_shared_boards`
- `human_review_requests`
- `human_review_decisions`

#### Proposed API endpoints
- `GET /v1/privacy/memory`
- `DELETE /v1/privacy/memory/{memory_id}`
- `POST /v1/privacy/export`
- `POST /v1/privacy/reset-spiritual-profile`
- `PATCH /v1/privacy/personalisation`
- `PATCH /v1/privacy/dua-personalisation`
- `GET /v1/privacy/no-ads-pledge`
- `GET /v1/guidance/evidence/{answer_id}`
- `POST /v1/guidance/audit`
- `POST /v1/guidance/human-review-requests`
- `GET /v1/guidance/human-review-requests/{request_id}`
- `GET /v1/iman-journey/path`
- `POST /v1/iman-journey/reminders/mood`
- `POST /v1/dua/vault`
- `PATCH /v1/dua/vault/{dua_id}/privacy`
- `POST /v1/subscription/discount/validate`
- `GET /v1/subscription/plans/global`
- `POST /v1/family/scopes/consent`
- `GET /v1/family/board`

#### Proposed Flutter screens
- `PrivacyTrustDashboardScreen`
- `MemoryControlScreen`
- `DataExportScreen`
- `SpiritualProfileResetScreen`
- `PersonalisationControlsScreen`
- `NoAdsPledgeScreen`
- `EvidenceShieldCardView`
- `ImanJourneyPlusScreen`
- `DuaVaultScreen`
- `DuaPrivacySettingsScreen`
- `StudentGlobalPlanScreen`
- `SponsoredAccessScreen`
- `HumanReviewRequestScreen`
- `FamilyImanModeScreen`
- `FamilyConsentScopeScreen`
- `FamilyDuaBoardScreen`

#### CI/test gates
- Phase 22 OpenAPI contract tests (backend + Flutter client contract sync)
- Migration idempotency + rollback tests for all new Phase 22 tables
- Religious evidence enforcement tests (citation card or safe fallback required)
- Privacy control integration tests (delete/export/reset/toggle endpoints)
- Family isolation tests (cross-account and cross-scope access denial)
- Subscription plan matrix tests (free/student/standard/family/sponsored)
- Notification/reminder tone checks (no guilt/streak pressure language)
- End-to-end regression suite including Phase 21 continuity + Phase 22 extensions

#### Security/privacy gates
- Data minimisation review on memory and dua retention fields
- Encryption-at-rest and key-path validation for private dua vault data
- Consent verification gate for any shared family scope write/read
- Audit-log immutability checks for religious answer evidence and review events
- Access-control audit for privacy endpoints and export jobs
- Abuse/threat model for discount code and sponsored access issuance
- Pledge compliance gate: no ads targeting and no personal data sale flows

#### Dependencies on Phase 20 and Phase 21
- Requires Phase 20 verified Islamic knowledge foundation for evidence cards and scholar/fatwa source confidence.
- Requires Phase 21 journey continuity primitives (daily context stitching, reminders, privacy controls) as extension base.
- Phase 22C is explicitly an extension layer over Phase 21 journey contracts and safe-language rules.
- Phase 22B evidence shield consumes and hardens evidence-bundle behavior introduced by Phase 20 and used in Phase 21.

#### Planning integrity notes
- No implementation yet: this section is roadmap/planning only and does not claim shipped behavior.
- No fake PASS: Phase 22 cannot be marked PASS until all contracts, data paths, evidence safeguards, privacy gates, and tests are genuinely implemented and verified.

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
- Phase 21 — Daily Iman Journey — Retention-Safe Personalization

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
