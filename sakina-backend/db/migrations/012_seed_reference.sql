BEGIN;
INSERT INTO modules (code, title, summary)
VALUES
  ('quran-basics', 'Quran Basics', 'Foundational recitation and understanding.'),
  ('daily-dua', 'Daily Dua', 'Morning and evening supplications.'),
  ('iman-journey', 'Iman Journey', 'Guided personal growth track.')
ON CONFLICT (code) DO NOTHING;
COMMIT;
