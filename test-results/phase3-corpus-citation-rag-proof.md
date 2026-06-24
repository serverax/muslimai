# PHASE 3 — Corpus + Citation Guard + RAG proof (Tue Jun 23 02:49:56 UTC 2026)
No mocks, no fake PASS, Docker/local real services only.
```
=== clean rebuild on final image ed806e4632af ===
init errors: 0
Sakina migrations applied: 36
api: healthy | services: 5

=== corpus counts (DB) + PHASE3 tables exist ===
 quran    |    25
 tafsir   |    22
 hadith   |    50
 sources  |    10
 fatwa    |    10
 rules    |    10

 sakina_ai.answer_source_links | sakina_ai.islamic_citation_checks | sakina_ai.rag_retrieval_traces


=== corpus endpoints ===
quran surahs: 5
quran surah 112: 4 ayahs
quran ayah 1:1: Quran 1:1 (Tanzil)
quran search 'mercy': 0
tafsir 1:1: Ibn Kathir, Surah Al-Fatihah
hadith collections: 4
hadith search 'intention': 1 | top: Bukhari 1; Muslim 1907
islamic-sources: 10
fatwa search 'divorce': 1

=== CITATION GUARD ===
-- valid: safe wudu ask --
wudu safety_state=ALLOWED_WITH_GUARDRAILS cited=True trace=6977720b-560e-47d7-9a3d-1eb2b3620c85
citation-check(wudu): result=valid count=1 links=1
-- blocked/escalated: high-risk fatwa --
fatwa safety_state=ESCALATED_TO_HUMAN trace=35a31211-a342-48ce-bc92-509f65095379
citation-check(fatwa): result=escalated
DB citation_checks rows: 2
DB answer_source_links rows: 1
DB rag_retrieval_traces rows: 2

=== REGRESSION (Phase 1/1B/2) ===
login: 200
scholar queue: 200  resolve: 200
user review-status: scholar_answered
dua list: 32  dua search forgive: 6
bookmark create: ok  list: 1  anon: 401
reminders tables: sakina_ai.reminders | sakina_ai.bookmarks
prayer-times London: 03:41 fajr
```

## Supplement: positive Quran search + blocked citation
```
quran search 'refuge': 3 | first: Quran 112:2 (Tanzil)
quran search 'Lord': 4 hits
-- fabricated-ritual question (blocked, uncited) --
blocked ask safety_state=CAVEATED_SHORT_CIRCUIT citations=0
citation-check(blocked): result=blocked reason=answer blocked / insufficient verified citations
weak-vs-strong rule present: Weak or unknown hadith must not be presented as strong proof.
```
