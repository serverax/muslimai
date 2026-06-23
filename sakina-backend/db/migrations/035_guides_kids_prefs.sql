-- PHASE 4: guides (public, sourced), kids learning/quiz (public read; progress login),
-- and user preferences (login). Does not alter Phases 1-3 tables.
BEGIN;

CREATE TABLE IF NOT EXISTS sakina_ai.guides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    body TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.kids_lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    age_band TEXT NOT NULL DEFAULT '5-9',
    body TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.kids_quiz (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_index INTEGER NOT NULL,
    explanation TEXT NOT NULL,
    source_reference TEXT NOT NULL,
    age_band TEXT NOT NULL DEFAULT '5-9',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sakina_ai.kids_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    activity TEXT NOT NULL,
    score INTEGER NOT NULL DEFAULT 0,
    total INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_kids_progress_user ON sakina_ai.kids_progress (user_id);

CREATE TABLE IF NOT EXISTS sakina_ai.user_preferences_kv (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    pref_key TEXT NOT NULL,
    pref_value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, pref_key)
);
CREATE INDEX IF NOT EXISTS idx_user_prefs_kv_user ON sakina_ai.user_preferences_kv (user_id);

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['guides','kids_lessons','kids_quiz','kids_progress','user_preferences_kv'] LOOP
    EXECUTE format('ALTER TABLE sakina_ai.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I_service ON sakina_ai.%I', t, t);
    EXECUTE format('CREATE POLICY %I_service ON sakina_ai.%I FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role())', t, t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['guides','kids_lessons','kids_quiz'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_public ON sakina_ai.%I', t, t);
    EXECUTE format('CREATE POLICY %I_public ON sakina_ai.%I FOR SELECT USING (true)', t, t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['kids_progress','user_preferences_kv'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_self ON sakina_ai.%I', t, t);
    EXECUTE format('CREATE POLICY %I_self ON sakina_ai.%I FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role()) WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())', t, t);
  END LOOP;
END $$;

INSERT INTO sakina_ai.guides (slug, title, category, body, source_reference) VALUES
('wudu','How to perform Wudu','purification',
 E'1. Make the intention (niyyah) to purify yourself.\n2. Say Bismillah and wash both hands to the wrists three times.\n3. Rinse the mouth three times.\n4. Rinse the nose three times.\n5. Wash the face three times.\n6. Wash the right then left arm up to the elbow three times.\n7. Wipe the head once with wet hands, and wipe the ears.\n8. Wash the right then left foot up to the ankles three times.',
 'Quran 5:6; Sahih al-Bukhari 159; Sahih Muslim 235'),
('salah','How to pray (basic Salah)','prayer',
 E'1. Ensure purification (wudu) and face the qiblah.\n2. Make the intention for the specific prayer.\n3. Raise hands and say "Allahu Akbar" (takbir).\n4. Recite Surah Al-Fatihah, then another surah/portion.\n5. Bow (ruku) saying "Subhana Rabbiyal-Adheem".\n6. Stand up saying "Sami Allahu liman hamidah, Rabbana lakal-hamd".\n7. Prostrate (sujud) twice saying "Subhana Rabbiyal-Ala".\n8. Complete the rakats, then the final tashahhud and salam to the right and left.',
 'Sahih al-Bukhari 757; general fiqh of salah'),
('ramadan','Fasting in Ramadan','fasting',
 E'1. Fasting Ramadan is obligatory on every able, adult Muslim.\n2. Make the intention to fast before Fajr.\n3. Take suhoor (pre-dawn meal); it is blessed.\n4. Abstain from food, drink, and marital relations from Fajr until Maghrib.\n5. Break the fast (iftar) at Maghrib, traditionally with dates and water.\n6. The sick and the traveller may break the fast and make up the days later.',
 'Quran 2:183-185; Sahih al-Bukhari 1923'),
('hajj-umrah','Hajj and Umrah overview','pilgrimage',
 E'Umrah: 1. Enter ihram at the miqat with the intention.\n2. Perform tawaf (seven circuits) of the Kaaba.\n3. Pray two rakats at Maqam Ibrahim.\n4. Perform sai between Safa and Marwah seven times.\n5. Shave or trim the hair.\nHajj (Dhul Hijjah): ihram, day at Mina, standing at Arafah (9th), Muzdalifah, stoning at Jamarat, sacrifice, tawaf al-ifadah, and farewell tawaf.',
 'Quran 2:196-203; Sahih Muslim 1218'),
('new-muslim','New Muslim first steps','foundation',
 E'1. Declare the shahadah: "Ash-hadu an la ilaha illallah, wa ash-hadu anna Muhammadan rasulullah".\n2. Learn to perform wudu and the five daily prayers.\n3. Learn Surah Al-Fatihah and a few short surahs.\n4. Take it step by step; Allah does not burden a soul beyond its capacity.\n5. Seek knowledge from trusted, qualified teachers and a local community.\n6. Be patient and consistent; small steady deeds are most beloved.',
 'Quran 2:286; Sahih al-Bukhari 6464')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO sakina_ai.kids_quiz (question, options, correct_index, explanation, source_reference) VALUES
('How many daily prayers do Muslims pray?','["3","5","7","2"]'::jsonb,1,'Muslims pray five daily prayers: Fajr, Dhuhr, Asr, Maghrib and Isha.','Islamic basics; Bukhari 8'),
('What is the first surah of the Quran?','["Al-Ikhlas","An-Nas","Al-Fatihah","Al-Baqarah"]'::jsonb,2,'Al-Fatihah is the opening surah of the Quran.','Quran, Surah 1'),
('How many rakats are in the Fajr prayer?','["2","3","4","1"]'::jsonb,0,'Fajr has two obligatory rakats.','Fiqh of salah'),
('What do we say before eating?','["Alhamdulillah","Bismillah","Subhanallah","Astaghfirullah"]'::jsonb,1,'We say Bismillah before eating.','Abu Dawud 3767'),
('In which month do Muslims fast?','["Shaban","Rajab","Ramadan","Shawwal"]'::jsonb,2,'Muslims fast in the month of Ramadan.','Quran 2:185'),
('Which direction do Muslims face in prayer?','["North","The Kaaba (Qiblah)","East","The sunrise"]'::jsonb,1,'Muslims face the Kaaba in Makkah, called the qiblah.','Quran 2:144'),
('Who is the final Prophet in Islam?','["Musa","Isa","Muhammad","Ibrahim"]'::jsonb,2,'Prophet Muhammad (peace be upon him) is the final messenger.','Quran 33:40'),
('What is the holy book of Islam?','["The Torah","The Quran","The Gospel","The Psalms"]'::jsonb,1,'The Quran is the final revealed book of Islam.','Quran 15:9')
ON CONFLICT DO NOTHING;

INSERT INTO sakina_ai.kids_lessons (title, age_band, body, source_reference) VALUES
('The Five Pillars','5-9','Islam has five pillars: Shahadah (faith), Salah (prayer), Zakah (charity), Sawm (fasting Ramadan), and Hajj (pilgrimage).','Sahih al-Bukhari 8'),
('Good Manners (Akhlaq)','5-9','A Muslim is kind, honest, and gentle. The Prophet (peace be upon him) said the best of you are those best in character.','Sahih al-Bukhari 3559')
ON CONFLICT DO NOTHING;

COMMIT;
