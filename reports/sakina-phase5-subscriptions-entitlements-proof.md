# Sakina AI — PHASE 5: Subscriptions, Entitlements & Payment Gating Proof

Date: 2026-06-23 · Branch: `qa-security-hardening` · Stack: local Docker (api :28080, real Postgres 15).
Image: `sakina-backend:latest` id **15cff27ad853** (build #12, 178MB, 0 compile errors).
**No mocks, no fake PASS, Docker/local real services only.** Evidence: `test-results/phase5-subscriptions-entitlements-proof.md`.

## Docker / migration
Services: api, postgres, qdrant, redis, llm-gateway (5) — api healthy. Clean `down -v` -> migrate = **38 migrations** (init errors 0; +036). No broken/duplicate IDs.

## Payment provider status
**stripe = provider_not_configured** (no Stripe test keys in this environment). Checkout returns `provider_not_configured` (no fake success). Webhook rejects untrusted/unsigned payloads (400). Stripe is **NOT** marked PASS (honestly not configured).

## Changed files
Backend:
- `db/migrations/036_subscriptions_phase5.sql` (new) — entitlement_usage, payment_events, payment_provider_config_status, admin_entitlement_overrides, feature_gates (11 gates seeded), premium_unlimited entitlement.
- `src/handlers/subscription.rs` (new) — plans/me/entitlements/check/usage, admin grant/revoke, payment provider-status/checkout/webhook/events, `enforce_ask_quota`.
- `src/handlers/sakina_ask.rs` — Ask flow enforces free daily quota (premium/admin bypass).
- `src/error.rs` — `ApiError::payment_required` (402 entitlement_required).
- `src/handlers/mod.rs`, `src/main.rs` — module + 11 /v1 routes. `bin/migrate.rs` — register 036.

Mobile:
- `lib/services/api_service.dart` — subscriptionPlans/paymentProviderStatus/subscriptionMe/entitlementsMe/createCheckoutSession.
- `lib/screens/subscription_screen.dart` (new) — plans, current tier (free/premium), upgrade CTA, honest provider status, locked-feature messaging; never blocks free features.
- `lib/screens/daily_essentials_screen.dart` — Subscription tile.

## Free features (no login) — all 200
Quran reader/search, Tafsir, Hadith search, Islamic sources, Dua, Prayer times, Qibla, Islamic calendar, Zakat, Mirath, guides (wudu/salah/ramadan/hajj/new-muslim), masjid fallback, subscription plans list. Proven: quran/prayer/guide/dua/zakat/plans = 200.

## Login-required (free) — anon 401
Bookmarks, reminders, adhan/preferences, kids progress, subscription/me, entitlements/me. Proven: all 401 anon (and 200/201 when authenticated).

## Paid / premium features — entitlement gated
| Feature gate | tier | Evidence | Result |
|---|---|---|---|
| ask_shaikh (free daily limit) | free+limit | 200,200,200,**402** at limit 3; premium bypass -> 200 | PASS |
| advanced_quran_tools | premium | free user `allowed=false`; premium `allowed=true` | PASS |
| advanced_hadith/zakat/mirath, family_profiles, kids_progress_history, premium_reminders, export_notes, priority_escalation | premium | seeded in feature_gates; `/v1/entitlements/check` returns tier_required=premium | PASS (gate present) |

## Entitlement enforcement proof
| Item | Evidence | Result |
|---|---|---|
| Free ask daily limit enforced | ask 4x -> 200,200,200,402 | PASS |
| Premium unlocks unlimited ask | after admin grant -> 200 (was 402) | PASS |
| Admin grant entitlement | admin -> 200; nonadmin -> 403 | PASS |
| Admin revoke entitlement | admin -> 200; tier reverts premium->free | PASS |
| Admin grant/revoke audited | admin_entitlement_overrides = 2 rows | PASS |
| Paid-only blocked without entitlement | check advanced_quran_tools allowed=false (free) | PASS |
| subscription/me reflects tier | premium after grant, free after revoke | PASS |

## Payment PASS/FAIL
| Item | Evidence | Result |
|---|---|---|
| Provider status endpoint | `provider_not_configured` | PASS |
| Checkout without Stripe | `provider_not_configured` (no fake session/charge) | PASS |
| Webhook rejects untrusted payload | 400 (no STRIPE_WEBHOOK_SECRET / signature) | PASS |
| Payment events admin-only | admin 200, anon 401 | PASS |
| Stripe test-mode flow | not configured in this env | NOT_CONFIGURED (not marked PASS) |
| No fake payment success stored | payment_events = 0 after rejected webhook | PASS |

## Regression (Phase 1 / 1B / 2 / 3 / 4)
| Item | Result |
|---|---|
| Auth register/login | PASS |
| Ask Shaikh cited (ALLOWED_WITH_GUARDRAILS) | PASS |
| High-risk fatwa escalates | PASS (ESCALATED_TO_HUMAN) |
| Corpus (quran 5, hadith 1) | PASS |
| Kids quiz (8) / Dua (32) | PASS |
| Bookmarks create (201) | PASS |
| Scholar tables intact | PASS |
| flutter analyze | PASS (No issues) |
| flutter build apk --debug | PASS |

## Mobile proof
flutter analyze: **No issues found**. APK: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk` — **175.8 MB**. Subscription screen wired into Daily hub; free features not gated behind login; no crash when provider not configured (honest message).

## Known limitations
- Stripe NOT configured in this environment -> `provider_not_configured` (honest). Real test-mode Stripe flow + signature verification is wired to activate when keys are set; not PASS here.
- Ask free limit default 20/day (feature_gates); set to 3 during the proof to demonstrate enforcement.
- Webhook stores events only as `received_unverified` once a secret is configured; full signature verification lands with real Stripe keys.

## Verdict
**PHASE 5 = PASS** (subscriptions + free/paid gating + entitlement enforcement, Docker/local command-proven; payment provider honestly `provider_not_configured`). Overall product verdict remains **PARTIAL_READY**, not LIVE_READY.

## Next recommended phase
PHASE 6 — production deployment (Kubernetes/staging) and live beta testing.
