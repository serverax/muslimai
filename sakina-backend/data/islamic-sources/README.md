# Rahma — Islamic source data (governance directory)

This directory holds **manifest** files that describe Islamic sources the
operator may eventually ingest. It does **not** contain copyrighted bulk
content (no full Quran text, no full Hadith collections, no fatwa text).

## What lives here

- `manifest.example.json` — schema example, not for ingestion.
- `starter-categories.json` — the seven Arabic top-level categories used by
  the library + RAG layer.
- `sample-manifest.test.json` — **TEST DATA ONLY** (clearly labelled,
  `verification_status: pending_review`, fictional non-religious copy).
- `REVIEW_POLICY.md` — operator-side rules for promoting a source to
  `verification_status: approved`.

## What does NOT live here

- Full Quran or Hadith text.
- Any religious content without a clear source reference.
- Any content awaiting copyright/licensing review.
- Real reviewer email addresses (use email-hash references instead).

## Pipeline

1. Operator writes a manifest entry (or imports from a reviewed source pack).
2. `scripts/rag/validate-source-manifest.js <file>` runs in dry-run by
   default — it validates schema, Arabic fields, source_reference presence,
   and duplicate detection. It writes nothing.
3. Operator inspects the dry-run report.
4. Only after explicit `--apply` AND a real `DATABASE_URL`, the ingestion
   script (`scripts/rag/ingest-source-manifest.js`) writes rows into
   `islamic_source_registry` with `verification_status='pending_review'`.
5. A reviewer signs the entry into `verification_status='approved'`.
6. Only `approved` sources are visible to public retrieval / library.

## Hard rules

- No item promoted to `approved` without a `reviewer_email_hash`.
- No item with `verification_status=approved` may have an empty
  `source_reference`.
- No item with `verification_status=approved` may have an empty Arabic body.
- Duplicate detection is by SHA-256 of `(source_type, title_ar, source_reference)`.
- `--apply` is refused without `DATABASE_URL`.
