# Sakina Mobile Workflows and Button Function Map

Phase 6G — mobile-first user journeys for the Flutter Android APK.

**Product rule:** The APK is the real Sakina app. Web at `http://localhost:8090` is diagnostic only.

---

## User journeys

| # | Journey | Entry | Outcome |
|---|---------|-------|---------|
| 1 | Guest / first-time | Splash → Welcome (first run) or Guest Home | Browse public Quran, prayer, dua, guides; login prompt for protected features |
| 2 | Register / login | Account intro or Login Required screen | JWT stored; lands on logged-in dashboard |
| 3 | Logged-in home | Mobile dashboard (12 cards) | Quick access to all wired features |
| 4 | Ask AI Shaikh | Ask tab or dashboard card | `/api/sakina/ask` with citations and escalation |
| 5 | Scholar review | Scholar Review card / Ask escalation | Poll review status; scholar dashboard if role permits |
| 6 | Quran / Tafsir / Hadith | Study tab | Corpus search, tafsir sample, hadith search, sources |
| 7 | Prayer / Qibla / calendar | Daily tab | Prayer times, Qibla calculator, hijri calendar, adhan prefs |
| 8 | Dua / bookmarks / reminders | Dashboard cards | Public duas; bookmarks/reminders require login |
| 9 | Zakat / Mirath | Dashboard or More | `/api/tools/zakat`, `/api/tools/inheritance` |
| 10 | Kids learning | Dashboard / More | `/kids/quiz`, progress save if logged in |
| 11 | Subscription | Dashboard card | Plans, entitlement, honest payment status |
| 12 | Admin / owner tools | Dashboard / More | API health, feature gates, grant/revoke (admin only) |

---

## Feature flag audit (local APK test mode)

| Feature | Local APK | Login | Premium | Notes |
|---------|-----------|-------|---------|-------|
| Quran read/search | ON (`SAKINA_LOCAL_TEST` or `SAKINA_FEATURE_QURAN=true`) | No | No | Public |
| Tafsir sample | ON | No | No | Public |
| Hadith search | ON | No | No | Public |
| Dua library | ON | No | No | Public |
| Prayer times | ON | No | No | Public |
| Qibla | ON | No | No | Public |
| Islamic calendar | ON | No | No | Public |
| Guides | ON | No | No | Public |
| Ask AI Shaikh | ON | Recommended | Partial | Auth for full history |
| Bookmarks | ON | Yes | No | |
| Reminders | ON | Yes | No | |
| Scholar review status | ON | Yes | No | |
| Kids progress | ON | Optional | No | |
| Zakat / Mirath | ON | No | No | Guidance only |
| Subscription | ON | Preview guest | — | Payment provider often not configured locally |
| Admin tools | ON | Admin role | — | Honest 403 if not admin |
| Scholar resolve | PARTIAL | Scholar role | — | Queue may work; resolve needs scholar account |
| Masjid near me | INCOMPLETE | — | — | Shows provider-needed message |
| Community module | INCOMPLETE | — | — | Not implemented screen |

---

## Button function map

Format: `Screen | Button | Requires login? | API endpoint | Success behaviour | Failure behaviour | Notes`

| Screen | Button | Requires login? | API endpoint | Success behaviour | Failure behaviour | Notes |
|--------|--------|-----------------|--------------|-------------------|-------------------|-------|
| Splash | Continue (auto) | No | `GET /health` | Routes to Welcome or Home shell | Shows offline warning; still continues | Probes API + restores session |
| Splash | Register | No | — | Opens account intro (register) | — | |
| Splash | Login | No | — | Opens account intro (login) | — | |
| Splash | Retry health | No | `GET /health` | Updates health chip | Shows offline | |
| Guest home | Quran Study | No | `GET /quran/*` | Opens Study hub | Error card | |
| Guest home | Prayer & Qibla | No | `GET /api/tools/prayer-times` | Opens Prayer hub | Error card | |
| Guest home | Dua Library | No | `GET /api/duas` | Opens dua list | Error card | |
| Guest home | Islamic Guides | No | `GET /guides/*` | Opens guides list | Error card | |
| Guest home | Subscription Plans | No | `GET /subscription/plans` | Shows plans | Error card | Preview only |
| Guest home | Bookmarks | Yes | `GET /api/bookmarks` | Login Required screen | — | |
| Guest home | Reminders | Yes | `GET /api/reminders` | Login Required screen | — | |
| Guest home | Ask AI Shaikh | Yes | `POST /api/sakina/ask` | Login Required screen | — | |
| Guest home | Login | No | — | Account intro login | Friendly error | |
| Guest home | Register | No | — | Account intro register | Friendly error | |
| Auth | Register | No | `POST /auth/register` | JWT stored → logged-in dashboard | Friendly error card | |
| Auth | Login | No | `POST /auth/login` | JWT stored → logged-in dashboard | Friendly error card | |
| Auth | Continue as guest | No | — | Guest home shell | — | |
| Logged-in dashboard | Ask AI Shaikh | Yes | `POST /api/sakina/ask` | Opens chat | Error in chat | |
| Logged-in dashboard | Quran Study | No | `GET /quran/*` | Study hub | Error card | |
| Logged-in dashboard | Prayer & Qibla | No | `GET /api/tools/prayer-times` | Prayer hub | Error card | |
| Logged-in dashboard | Dua Library | No | `GET /api/duas` | Dua screen | Error card | |
| Logged-in dashboard | Bookmarks | Yes | `GET /api/bookmarks` | Bookmark list | Error card | |
| Logged-in dashboard | Reminders | Yes | `GET /api/reminders` | Reminder list | Error card | |
| Logged-in dashboard | Kids Learning | Optional | `GET /kids/quiz` | Kids quiz | Error card | |
| Logged-in dashboard | Zakat Calculator | No | `POST /api/tools/zakat` | Shows estimate | Error card | Not binding fatwa |
| Logged-in dashboard | Mirath Calculator | No | `POST /api/tools/inheritance` | Simple result or scholar note | Error card | Complex cases → scholar |
| Logged-in dashboard | Subscription | Yes | `GET /entitlements/me` | Plans + tier | Error card | |
| Logged-in dashboard | Scholar Review | Yes | `GET /api/sakina/review-status/{trace}` | Review list | Error card | |
| Logged-in dashboard | Settings | No | — | Settings screen | — | |
| Logged-in dashboard | Admin Tools | Admin | `GET /health`, `/modules` | Status dashboard | Honest 403 | |
| Logged-in dashboard | Logout | Yes | `POST /auth/logout` | Clears JWT → guest home | Error snackbar | |
| Ask AI Shaikh | Ask | Recommended | `POST /api/sakina/ask` | Answer + citations + safety | Humanized error bubble | |
| Ask AI Shaikh | Clear | No | — | Clears chat | — | |
| Ask AI Shaikh | View citations | No | — | Bottom sheet of sources | Status message if none | |
| Ask AI Shaikh | View review status | Yes | `GET /api/sakina/review-status/{trace}` | Scholar reviews screen | — | After escalation |
| Ask AI Shaikh | Back home | No | — | Pop navigator | — | |
| Study hub | Search (Quran) | No | `GET /quran/search` | Results list | Error text | |
| Study hub | Load tafsir | No | `GET /quran/tafsir/{s}/{a}` | Tafsir text + source | Error text | |
| Study hub | Hadith search | No | `GET /hadith/search` | Hadith results | Error text | |
| Study hub | Sources tab | No | `GET /islamic-sources` | Source registry | Error text | |
| Prayer hub | Refresh prayer times | No | `GET /api/tools/prayer-times` | Updated times | Error card | Manual city mode |
| Prayer hub | Change city | No | — | Edit lat/lng fields | — | Default London |
| Prayer hub | Open Qibla | No | `POST /api/tools/qibla` | Qibla calculator | Error card | |
| Prayer hub | Save adhan preference | No | — | Local SharedPreferences | — | Device only |
| Dua | Search | No | `GET /api/duas` | Filtered list | Error card | |
| Dua | Save bookmark | Yes | `POST /api/bookmarks` | Snackbar success | Error snackbar | |
| Bookmarks | Remove | Yes | `DELETE /api/bookmarks/{id}` | Refreshes list | Error | |
| Bookmarks | Open | Yes | — | Opens content | — | |
| Reminders | Add | Yes | `POST /api/reminders` | Adds reminder | Error | |
| Reminders | Delete | Yes | `DELETE /api/reminders/{id}` | Removes item | Error | |
| Zakat | Calculate | No | `POST /api/tools/zakat` | Estimated amount | Error card | |
| Zakat | Reset | No | — | Clears fields | — | |
| Mirath | Calculate | No | `POST /api/tools/inheritance` | Shares or scholar note | Error card | |
| Kids | Start quiz | No | `GET /kids/quiz` | Quiz UI | Error card | |
| Kids | Next question | No | — | Advances | — | |
| Kids | Save progress | Yes | `POST /kids/progress` | Saved | Error | |
| Subscription | Check entitlement | Yes | `GET /entitlements/me` | Shows tier | Error card | |
| Subscription | View plans | No | `GET /subscription/plans` | Plan list | Error card | |
| Subscription | Upgrade | Yes | `POST /payment/create-checkout-session` | Checkout URL or honest not configured | Error message | |
| Subscription | Refresh | Yes | Multiple | Reloads | Error | |
| Scholar review | Refresh status | Yes | `GET /api/sakina/review-status/{trace}` | Updated list | Error card | |
| Scholar review | Open answer | Yes | — | Shows scholar answer if available | — | |
| Scholar dashboard | Refresh queue | Scholar | `GET /scholar/queue` | Queue list | Honest partial screen | |
| Scholar dashboard | Submit review | Scholar | `POST /scholar-reviews/resolve` | Resolved status | Error snackbar | If API + role available |
| Admin | Refresh API health | No | `GET /health` | Health card updated | Error in card | |
| Admin | Check entitlement | Yes | `GET /entitlements/me` | Entitlement card | Error | |
| Admin | Grant test premium | Admin | `POST /admin/entitlements/grant` | Success message | 403 honest message | |
| Admin | Revoke test premium | Admin | `POST /admin/entitlements/revoke` | Success message | 403 honest message | |
| Admin | Open scholar queue | Scholar/Admin | `GET /scholar/queue` | Scholar dashboard | — | |
| Login required | Login | No | `POST /auth/login` | Returns to feature | Error | |
| Login required | Register | No | `POST /auth/register` | Returns to feature | Error | |
| Login required | Continue as guest | No | — | Pop screen | — | |
| Premium locked | View plans | No | `GET /subscription/plans` | Subscription screen | — | |
| Premium locked | Back home | No | — | Pop screen | — | |
| Not implemented | Back | No | — | Pop screen | — | Incomplete features only |

---

## APK build commands

**Emulator:**
```bash
cd sakina-frontend && flutter build apk --debug \
  --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1 \
  --dart-define=SAKINA_LOCAL_TEST=true \
  --dart-define=SAKINA_FEATURE_QURAN=true \
  --dart-define=SAKINA_FEATURE_PRAYER=true \
  --dart-define=SAKINA_FEATURE_KNOWLEDGE=true \
  --dart-define=SAKINA_FEATURE_COMMUNITY=true \
  --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

**Phone (replace LAN IP):**
```bash
cd sakina-frontend && flutter build apk --debug \
  --dart-define=SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1 \
  --dart-define=SAKINA_LOCAL_TEST=true \
  --dart-define=SAKINA_FEATURE_QURAN=true \
  --dart-define=SAKINA_FEATURE_PRAYER=true \
  --dart-define=SAKINA_FEATURE_KNOWLEDGE=true \
  --dart-define=SAKINA_FEATURE_COMMUNITY=true \
  --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

**Owner one-command (Windows):**
```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

---

## Phase 6H — luxury design + server feature gates

Mobile loads `GET /v1/features` on dashboard init. Each tile uses gate logic:

| State | User sees |
|-------|-----------|
| Free + enabled | Real feature screen |
| `requires_login` + guest | Login-required luxury card |
| `requires_premium` + no entitlement | Premium locked card |
| `coming_soon` | Coming soon card |
| `!enabled` | Disabled card |
| `maintenance_mode` | Maintenance card |
| `admin_only` / `scholar_only` | Hidden or access denied |

**25 admin-managed features:** ask_ai_shaikh, quran_reader, quran_search, tafsir, hadith, islamic_sources, dua_library, prayer_times, qibla, adhan_preferences, islamic_calendar, zakat, mirath, masjid_near_me, new_muslim_guide, wudu_guide, salah_guide, ramadan_guide, hajj_umrah_guide, halal_haram_guidance, scholar_review, bookmarks, reminders, kids_learning, subscription.

Design system: deep navy, emerald, gold, cream — `lib/design/` + `lib/widgets/luxury/`.
