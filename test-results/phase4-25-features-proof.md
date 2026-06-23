# PHASE 4 — 25 Features proof (Tue Jun 23 15:27:33 UTC 2026)
No mocks, no fake PASS, Docker/local real services only. Image be4d14620922.
```
=== clean rebuild ===
init errors: 0
Sakina migrations applied: 37
api: healthy | services: 5

=== 25 FEATURES ===
01 Quran reader     surahs=5 surah1_http=200
02 Quran search     refuge=3
03 Tafsir reader    1:1_http=200
04 Hadith search    intention=1
05 Islamic sources  count=10
06 Dua library      /v1/dua=32
07 Prayer times     /v1/prayer-times fajr=04:14
08 Qibla            /v1/qibla bearing=118.98
09 Adhan/prefs      set_pref_http(login)=200 anon=400
10 Islamic calendar /v1/islamic-dates hy=1448
11 Zakat            /v1/zakat/calculate due=250.0
12 Mirath           /v1/mirath/calculate http=200
13 Masjid nearby    status=provider_not_configured
14 New Muslim       http=200
15 Wudu guide       http=200 src=Quran 5:6; Sahih al-Bukhari 159; Sahih Muslim 235
16 Salah guide      http=200
17 Ramadan guide    http=200
18 Hajj guide       http=200
19/20 Ask Shaikh    /v1/ask safety=ALLOWED_WITH_GUARDRAILS cited=True
21 High-risk escal. safety=ESCALATED_TO_HUMAN
22 Scholar queue    http=200
23 Bookmarks        create=201 anon=401
24 Reminders        create=201 anon=401
25 Kids             quiz_q=8 lessons=2 progress(login)=201 anon=400

=== CITATION GUARD + DB traces ===
valid(wudu): valid
escalated(fatwa): escalated
blocked(fabricated): blocked

=== REGRESSION ===
scholar resolve=200  review-status=scholar_answered
kids_progress DB rows=1  prefs DB rows=1
migration count check (regression intact): corpus_quran=25 duas=32
```

## Supplement: login-protected routes block anon with VALID body (401, not payload-400)
```
anon PUT /v1/preferences (valid body): 401 (expect 401)
anon POST /v1/kids/progress (valid body): 401 (expect 401)
```
