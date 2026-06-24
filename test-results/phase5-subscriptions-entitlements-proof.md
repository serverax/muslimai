# PHASE 5 — Subscriptions / Entitlements / Payment gating proof (Tue Jun 23 19:16:00 UTC 2026)
No mocks, no fake PASS, Docker/local real services only. Image 15cff27ad853. Clean-DB migrations applied: 38.
```
api: healthy
=== FREE FEATURES (no login) ===
quran=200 prayer=200 guide=200 dua=200 zakat=200 plans_anon=200  (all expect 200)
=== LOGIN-REQUIRED still 401 anon ===
bookmarks=401 reminders=401 subscription/me=401 entitlements/me=401  (all expect 401)
=== ASK QUOTA (free ask limit=3) ===
ask 4x: 200 200 200 402  (expect 200 200 200 402)
=== ADMIN GRANT/REVOKE + premium unlock ===
nonadmin grant=403 (403)  admin grant=200 (200)
premium ask now=200 (200)  tier=premium
admin revoke=200 (200)  tier after=free
=== PAID-ONLY entitlement check ===
free check advanced_quran_tools: allowed=False tier=premium
premium check advanced_quran_tools: allowed=True
=== PAYMENT (honest) ===
provider-status=provider_not_configured  checkout=provider_not_configured
webhook untrusted=400 (expect 400)  events admin=200 anon=401
=== REGRESSION ===
ask=ALLOWED_WITH_GUARDRAILS cited=True  fatwa=ESCALATED_TO_HUMAN
corpus_quran=5 hadith=1 kids=8 duas=32 bookmark=201
override audit rows=2  payment_events rows=0
```
