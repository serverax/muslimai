# PHASE 2 — Muslim Daily Essentials proof (Tue Jun 23 01:16:33 UTC 2026)
```
=== clean rebuild: down -v + fresh + migrate ===
init errors: 0
Sakina migrations applied: 34
api: healthy

=== PRAYER TIMES (no login) ===
Makkah (21.42,39.83 tz3):
  Fajr 04:14 Dhuhr 12:23 Asr 15:43 Maghrib 19:06 Isha 20:26
London (tz1):
Traceback (most recent call last):
  File "<string>", line 1, in <module>
    import sys,json;d=json.load(sys.stdin);print('  Fajr',d['fajr'],'Dhuhr',d['dhuhr'],'Maghrib',d['maghrib'],'Isha',d['isha'])
                                                          ~^^^^^^^^
KeyError: 'fajr'
Istanbul (41.0,28.97 tz3):
  Fajr 03:25 Dhuhr 13:06 Maghrib 20:40
bad location:
  GET prayer-times (lat=999) -> 400 (expect 400)

=== ISLAMIC CALENDAR (no login) ===
  today: 7 Muharram 1448 | important dates: 6

=== DUA LIBRARY (no login) ===
  DB dua count: 32
  categories: 10
  missing source: 0
  API list count: 32
  category=anxiety count: 4
  search q=forgive count: 6
  sample dua (with source):
    Dua for travel | source: Quran 43:13; Sahih Muslim 1342

=== BOOKMARKS (login + isolation) ===
  A create bookmark id present: yes
  A list count: 1
  B list count (expect 0): 0
  B delete A bookmark -> 404 (expect 404)
  anon list bookmarks -> 401 (expect 401)
  A delete own bookmark -> 200 (expect 200)

=== REMINDERS (login + isolation) ===
  A create reminder id present: yes
  A list count: 1
  B list count (expect 0): 0
  anon list reminders -> 401 (expect 401)
  DB reminders rows: 1

=== REGRESSION: PHASE 1 / 1B scholar loop ===
  fatwa trace: yes ; scholar queue: 200
  scholar resolve -> 200
  user review-status: scholar_answered
  safe wudu cited: ALLOWED_WITH_GUARDRAILS cited=True
```

## London high-latitude fix (rebuild #9)
At 51.5°N in June the sun never reaches the 18° fajr/isha twilight angle (white nights).
Fixed with the "one-seventh of the night" higher-latitude rule. After fix:
```
London 2026-06-23 tz1: Fajr 03:41 Sunrise 04:44 Dhuhr 13:03 Asr 17:26 Maghrib 21:22 Isha 22:25
Makkah unchanged:       Fajr 04:14 ... Isha 20:26
```
All six times present and correctly ordered.

## Mobile
flutter analyze: No issues found. flutter build apk --debug: app-debug.apk 175.7 MB.
Screens: Daily hub -> PrayerTimes / IslamicCalendar / DuaLibrary / Bookmarks / Reminders / AdhanSettings.
Adhan settings = local-only (SharedPreferences); local notification firing = NOT_IMPLEMENTED (honest).
