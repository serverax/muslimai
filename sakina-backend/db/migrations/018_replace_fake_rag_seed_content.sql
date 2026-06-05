BEGIN;

DELETE FROM sakina_ai.islamic_chunks c
USING sakina_ai.islamic_documents d, sakina_ai.islamic_sources s
WHERE c.document_id = d.id
  AND d.source_id = s.id
  AND (
    c.chunk_text = 'verified chunk text'
    OR c.citation_text = 'verified citation'
    OR s.title = 'Verified Source'
  );

DELETE FROM sakina_ai.islamic_documents d
USING sakina_ai.islamic_sources s
WHERE d.source_id = s.id
  AND s.title = 'Verified Source';

DELETE FROM sakina_ai.islamic_sources
WHERE title = 'Verified Source';

WITH source_row AS (
    INSERT INTO sakina_ai.islamic_sources (
        source_key, source_type, source_status, language, title, review_status
    )
    VALUES (
        'quran-reference-guidance-en',
        'quran',
        'approved',
        'en',
        'Quran Reference Guidance',
        'verified'
    )
    ON CONFLICT (source_key) DO UPDATE SET
        source_status = EXCLUDED.source_status,
        review_status = EXCLUDED.review_status,
        title = EXCLUDED.title
    RETURNING id
),
document_row AS (
    INSERT INTO sakina_ai.islamic_documents (
        source_id, document_key, title, source_type, language, source_status, review_status
    )
    SELECT id, 'quran-reference-guidance-en-v1', 'Quran Reference Guidance Starter Corpus', 'quran', 'en', 'approved', 'verified'
    FROM source_row
    ON CONFLICT (document_key) DO UPDATE SET
        source_status = EXCLUDED.source_status,
        review_status = EXCLUDED.review_status,
        title = EXCLUDED.title
    RETURNING id
),
starter_chunks(chunk_key, chunk_index, chunk_text, citation_text) AS (
    VALUES
    ('quran-001-001-007-guidance', 0, 'Al-Fatihah is the opening chapter of the Quran and centers worship, reliance, and asking Allah for guidance to the straight path.', 'Quran 1:1-7'),
    ('quran-002-201-dua', 1, 'Quran 2:201 records a supplication asking Allah for good in this world, good in the Hereafter, and protection from the punishment of the Fire.', 'Quran 2:201'),
    ('quran-002-286-capacity', 2, 'Quran 2:286 teaches that Allah does not burden a soul beyond what it can bear and includes supplication for pardon, forgiveness, and mercy.', 'Quran 2:286'),
    ('quran-016-090-justice', 3, 'Quran 16:90 commands justice, excellence, and giving to relatives, and forbids immorality, bad conduct, and oppression.', 'Quran 16:90'),
    ('quran-049-013-humanity', 4, 'Quran 49:13 teaches that people are made into nations and tribes so they may know one another, and that nobility is tied to taqwa.', 'Quran 49:13'),
    ('quran-094-005-006-ease', 5, 'Quran 94:5-6 reassures believers that with hardship comes ease.', 'Quran 94:5-6'),
    ('quran-103-001-003-time', 6, 'Surah Al-Asr teaches that humankind is in loss except those who believe, do righteous deeds, counsel truth, and counsel patience.', 'Quran 103:1-3'),
    ('quran-112-001-004-tawhid', 7, 'Surah Al-Ikhlas summarizes tawhid by affirming Allah as One, the Eternal Refuge, unlike creation, and without equal.', 'Quran 112:1-4'),
    ('quran-113-001-005-protection', 8, 'Surah Al-Falaq teaches seeking refuge in Allah from harms including darkness, malicious practices, and envy.', 'Quran 113:1-5'),
    ('quran-114-001-006-refuge', 9, 'Surah An-Nas teaches seeking refuge in Allah, Lord and King of mankind, from the whispering evil that affects hearts.', 'Quran 114:1-6'),
    ('quran-002-183-fasting', 10, 'Quran 2:183 establishes fasting as an obligation for believers and connects fasting with taqwa.', 'Quran 2:183'),
    ('quran-002-184-illness-travel', 11, 'Quran 2:184 mentions allowances around fasting for a limited number of days and references concession for illness or travel with later make-up days.', 'Quran 2:184')
)
INSERT INTO sakina_ai.islamic_chunks (
    document_id, chunk_key, chunk_index, chunk_text, citation_text,
    source_type, language, source_status, review_status
)
SELECT document_row.id, starter_chunks.chunk_key, starter_chunks.chunk_index, starter_chunks.chunk_text,
       starter_chunks.citation_text, 'quran', 'en', 'approved', 'verified'
FROM document_row, starter_chunks
ON CONFLICT (chunk_key) DO UPDATE SET
    chunk_text = EXCLUDED.chunk_text,
    citation_text = EXCLUDED.citation_text,
    source_status = EXCLUDED.source_status,
    review_status = EXCLUDED.review_status;

COMMIT;
