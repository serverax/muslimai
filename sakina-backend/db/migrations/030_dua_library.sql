-- PHASE 2: Dua library. Public read. Seeded with authentic, sourced supplications.
BEGIN;

CREATE TABLE IF NOT EXISTS sakina_ai.duas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    arabic TEXT NOT NULL,
    transliteration TEXT,
    translation TEXT NOT NULL,
    source TEXT NOT NULL,
    tags TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_duas_category ON sakina_ai.duas (category);

ALTER TABLE sakina_ai.duas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS duas_public_read ON sakina_ai.duas;
CREATE POLICY duas_public_read ON sakina_ai.duas FOR SELECT USING (true);
DROP POLICY IF EXISTS duas_service ON sakina_ai.duas;
CREATE POLICY duas_service ON sakina_ai.duas
    FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role());

INSERT INTO sakina_ai.duas (category, title, arabic, transliteration, translation, source, tags) VALUES
('morning','Morning remembrance','أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ','Asbahna wa asbahal-mulku lillah','We have entered the morning and the dominion belongs to Allah.','Sahih Muslim 2723','morning adhkar remembrance'),
('morning','Seeking a good day','اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا','Allahumma bika asbahna wa bika amsayna','O Allah, by You we enter the morning and by You we enter the evening.','Sunan Abi Dawud 5068 (hasan)','morning evening'),
('morning','Sayyid al-Istighfar','اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ','Allahumma anta Rabbi la ilaha illa anta','O Allah, You are my Lord, there is no god but You.','Sahih al-Bukhari 6306','morning forgiveness istighfar'),
('evening','Evening remembrance','أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ','Amsayna wa amsal-mulku lillah','We have entered the evening and the dominion belongs to Allah.','Sahih Muslim 2723','evening adhkar'),
('evening','Refuge in Allah''s words','أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ','A''udhu bi-kalimatillahit-tammati min sharri ma khalaq','I seek refuge in the perfect words of Allah from the evil He created.','Sahih Muslim 2708','evening protection'),
('before_sleep','Before sleeping','بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا','Bismika Allahumma amutu wa ahya','In Your name, O Allah, I die and I live.','Sahih al-Bukhari 6324','sleep night'),
('before_sleep','Entrusting the soul','اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ','Allahumma aslamtu nafsi ilayk','O Allah, I submit my soul to You.','Sahih al-Bukhari 247','sleep night trust'),
('before_sleep','Ayat al-Kursi at night','اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ','Allahu la ilaha illa huwal-Hayyul-Qayyum','Allah! There is no god but He, the Living, the Self-Sustaining.','Quran 2:255; Sahih al-Bukhari 2311','sleep protection quran'),
('after_prayer','Istighfar after salah','أَسْتَغْفِرُ اللَّهَ (ثلاثاً)','Astaghfirullah (x3)','I seek forgiveness of Allah (three times).','Sahih Muslim 591','after-prayer forgiveness'),
('after_prayer','Peace and blessings','اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ','Allahumma antas-Salam wa minkas-salam','O Allah, You are Peace and from You is peace.','Sahih Muslim 591','after-prayer'),
('after_prayer','Help in remembrance','اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ','Allahumma a''inni ala dhikrika wa shukrika wa husni ibadatik','O Allah, help me to remember You, thank You, and worship You well.','Sunan Abi Dawud 1522 (sahih)','after-prayer worship'),
('protection','Al-Ikhlas and Mu''awwidhatayn','قُلْ هُوَ اللَّهُ أَحَدٌ','Qul huwa Allahu ahad','Say: He is Allah, the One. (with al-Falaq and an-Nas)','Quran 112-114; Sunan at-Tirmidhi 3575','protection refuge'),
('protection','Protection from harm','بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ','Bismillahil-ladhi la yadurru ma''as-mihi shay''','In the name of Allah, with whose name nothing can cause harm.','Sunan Abi Dawud 5088 (sahih)','protection morning evening'),
('protection','Refuge from evil','اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ','Allahumma inni a''udhu bika minal-khubthi wal-khaba''ith','O Allah, I seek refuge in You from evil and evil-doers.','Sahih al-Bukhari 142','protection restroom'),
('forgiveness','Comprehensive forgiveness','رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ','Rabbi-ghfir li wa tub alayya','My Lord, forgive me and accept my repentance.','Sunan at-Tirmidhi 3434 (sahih)','forgiveness repentance'),
('forgiveness','Forgiveness of sins','اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ','Allahumma-ghfir li dhanbi kullahu','O Allah, forgive me all my sins, small and great.','Sahih Muslim 483','forgiveness'),
('forgiveness','Quranic plea','رَبَّنَا ظَلَمْنَا أَنْفُسَنَا','Rabbana zalamna anfusana','Our Lord, we have wronged ourselves.','Quran 7:23','forgiveness repentance quran'),
('anxiety','Relief from worry','اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ','Allahumma inni a''udhu bika minal-hammi wal-hazan','O Allah, I seek refuge in You from anxiety and grief.','Sahih al-Bukhari 6369','anxiety sadness grief'),
('anxiety','Hasbunallah','حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ','Hasbunallahu wa ni''mal-wakil','Allah is sufficient for us, and He is the best disposer of affairs.','Quran 3:173; Sahih al-Bukhari 4563','anxiety trust reliance'),
('anxiety','Dua of distress','لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ','La ilaha illallahul-Azimul-Halim','There is no god but Allah, the Mighty, the Forbearing.','Sahih al-Bukhari 6346','anxiety distress'),
('anxiety','Yunus''s dua','لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ','La ilaha illa anta subhanaka inni kuntu minaz-zalimin','There is no god but You, glory be to You, I was among the wrongdoers.','Quran 21:87; Sunan at-Tirmidhi 3505','anxiety distress quran'),
('travel','Dua for travel','سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا','Subhanal-ladhi sakhkhara lana hadha','Glory to Him who has subjected this to us.','Quran 43:13; Sahih Muslim 1342','travel journey'),
('travel','Protection on a journey','اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى','Allahumma inna nas''aluka fi safarina hadhal-birra wat-taqwa','O Allah, we ask You on this journey for righteousness and piety.','Sahih Muslim 1342','travel journey'),
('travel','Entering a town','اللَّهُمَّ بَارِكْ لَنَا فِيهَا','Allahumma barik lana fiha','O Allah, bless it for us.','Sunan an-Nasa''i (hasan)','travel arrival'),
('food','Before eating','بِسْمِ اللَّهِ','Bismillah','In the name of Allah.','Sunan Abi Dawud 3767 (sahih)','food eating'),
('food','After eating','الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا','Alhamdu lillahil-ladhi at''amani hadha','Praise be to Allah who fed me this.','Sunan at-Tirmidhi 3458 (hasan)','food gratitude'),
('food','When forgetting bismillah','بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ','Bismillahi awwalahu wa akhirahu','In the name of Allah, at its beginning and its end.','Sunan Abi Dawud 3767 (sahih)','food eating'),
('parents_family','Mercy for parents','رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا','Rabbi-rhamhuma kama rabbayani saghira','My Lord, have mercy on them as they raised me when I was small.','Quran 17:24','parents family mercy'),
('parents_family','Righteous family','رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ','Rabbana hab lana min azwajina wa dhurriyyatina qurrata a''yun','Our Lord, grant us from our spouses and offspring comfort to our eyes.','Quran 25:74','family spouse children'),
('parents_family','Forgiveness for believers','رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ','Rabbana-ghfir li wa li-walidayya wa lil-mu''minin','Our Lord, forgive me, my parents, and the believers.','Quran 14:41','parents family forgiveness'),
('morning','Pleased with Allah','رَضِيتُ بِاللَّهِ رَبًّا وَبِالْإِسْلَامِ دِينًا','Raditu billahi Rabban wa bil-Islami dina','I am pleased with Allah as Lord and Islam as religion.','Sunan Abi Dawud 5072 (hasan)','morning evening contentment'),
('protection','Tasbih of protection','سُبْحَانَ اللَّهِ وَبِحَمْدِهِ (مائة مرة)','Subhanallahi wa bihamdihi (x100)','Glory and praise be to Allah (one hundred times).','Sahih al-Bukhari 6405','protection reward')
ON CONFLICT DO NOTHING;

COMMIT;
