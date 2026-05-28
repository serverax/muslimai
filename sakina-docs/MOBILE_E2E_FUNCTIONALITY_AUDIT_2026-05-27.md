# SakinaAI Mobile E2E Functionality Audit (Mobile-First)

Date: 2026-05-27  
Branch audited: `qa-security-hardening` (`2e85aa7`)  
Audit intent: mobile-first truth audit, no fake features, no production changes.

---

## 1) Current phase status

- **Phase 0 (landing + waitlist baseline):** **READY**
- **Phase 1 (mobile foundation):** **PARTIAL**
- **Phase 2+ (auth, dashboard, prayer, Quran, AI companion, subscription, admin):** **NOT BUILT / STUB / BLOCKED** depending on feature

---

## 2) What is genuinely working (real)

- Public landing endpoints:
  - `http://7jzi.com/` -> 200
  - `http://7jzi.com/lander` -> 200
- Backend operational endpoints:
  - `GET /health` and `GET /v1/health` -> 200
  - `GET /ready` and `GET /v1/ready` -> 200 with `database_reachable=true`, `waitlist_table_exists=true`
  - `GET /metrics` and `GET /v1/metrics` -> Prometheus text response
- Waitlist API core:
  - `POST /waitlist` valid -> 200
  - `POST /v1/waitlist` valid -> 200
  - Duplicate email handled cleanly (200, upsert semantics)
  - Invalid email rejected (400)
- Mobile build quality gates:
  - `flutter analyze` passes
  - `flutter test` passes
  - `flutter build apk --release` passes
- Backend quality gates:
  - `cargo fmt -- --check` passes
  - `cargo test --all-targets` passes
- Secret scanning:
  - `gitleaks detect --source . --config .gitleaks.toml --redact` -> no leaks found

---

## 3) What is fake/mock/stub

- Flutter chat UI is local-only (`TODO: Call API`) and **not wired** to backend.
- `/v1/classify` behavior is currently stub-like (`FiqhQuery` fixed response path).
- `/v1/dashboard/guardrails` returns sample/demo-like guardrail rows.
- RAG path has placeholder elements and failed with live dependency error (`localhost:8000` embeddings target).
- User/profile flows are not production identity flows yet.
- No payment/subscription implementation exists.
- No real admin workflow exists.

Note: mocks are acceptable in tests; user-visible production paths above are currently not acceptable for “full product” claims.

---

## 4) What is hidden/disabled

- Login UI, subscription UI, and real dashboard product workflows are effectively absent from the current Flutter runtime flow.
- In current branch backend code, user account/profile handlers are explicitly designed to return `501` (disabled until auth/profile phase).  
  (Observed live runtime appears ahead/behind branch in some routes; see item 8.)

---

## 5) What returns 501

- In audited branch code:
  - `POST /v1/users` -> intended `501 Not Implemented`
  - `GET /v1/users/{user_id}` -> intended `501 Not Implemented`
- In currently live runtime during audit, user endpoints still behaved as stubs rather than consistent 501-disabled contract.

---

## 6) What is safe to show users now

Safe for public visibility today:

- Landing page experience
- Waitlist submission flow
- Operational health/readiness for operators

Not safe to market as “complete Muslim AI companion” yet:

- Real AI guidance/chat journey
- Authenticated user account journey
- Premium/subscription journey
- Admin/moderation journey

---

## 7) Required before Android internal testing

Minimum to enter Android internal testing honestly:

1. Mobile shell polish:
   - app icon/name/splash finalized
   - no debug/demo strings in user-visible screens
2. API contract alignment:
   - live runtime matches audited branch behavior
   - no endpoint drift
3. Chat honesty:
   - if AI not ready, hide chat or mark clear “Coming soon”
   - no fake success responses
4. Production URL hygiene:
   - no localhost baked into release configuration
5. Error states:
   - offline/network/auth errors shown cleanly
6. Language:
   - AR/EN switch and basic localized strings present in mobile shell

---

## 8) Required before public beta

Must-have before public beta:

1. Real auth/session/token flow (register/login/logout/forgot-password)
2. Protected dashboard routes (no unauthenticated access)
3. Real profile persistence (language/timezone/preferences)
4. Honest feature gating:
   - incomplete features hidden/disabled or 501
5. TLS and metrics hardening for production posture
6. Prayer module real-data implementation (if included in beta scope)
7. Basic Quran module with verified source handling (if included in beta scope)

---

## 9) Required before calling it a real Muslim AI companion

Must-have before this claim:

1. Real RAG + model chain in production (no static/stub answers)
2. Source/citation display for guidance answers
3. Guardrail/fallback behavior with clear user messaging
4. No fabricated Islamic content, hadith, dua, or scholar attributions
5. English + Arabic user support through key AI flows
6. Safety policy + disclaimer paths in guidance UX
7. End-to-end mobile journey: login -> dashboard -> guidance -> saved progress

---

## Feature readiness table

Feature | Phase | Status | Real backend? | Real mobile UI? | User-visible? | Evidence | Next action
---|---|---|---|---|---|---|---
Landing page | 0 | READY | Yes | N/A | Yes | `curl -i http://7jzi.com/` 200 | Keep stable
Waitlist API | 0 | READY | Yes | N/A | Yes | valid + duplicate + invalid payload checks | Keep stable, monitor abuse
Waitlist frontend form | 1 | NOT BUILT | N/A | No | No | no waitlist form in Flutter app flow | Add mobile waitlist/account-intro screen
Health endpoint | 0 | READY | Yes | N/A | Operator-visible | `/health` 200 | Keep
Readiness endpoint | 0 | READY | Yes | N/A | Operator-visible | `/ready` checks DB/table/env true | Keep
Metrics endpoint | 0 | PARTIAL | Yes | N/A | Yes (public) | `/metrics` 200 text output | Restrict access in later phase
Flutter APK build | 1 | READY | N/A | Yes | Internal only | `flutter build apk --release` pass | Device install smoke
Flutter app launch journey | 1 | PARTIAL | N/A | Partial | Yes | app shell/chat screen exists | Build onboarding + navigation
Arabic language support | 1 | PARTIAL | N/A | Partial | Partial | Arabic text present, full i18n not wired | Add full localization pipeline
English language support | 1 | PARTIAL | N/A | Partial | Yes | English shell text present | Complete localization parity
Auth (register/login/logout) | 2 | NOT BUILT | No | No | No | no full auth flow | Implement real auth module
Profile/account | 2-3 | RETURNS 501 | Partial | No | No | backend intended 501 in branch | Implement real profile persistence
Dashboard real data | 3 | STUB | Partial | No | No | stub/sample endpoints and static cards | Build real dashboard data contracts
Prayer companion | 4 | NOT BUILT | No | No | No | no implemented prayer flow | Implement real prayer data + UI
Quran module | 5 | NOT BUILT | No | No | No | no full module wired | Implement with verified sources
AI guidance chat | 6 | STUB | Partial | No | No | RAG 500 + chat UI TODO | Wire real model/RAG + mobile UI
Dua/knowledge module | 7 | NOT BUILT | No | No | No | not implemented as product flow | Build verified content module
Subscription/entitlement | 8 | NOT BUILT | No | No | No | no plan/entitlement models | Add server-side entitlement core
Admin/moderation | 9 | STUB | Partial | N/A | Not for public | sample dashboard guardrails response | Build RBAC admin module
Route protection | 2+ | PARTIAL | Partial | No | Partial | some sync header checks only | Add full auth middleware + guards
No-fake policy enforcement | All | PARTIAL | Partial | Partial | Partial | stubs still visible in some paths | Hide/disable incomplete surfaces

---

## Final mobile-first truth statement

SakinaAI is currently **honest and ready only as Phase 0 (landing + waitlist)**.  
It is **not yet** a complete mobile Muslim AI companion product.  
To move forward safely, ship by phases with strict no-fake enforcement: incomplete features must be hidden, disabled, or return 501.
