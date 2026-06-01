# Phase 21 + 22 Implementation Checklist Plan (Docs-Only)

Date: 2026-06-01  
Scope: planning artifacts only; no deployment, no implementation code, no placeholder claims.

---

## 1) Canonical locations to use during implementation

- Backend: `sakina-backend/src/`
- Frontend (Flutter): `sakina-frontend/lib/`
- Current DB migration area: `sakina-backend/db/`
- OpenAPI/contracts: `sakina-docs/MODULE_CONTRACTS_OPENAPI_2026-05-28.yaml`, `sakina-docs/API.md`
- Planning/docs root: `sakina-docs/`
- CI workflows: `.github/workflows/`

---

## 2) File-by-file implementation checklist (proposed)

### Roadmap and product planning docs
- [ ] `sakina-docs/SAKINA_MOBILE_PHASED_DELIVERY_PLAN_2026-05-27.md`
  - keep Phase 21 after Phase 20 and Phase 22 after Phase 21
  - preserve planning-only status until real implementation passes all gates
- [ ] `sakina-docs/PHASE_21_22_IMPLEMENTATION_CHECKLIST_PLAN.md`
  - maintain execution checklist and readiness state

### Backend contracts and handlers (future code work)
- [ ] `sakina-docs/MODULE_CONTRACTS_OPENAPI_2026-05-28.yaml`
  - add Phase 21 and 22 request/response schemas and auth requirements
- [ ] `sakina-backend/src/handlers/` (new Phase 21/22 handlers)
  - journey, privacy, evidence, dua-intelligence, family-scope, human-review contracts
- [ ] `sakina-backend/src/services/`
  - evidence-bundle enforcement and safe fallback orchestration

### Database migrations (future SQL work)
- [ ] `sakina-backend/db/202606xx_phase21_daily_iman_journey.sql` (new)
- [ ] `sakina-backend/db/202606xx_phase22_competitive_advantage_pack.sql` (new)
- [ ] `sakina-backend/db/202606xx_phase21_22_rollback.sql` (new)

### Flutter screens/components (future app work)
- [ ] `sakina-frontend/lib/screens/iman_journey_*.dart` (new Phase 21 screens)
- [ ] `sakina-frontend/lib/screens/privacy_*.dart` (new Phase 22 trust screens)
- [ ] `sakina-frontend/lib/screens/dua_*.dart` (new dua-intelligence screens)
- [ ] `sakina-frontend/lib/screens/family_*.dart` (new family mode screens)
- [ ] `sakina-frontend/lib/services/api_service.dart`
  - wire APIs only after OpenAPI contracts are approved
- [ ] `sakina-frontend/lib/app/app_state.dart`
  - add journey/privacy/evidence/family state containers

### CI/test gate updates (future test work)
- [ ] `.github/workflows/backend-ci.yml`
  - migration validation, contract tests, evidence fallback tests
- [ ] `.github/workflows/frontend-ci.yml`
  - Flutter widget/integration coverage for new screens and safety states
- [ ] `.github/workflows/dependency-scan.yml`
  - keep dependency/security checks for new packages
- [ ] `.github/workflows/secret-scan.yml`
  - enforce no secret leakage in new test fixtures and docs

---

## 3) Proposed DB migration plan

### Phase 21 tables
- `iman_focus_daily`
  - purpose: store Today's Iman Focus and daily context envelope per user/date
  - indexes: `(user_id, focus_date)` unique, `(updated_at)`
  - privacy/security notes: no raw chat transcript storage by default; minimal retention fields
- `journey_topic_continuity`
  - purpose: Continue Yesterday's Topic linkage and tomorrow follow-up pointer
  - indexes: `(user_id, journey_date)` unique, `(continuity_source_date)`
  - privacy/security notes: avoid storing sensitive free text unless user explicitly saves
- `worship_progress_daily`
  - purpose: Prayer / Qur'an / Dhikr Progress tracking
  - indexes: `(user_id, progress_date)` unique
  - privacy/security notes: aggregate counters preferred over detailed behavior traces
- `dua_list_items`
  - purpose: Personal Dua List with private/public scope flag
  - indexes: `(user_id, created_at)`, `(user_id, is_private)`
  - privacy/security notes: private by default, encrypted-at-rest columns for private dua text
- `family_reminder_links`
  - purpose: Family Reminder opt-in links and reminder scope
  - indexes: `(owner_user_id, family_scope_id)`, `(family_scope_id, active)`
  - privacy/security notes: explicit consent required before cross-user reminder actions
- `religious_evidence_bundles`
  - purpose: evidence bundle enforcement records for generated religious reminders/answers
  - indexes: `(bundle_id)` primary, `(content_hash)`, `(verification_state)`
  - privacy/security notes: store provenance metadata, never fabricate source rows

### Phase 22 tables
- `privacy_dashboard_events`
  - purpose: Trust & Privacy Dashboard action history (export/delete/reset/toggle)
  - indexes: `(user_id, event_time)`, `(action_type)`
  - privacy/security notes: immutable audit path for account-sensitive actions
- `evidence_shield_audit`
  - purpose: Evidence Shield decision trail and fallback triggers
  - indexes: `(answer_id)`, `(user_id, created_at)`, `(fallback_triggered)`
  - privacy/security notes: required for religious-evidence compliance review
- `iman_journey_plus_profiles`
  - purpose: Daily Iman Journey Plus settings (modes, cadence, tone constraints)
  - indexes: `(user_id)` unique
  - privacy/security notes: no manipulative-streak fields allowed
- `dua_intelligence_prefs`
  - purpose: Personal Dua Intelligence preferences and data-use toggles
  - indexes: `(user_id)` unique
  - privacy/security notes: default opt-out for personalization from private duas
- `student_global_plan_eligibility`
  - purpose: Student Global Plan and sponsored access eligibility
  - indexes: `(user_id)`, `(verification_state)`, `(expires_at)`
  - privacy/security notes: retain proof metadata only, no excess identity document storage
- `human_scholar_review_queue`
  - purpose: Human Scholar Review Layer request lifecycle
  - indexes: `(status, priority)`, `(created_at)`, `(answer_id)`
  - privacy/security notes: strict access control and reviewer action audit
- `family_iman_mode_scopes`
  - purpose: Family Iman Mode scope boundaries and consent grants
  - indexes: `(family_scope_id)`, `(member_user_id, consent_state)`
  - privacy/security notes: enforce family data isolation by explicit shared scope only

---

## 4) Proposed API endpoint plan

### Phase 21
- `GET /v1/iman-journey/today`
  - purpose: fetch Today's Iman Focus + prayer/Qur'an/dhikr + continuity context
  - auth/privacy rule: authenticated user only; return only self or explicitly shared family scope
- `POST /v1/iman-journey/continue-yesterday`
  - purpose: bind Continue Yesterday's Topic into current day plan
  - auth/privacy rule: authenticated user; source topic must belong to same user scope
- `PATCH /v1/iman-journey/progress`
  - purpose: update Prayer / Qur'an / Dhikr Progress
  - auth/privacy rule: authenticated user; no writes outside own account
- `POST /v1/dua-list`
  - purpose: add Personal Dua List item and privacy flag
  - auth/privacy rule: private by default; explicit user selection needed for any sharing
- `POST /v1/family-reminders`
  - purpose: create Family Reminder in approved family scope
  - auth/privacy rule: requires active consent in family scope
- `POST /v1/ask-sakina/today-context`
  - purpose: ask Sakina with today context envelope attached
  - auth/privacy rule: context assembly excludes private data without opt-in
- `POST /v1/iman-journey/tomorrow-follow-up`
  - purpose: schedule Tomorrow Follow-up
  - auth/privacy rule: user-owned reminder only; quiet-hours honored
- `PATCH /v1/iman-journey/notification-privacy-settings`
  - purpose: manage notification/privacy settings
  - auth/privacy rule: user-level settings, no cross-account access

### Phase 22
- `GET /v1/privacy/dashboard`
  - purpose: Trust & Privacy Dashboard read model
  - auth/privacy rule: authenticated user; never includes other account data
- `POST /v1/guidance/evidence-shield/validate`
  - purpose: Evidence Shield verification before answer/recommendation release
  - auth/privacy rule: enforce evidence bundle or safe fallback
- `GET /v1/iman-journey-plus`
  - purpose: Daily Iman Journey Plus mode and continuity config
  - auth/privacy rule: authenticated user only
- `PATCH /v1/dua-intelligence/preferences`
  - purpose: Personal Dua Intelligence toggles
  - auth/privacy rule: private dua usage requires explicit opt-in
- `POST /v1/subscription/student-global/verify`
  - purpose: Student Global Plan eligibility check
  - auth/privacy rule: minimize and redact verification payloads
- `POST /v1/guidance/human-scholar-review`
  - purpose: Human Scholar Review Layer request submission
  - auth/privacy rule: authenticated user; review queue access restricted by role
- `PATCH /v1/family-iman-mode/scopes/{scope_id}`
  - purpose: Family Iman Mode scope/consent updates
  - auth/privacy rule: all members must have explicit consent for shared operations

---

## 5) Proposed Flutter screen/component plan

### Phase 21
- `TodayImanFocusCard`
  - purpose: Today's Iman Focus surface
  - state handling: hydrated from `/v1/iman-journey/today`; safe fallback state when evidence missing
- `ContinueYesterdayTopicPanel`
  - purpose: Continue Yesterday's Topic action
  - state handling: local optimistic update with server reconciliation
- `WorshipProgressSection`
  - purpose: Prayer / Qur'an / Dhikr Progress entry and view
  - state handling: local cache + server patch queue for offline resilience
- `PersonalDuaListSection`
  - purpose: Personal Dua List CRUD and privacy tags
  - state handling: encrypted local cache marker + server source of truth
- `FamilyReminderComposer`
  - purpose: Family Reminder creation in consented scope
  - state handling: scope eligibility loaded before submit
- `AskSakinaTodayContextComposer`
  - purpose: Ask Sakina with today context
  - state handling: context preview, opt-in toggles, strict error/safe fallback states
- `TomorrowFollowUpCard`
  - purpose: Tomorrow Follow-up scheduling and status
  - state handling: idempotent reminder scheduling response handling
- `NotificationPrivacySettingsScreen`
  - purpose: notification/privacy settings
  - state handling: durable settings model with local + remote sync checks

### Phase 22
- `TrustPrivacyDashboardScreen`, `EvidenceShieldPanel`, `DailyImanJourneyPlusScreen`,
  `PersonalDuaIntelligenceScreen`, `StudentGlobalPlanScreen`, `HumanScholarReviewScreen`,
  `FamilyImanModeScreen`
  - purpose: implement hard requirement screens/modules
  - state handling: contract-first models with dedicated error and denied-access states

---

## 6) CI/test gate plan

- Backend:
  - migration idempotency + rollback verification
  - authz tests for all Phase 21/22 endpoints
  - evidence bundle enforcement tests (religious output blocked without evidence or safe fallback)
- Frontend:
  - widget tests for all new phase sections and denied-access states
  - integration tests for consent/privacy toggles and safe fallback UX
- E2E:
  - daily continuity flow (today -> tomorrow)
  - family scope isolation flow
  - scholar-review request flow
- Evidence:
  - fail build if evidence bundle contract fields are absent on religious response types
- Privacy:
  - fail build on cross-account leakage tests
  - fail build if private-dua opt-in default is not strict
- Family data isolation:
  - negative tests for unauthorized read/write across family members and scopes

---

## 7) Privacy/security/religious-evidence gate plan

- Privacy:
  - data minimization review before any migration merge
  - explicit user controls for memory/personalization and family sharing
- Security:
  - endpoint authz matrix required for merge
  - audit logging for privacy actions and evidence decisions
- Religious evidence:
  - no Qur'an/hadith/fatwa/scholar claim without verifiable evidence bundle
  - mandatory safe fallback if evidence is missing, invalid, or low confidence
  - no fabricated Islamic sources under any condition

---

## 8) Exactly what remains before implementation can start

1. Product sign-off on final Phase 21/22 scope and wording for all user-facing modules.
2. Data governance sign-off on retention windows, private dua handling, and family-scope consent model.
3. OpenAPI contract draft update and cross-team approval (backend + Flutter).
4. Migration naming/versioning approval and rollback acceptance criteria.
5. CI gate definitions translated into enforceable checks in backend/frontend workflows.
6. Religious evidence policy approval: evidence bundle schema, fallback language rules, and audit obligations.
7. Security review kickoff package prepared (threat model + endpoint authz matrix).

Implementation should not start until all seven items above are approved.
