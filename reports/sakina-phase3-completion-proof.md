# Sakina AI — PHASE 3 Completion Proof (Corpus + Citation Guard + RAG authenticity)

Date: 2026-06-23 · Branch: `qa-security-hardening` · Stack: local Docker (api :28080, real Postgres 15).
Image: `sakina-backend:latest` (build #10, id ed806e4632af). **No mocks, no fake PASS, Docker/local real services only.**
Evidence: `test-results/phase3-corpus-citation-rag-proof.md`.

## Changed files
Backend:
- `db/migrations/033_islamic_corpus.sql` (new) — corpus_quran, corpus_quran_tafsir, corpus_hadith, corpus_islamic_sources, corpus_fatwa_refs, source_authenticity_rules, answer_source_links, islamic_citation_checks, rag_retrieval_traces (RLS public-read + service).
- `db/migrations/034_islamic_corpus_seed.sql` (new) — sourced seed.
- `src/handlers/corpus.rs` (new) — 11 corpus endpoints + citation guard (`persist_citation_trace`, `classify_citation`).
- `src/handlers/mod.rs`, `src/main.rs` — module + /v1 routes.
- `src/handlers/sakina_ask.rs` — wired citation guard recording after trace persist.
- `src/bin/migrate.rs` — register 033/034.

Mobile:
- `lib/services/api_service.dart` — quranSurahs/quranSurah/quranSearch/quranTafsir/hadithCollections/hadithSearch/islamicSources.
- `lib/screens/quran_corpus_screen.dart` (new) — Quran reader/search + Surah view + Tafsir dialog + Hadith search (Arabic RTL, translation, grading, source).
- `lib/screens/daily_essentials_screen.dart` — Quran + Hadith tiles in the Daily hub (wired, not orphan).

## Migrations added / proof
Clean-DB `down -v` -> migrate = **36 migrations applied** (incl. 033, 034); init errors 0. No duplicate-broken IDs (033/034 unique). PHASE-3 tables exist (`answer_source_links`, `islamic_citation_checks`, `rag_retrieval_traces` resolve). Indexes on surah/collection/trace_id. Seeded rows present (below). Seed is static SQL - no runtime remote-API dependency.

## API routes added (/v1)
`/quran/surahs`, `/quran/surah/{n}`, `/quran/ayah/{s}/{a}`, `/quran/search`, `/quran/tafsir/{s}/{a}`, `/hadith/collections`, `/hadith/search`, `/hadith/{collection}/{number}`, `/islamic-sources`, `/fatwa/search`, `/citation-check`.

## Seed counts (DB)
quran ayahs 25 (5 surahs) · tafsir 22 · hadith 50 · sources 10 · fatwa refs 10 · authenticity rules 10. Every row carries a source_reference (0 missing).

## PHASE 3 endpoint PASS/FAIL
| Item | Evidence | Result |
|---|---|---|
| Quran corpus count | 25 ayahs / 5 surahs | PASS |
| Hadith corpus count | 50 | PASS |
| Tafsir corpus count | 22 | PASS |
| Source registry count | 10 | PASS |
| Quran read (surah/ayah) | surah 112->4 ayahs; ayah 1:1 source `Quran 1:1 (Tanzil)` | PASS |
| Quran search | `refuge`->3 (first 112:2); `Lord`->4 | PASS |
| Tafsir read | 1:1 -> `Ibn Kathir, Surah Al-Fatihah` | PASS |
| Hadith collections | 4 | PASS |
| Hadith search | `intention`->1 (`Bukhari 1; Muslim 1907`) | PASS |
| Sources endpoint | 10 | PASS |
| Fatwa search | `divorce`->1 | PASS |
| Citation guard - valid | wudu ask -> cited; citation-check `result=valid count=1 links=1` | PASS |
| Citation guard - blocked | fabricated-ritual ask -> `CAVEATED_SHORT_CIRCUIT`, 0 citations; citation-check `result=blocked` | PASS |
| Citation guard - escalated | fatwa ask -> `ESCALATED_TO_HUMAN`; citation-check `result=escalated` | PASS |
| Citation-check trace lookup | returns check + source_links | PASS |
| DB trace tables populated | citation_checks=2, answer_source_links=1, rag_retrieval_traces=2 | PASS |
| Weak-not-strong rule present | seeded | PASS |
| Mobile corpus API wiring exercised | `/v1/quran/*`,`/v1/hadith/*`,`/v1/islamic-sources` all 200 | PASS |

## Regression PASS/FAIL (Phase 1 / 1B / 2)
| Item | Result |
|---|---|
| Auth login | PASS (200) |
| Ask Shaikh safe + grounded citation | PASS (wudu, Quran citation) |
| High-risk fatwa escalates to scholar | PASS (ESCALATED_TO_HUMAN + queue) |
| Scholar queue + resolve | PASS (200/200) |
| User review-status loop | PASS (scholar_answered) |
| Dua library endpoint | PASS (32; search forgive->6) |
| Bookmarks create/list + anon block | PASS (create ok, list 1, anon 401) |
| Bookmarks/reminders tables present | PASS |
| Prayer times (Phase 2) | PASS (London fajr 03:41) |

## Mobile proof
flutter analyze: **No issues found**. flutter build apk --debug: **success**.
APK: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk` - **175.8 MB**.
PHASE 3 screens wired into the Daily hub (Quran, Hadith) - not orphan. Screens use ApiService methods (real backend), no static content.

## Known limitations
- Corpus is a proof-scale seed (5 surahs / 50 hadith / 22 tafsir), not the full world corpus (by design this phase).
- RAG retrieval for the ask answer still uses the existing hybrid/local engine; the new `rag_retrieval_traces` records the citation-derived retrieval. Vector RAG over the corpus_* tables is a later enhancement.
- On-device visual runtime of corpus screens = PHASE 9 (APK builds; endpoints proven).
- `hadith/{collection}/{number}` uses ILIKE collection match (handles URL-encoded collection names with spaces).

## Commands used (key)
`docker build -f sakina-backend/Dockerfile -t sakina-backend:latest .` (#10) ·
`docker compose -f sakina-infra/docker-compose.qa.yml --env-file .env down -v / up / run --rm api sakina-migrate` (->36) ·
curl `/v1/quran/*`, `/v1/hadith/*`, `/v1/islamic-sources`, `/v1/fatwa/search`, `/v1/citation-check`, `/api/sakina/ask` ·
psql corpus counts + trace tables · `flutter analyze` · `flutter build apk --debug`.

## Verdict: PHASE 3 = PASS (Docker/local command-proven). Overall project verdict remains PARTIAL_READY (not LIVE_READY).
