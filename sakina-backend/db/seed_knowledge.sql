-- Seed data for Sakina Knowledge Tables
BEGIN;

-- 1. Quran Surahs
INSERT INTO sakina_ai.quran_surahs (surah_number, name_arabic, name_english, name_transliterated, revelation_type, total_ayahs)
VALUES 
(1, 'الفاتحة', 'The Opening', 'Al-Fatihah', 'Meccan', 7),
(112, 'الإخلاص', 'The Sincerity', 'Al-Ikhlas', 'Meccan', 4)
ON CONFLICT (surah_number) DO NOTHING;

-- 2. Quran Ayahs
INSERT INTO sakina_ai.quran_ayahs (surah_id, surah_number, ayah_number, juz_number, page_number, text_uthmani, text_imlaei_simple)
SELECT id, 1, 1, 1, 1, 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', 'بسم الله الرحمن الرحيم'
FROM sakina_ai.quran_surahs WHERE surah_number = 1
ON CONFLICT (surah_number, ayah_number) DO NOTHING;

-- 3. Tafsir Source
INSERT INTO sakina_ai.quran_tafsir_sources (source_key, name_english, author, language_code, licence_status)
VALUES ('ibn-kathir-en', 'Tafsir Ibn Kathir (English)', 'Ibn Kathir', 'en', 'public_domain')
ON CONFLICT (source_key) DO NOTHING;

-- 4. Tafsir Entry
INSERT INTO sakina_ai.quran_tafsir_entries (source_id, surah_number, ayah_number, ayah_range_start, ayah_range_end, tafsir_text, language)
SELECT id, 1, 1, 1, 1, 'Bismillah (In the Name of Allah) is the start of every good deed.', 'en'
FROM sakina_ai.quran_tafsir_sources WHERE source_key = 'ibn-kathir-en'
ON CONFLICT DO NOTHING;

-- 5. Hadith Collection
INSERT INTO sakina_ai.hadith_collections (collection_key, name_arabic, name_english, author, licence_status)
VALUES ('bukhari', 'صحيح البخاري', 'Sahih al-Bukhari', 'Imam Bukhari', 'public_domain')
ON CONFLICT (collection_key) DO NOTHING;

-- 6. Hadith Book
INSERT INTO sakina_ai.hadith_books (collection_id, book_number, name_arabic, name_english)
SELECT id, 1, 'كتاب الوحي', 'Book of Revelation'
FROM sakina_ai.hadith_collections WHERE collection_key = 'bukhari'
ON CONFLICT DO NOTHING;

-- 7. Hadith Narration
INSERT INTO sakina_ai.hadith_narrations (book_id, hadith_number, text_arabic, text_english)
SELECT b.id, '1', 'إنما الأعمال بالنيات', 'Actions are but by intentions'
FROM sakina_ai.hadith_books b
JOIN sakina_ai.hadith_collections c ON c.id = b.collection_id
WHERE c.collection_key = 'bukhari' AND b.book_number = 1
ON CONFLICT DO NOTHING;

COMMIT;
