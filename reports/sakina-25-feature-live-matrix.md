# Sakina AI — 25-Feature Live Matrix

Date: 2026-06-22 · Stack: local Docker (api :28080, Postgres 15) + Flutter 3.41.7.
PASS = real + wired + command-proven. PARTIAL = real but incomplete/unproven. BLOCKED = not implemented / needs external dependency.

| # | Feature | Backend endpoint | DB table / migration | Mobile screen | Auth | Free/Paid | Safety handling | Test | Result |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Ask AI Shaikh | `/api/sakina/ask` | brain_decision_traces, ask_shaikh_answers (014/021) | chat_screen | user | free (login) | keyword safety + citation gate + escalation | curl wudu→cited+trace | PASS |
| 2 | Scholar review/escalation | `/admin/scholar-*`, scholar_review_queue insert | scholar_review_queue (021), scholar_resolved_answers (025), scholar_accounts (027) | — (admin web) | admin/scholar | free | high-risk → queue | fatwa→queue row; assign/resolve | PARTIAL (no queue-read API / user delivery — SAK-009) |
| 3 | Quran reader | `/v1/modules/quran/overview` | quran_* (022) | ModuleReadOnlyStateScreen | user+entitlement | paid (quran_access) | gated | 402→200 gating | PASS (gating); corpus not loaded |
| 4 | Tafsir | `/v1/islamic/*`, tafsir handler | quran_tafsir_* (022) | islamic_library_screen | none/user | free/limited | citations | endpoints exist | PARTIAL (corpus not ingested) |
| 5 | Hadith search | `/v1/islamic/search` | hadith_* (023) | islamic_library_screen | none | free/limited | citations | endpoints exist | PARTIAL (corpus not ingested) |
| 6 | Fatwa verification | `/api/fatwa/verify`, fatwa_verifier | fatwa_* (023) | — | none | free | escalation | handler exists | PARTIAL (no UI; corpus) |
| 7 | New Muslim path | `/api/sakina/ask` (intent new_muslim) | local_sunni_topics (021) | chat_screen | user | free | safety | intent routing | PARTIAL (no dedicated journey UI) |
| 8 | Prayer times | — | — | ModuleReadOnlyStateScreen (gated) | user | paid | — | none | BLOCKED (no time-calc endpoint) |
| 9 | Adhan | — | — | — | — | — | — | none | BLOCKED (not implemented) |
| 10 | Masjid near me | — | — | — | — | — | — | none | BLOCKED (needs external maps API) |
| 11 | Qibla | `/api/tools/qibla` | none (pure calc) | calculators_screen (Qibla tab) | none | free | n/a | London→118.99° | PASS |
| 12 | Zakat calculator | `/api/tools/zakat` | none | calculators_screen (Zakat tab) | none | free | citation | 10000→250 due | PASS |
| 13 | Inheritance calculator | `/api/tools/inheritance` | none | calculators_screen (Inheritance tab) | none | free | scope note + scholar advice | faraid + 'awl/radd | PASS (core scope) |
| 14 | Dua library | — | — | — | — | — | — | none | BLOCKED (not implemented) |
| 15 | Daily reminders | `/v1/notifications/*` | notifications (009) | (in chat screen) | user | free | — | endpoints exist | PARTIAL (no scheduler) |
| 16 | Islamic calendar | `/api/tools/hijri` | none | (endpoint only) | none | free | n/a | 2026-06-22→1448-01-06 | PARTIAL (endpoint PASS, no UI tab) |
| 17 | Ramadan tools | — | — | — | — | — | — | none | BLOCKED |
| 18 | Hajj/Umrah guide | — | — | — | — | — | — | none | BLOCKED |
| 19 | Muslim kids AI games | — | — | kids_quran_screen (honest coming-soon) | user | free | kids-safe | none | BLOCKED (Priority-3 pending) |
| 20 | Family/kids-safe mode | — | — | — | — | — | content safety | none | BLOCKED |
| 21 | User bookmarks | — | quran_bookmarks (022) | — | user | free | — | table exists | BLOCKED (no endpoint/UI) |
| 22 | Personal learning history | `/api/brain/traces/{id}` | brain_decision_traces (014) | (chat history) | user | free | isolation | B→A 404 isolation | PASS |
| 23 | Citation/source viewer | ask `citations[]` | jsonb on answers | CitationBadge / chat | user | free | verified sources | wudu cited | PASS |
| 24 | Admin/scholar dashboard | `/v1/dashboard/guardrails`, `/admin/*` | safety_classifications (028), admin_users (010) | — (no mobile admin) | admin | n/a | RBAC | nonadmin 403 / admin 200 | PARTIAL (backend PASS; no mobile admin UI) |
| 25 | Subscription/payment readiness | `/v1/subscriptions/*`, entitlement gate | subscription_plans, user_subscriptions (029), entitlements (026) | — | user | n/a | — | gating 402→200 | PARTIAL (no payment provider integration) |

## Tally
- PASS: 8 (Ask Shaikh, Quran gating, Qibla, Zakat, Inheritance, Learning history, Citation viewer, Admin-backend)
- PARTIAL: 9 (Scholar loop, Tafsir, Hadith, Fatwa, New-Muslim, Reminders, Islamic calendar, Admin dashboard mobile, Subscriptions)
- BLOCKED: 8 (Prayer times, Adhan, Masjid, Dua library, Ramadan, Hajj/Umrah, Kids games, Family mode, Bookmarks)

## Honest note
This is not full 25-feature coverage. The deterministic calculators + Ask Shaikh + safety + gating + isolation are real and proven; roughly a third of features are unbuilt (no endpoint/screen) or depend on external services (maps, payments) or corpus ingestion.
