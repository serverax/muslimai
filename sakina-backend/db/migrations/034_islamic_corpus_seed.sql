-- PHASE 3 seed: real, sourced Islamic corpus. Translations: Saheeh International.
-- Quran Arabic: Tanzil/Quran.com (Uthmani). Hadith: 40 Hadith an-Nawawi + Sahih collections.
-- Every row carries a source_reference. No unsourced content.
BEGIN;

-- ===================== Quran (5 full surahs, 25 ayahs) =====================
INSERT INTO sakina_ai.corpus_quran (surah_number, surah_name_en, surah_name_ar, ayah_number, text_arabic, translation_en, translation_source, source_reference) VALUES
(1,'Al-Fatihah','الفاتحة',1,'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ','In the name of Allah, the Entirely Merciful, the Especially Merciful.','Saheeh International','Quran 1:1 (Tanzil)'),
(1,'Al-Fatihah','الفاتحة',2,'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ','[All] praise is [due] to Allah, Lord of the worlds.','Saheeh International','Quran 1:2 (Tanzil)'),
(1,'Al-Fatihah','الفاتحة',3,'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ','The Entirely Merciful, the Especially Merciful,','Saheeh International','Quran 1:3 (Tanzil)'),
(1,'Al-Fatihah','الفاتحة',4,'مَٰلِكِ يَوْمِ ٱلدِّينِ','Sovereign of the Day of Recompense.','Saheeh International','Quran 1:4 (Tanzil)'),
(1,'Al-Fatihah','الفاتحة',5,'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ','It is You we worship and You we ask for help.','Saheeh International','Quran 1:5 (Tanzil)'),
(1,'Al-Fatihah','الفاتحة',6,'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ','Guide us to the straight path -','Saheeh International','Quran 1:6 (Tanzil)'),
(1,'Al-Fatihah','الفاتحة',7,'صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ','The path of those upon whom You have bestowed favor, not of those who have earned Your anger or of those who are astray.','Saheeh International','Quran 1:7 (Tanzil)'),
(108,'Al-Kawthar','الكوثر',1,'إِنَّآ أَعْطَيْنَٰكَ ٱلْكَوْثَرَ','Indeed, We have granted you, [O Muhammad], al-Kawthar.','Saheeh International','Quran 108:1 (Tanzil)'),
(108,'Al-Kawthar','الكوثر',2,'فَصَلِّ لِرَبِّكَ وَٱنْحَرْ','So pray to your Lord and sacrifice [to Him alone].','Saheeh International','Quran 108:2 (Tanzil)'),
(108,'Al-Kawthar','الكوثر',3,'إِنَّ شَانِئَكَ هُوَ ٱلْأَبْتَرُ','Indeed, your enemy is the one cut off.','Saheeh International','Quran 108:3 (Tanzil)'),
(112,'Al-Ikhlas','الإخلاص',1,'قُلْ هُوَ ٱللَّهُ أَحَدٌ','Say, "He is Allah, [who is] One,','Saheeh International','Quran 112:1 (Tanzil)'),
(112,'Al-Ikhlas','الإخلاص',2,'ٱللَّهُ ٱلصَّمَدُ','Allah, the Eternal Refuge.','Saheeh International','Quran 112:2 (Tanzil)'),
(112,'Al-Ikhlas','الإخلاص',3,'لَمْ يَلِدْ وَلَمْ يُولَدْ','He neither begets nor is born,','Saheeh International','Quran 112:3 (Tanzil)'),
(112,'Al-Ikhlas','الإخلاص',4,'وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ','Nor is there to Him any equivalent."','Saheeh International','Quran 112:4 (Tanzil)'),
(113,'Al-Falaq','الفلق',1,'قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ','Say, "I seek refuge in the Lord of daybreak,','Saheeh International','Quran 113:1 (Tanzil)'),
(113,'Al-Falaq','الفلق',2,'مِن شَرِّ مَا خَلَقَ','From the evil of that which He created,','Saheeh International','Quran 113:2 (Tanzil)'),
(113,'Al-Falaq','الفلق',3,'وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ','And from the evil of darkness when it settles,','Saheeh International','Quran 113:3 (Tanzil)'),
(113,'Al-Falaq','الفلق',4,'وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ','And from the evil of the blowers in knots,','Saheeh International','Quran 113:4 (Tanzil)'),
(113,'Al-Falaq','الفلق',5,'وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ','And from the evil of an envier when he envies."','Saheeh International','Quran 113:5 (Tanzil)'),
(114,'An-Nas','الناس',1,'قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ','Say, "I seek refuge in the Lord of mankind,','Saheeh International','Quran 114:1 (Tanzil)'),
(114,'An-Nas','الناس',2,'مَلِكِ ٱلنَّاسِ','The Sovereign of mankind.','Saheeh International','Quran 114:2 (Tanzil)'),
(114,'An-Nas','الناس',3,'إِلَٰهِ ٱلنَّاسِ','The God of mankind,','Saheeh International','Quran 114:3 (Tanzil)'),
(114,'An-Nas','الناس',4,'مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ','From the evil of the retreating whisperer -','Saheeh International','Quran 114:4 (Tanzil)'),
(114,'An-Nas','الناس',5,'ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ','Who whispers [evil] into the breasts of mankind -','Saheeh International','Quran 114:5 (Tanzil)'),
(114,'An-Nas','الناس',6,'مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ','From among the jinn and mankind."','Saheeh International','Quran 114:6 (Tanzil)')
ON CONFLICT (surah_number, ayah_number) DO NOTHING;

-- ===================== Tafsir (22 entries, Ibn Kathir summary) =====================
INSERT INTO sakina_ai.corpus_quran_tafsir (surah_number, ayah_number, tafsir_source, tafsir_text, source_reference) VALUES
(1,1,'Tafsir Ibn Kathir (summary)','The Basmalah opens the Quran; beginning affairs with Allah''s name seeking blessing. It affirms His mercy (Rahman, Rahim).','Ibn Kathir, Surah Al-Fatihah'),
(1,2,'Tafsir Ibn Kathir (summary)','All praise belongs to Allah, Lord and Sustainer of all creation (the worlds).','Ibn Kathir, Surah Al-Fatihah'),
(1,3,'Tafsir Ibn Kathir (summary)','Repetition of His mercy emphasises hope alongside the reminder of judgment in the next ayah.','Ibn Kathir, Surah Al-Fatihah'),
(1,4,'Tafsir Ibn Kathir (summary)','Allah is sole Owner of the Day of Recompense, when each soul is requited for its deeds.','Ibn Kathir, Surah Al-Fatihah'),
(1,5,'Tafsir Ibn Kathir (summary)','Worship and seeking help are devoted to Allah alone; the heart of tawhid.','Ibn Kathir, Surah Al-Fatihah'),
(1,6,'Tafsir Ibn Kathir (summary)','A plea for guidance to the straight path of Islam and steadfastness upon it.','Ibn Kathir, Surah Al-Fatihah'),
(1,7,'Tafsir Ibn Kathir (summary)','The path of the prophets and righteous, not those who knew the truth and abandoned it, nor those astray in ignorance.','Ibn Kathir, Surah Al-Fatihah'),
(112,1,'Tafsir Ibn Kathir (summary)','A declaration of Allah''s absolute oneness (Ahad), revealed in reply to those who asked about His nature.','Ibn Kathir, Surah Al-Ikhlas'),
(112,2,'Tafsir Ibn Kathir (summary)','As-Samad: the Eternal, Self-Sufficient Master upon whom all depend while He needs none.','Ibn Kathir, Surah Al-Ikhlas'),
(112,3,'Tafsir Ibn Kathir (summary)','He has no offspring and no parent; negating any claim of children or lineage to Him.','Ibn Kathir, Surah Al-Ikhlas'),
(112,4,'Tafsir Ibn Kathir (summary)','There is none comparable or equal to Him in any way.','Ibn Kathir, Surah Al-Ikhlas'),
(113,1,'Tafsir Ibn Kathir (summary)','Seeking refuge with the Lord of the daybreak, who splits the dawn from darkness.','Ibn Kathir, Surah Al-Falaq'),
(113,2,'Tafsir Ibn Kathir (summary)','From the evil of all created things capable of harm.','Ibn Kathir, Surah Al-Falaq'),
(113,3,'Tafsir Ibn Kathir (summary)','From the evil of the night when its darkness gathers.','Ibn Kathir, Surah Al-Falaq'),
(113,4,'Tafsir Ibn Kathir (summary)','From the evil of those who practise sorcery by blowing on knots.','Ibn Kathir, Surah Al-Falaq'),
(113,5,'Tafsir Ibn Kathir (summary)','From the harm of an envier when he acts upon his envy.','Ibn Kathir, Surah Al-Falaq'),
(114,1,'Tafsir Ibn Kathir (summary)','Seeking refuge with the Lord, Sovereign and God of mankind against the whisperer.','Ibn Kathir, Surah An-Nas'),
(114,4,'Tafsir Ibn Kathir (summary)','The retreating whisperer is Shaytan, who withdraws when Allah is remembered.','Ibn Kathir, Surah An-Nas'),
(114,5,'Tafsir Ibn Kathir (summary)','He casts whispers into the chests of people to provoke sin and doubt.','Ibn Kathir, Surah An-Nas'),
(114,6,'Tafsir Ibn Kathir (summary)','Such whisperers are found among both jinn and humans.','Ibn Kathir, Surah An-Nas'),
(108,1,'Tafsir Ibn Kathir (summary)','Al-Kawthar is abundant good, including a river in Paradise granted to the Prophet (peace be upon him).','Ibn Kathir, Surah Al-Kawthar'),
(108,2,'Tafsir Ibn Kathir (summary)','A command to devote prayer and sacrifice to Allah alone in gratitude.','Ibn Kathir, Surah Al-Kawthar')
ON CONFLICT DO NOTHING;

-- ===================== Hadith (50: an-Nawawi 40 + Sahih extras) =====================
INSERT INTO sakina_ai.corpus_hadith (collection, book, hadith_number, narrator, text_arabic, text_english, grading, source_reference, tags) VALUES
('40 Hadith an-Nawawi',NULL,'1','Umar ibn al-Khattab','إنَّما الأعمالُ بالنِّيَّاتِ','Actions are but by intentions, and every person will have only what they intended.','Sahih','Bukhari 1; Muslim 1907','intention niyyah'),
('40 Hadith an-Nawawi',NULL,'2','Umar ibn al-Khattab',NULL,'The hadith of Jibril: Islam, Iman and Ihsan are defined, and the signs of the Hour.','Sahih','Muslim 8','iman ihsan islam'),
('40 Hadith an-Nawawi',NULL,'3','Ibn Umar','بُنِيَ الإسلامُ على خَمسٍ','Islam is built upon five: testifying there is no god but Allah and Muhammad is His Messenger, establishing prayer, giving zakah, Hajj, and fasting Ramadan.','Sahih','Bukhari 8; Muslim 16','pillars'),
('40 Hadith an-Nawawi',NULL,'4','Ibn Masud',NULL,'The creation of each of you is gathered in the mother''s womb; the soul is breathed in and the provision, lifespan, deeds and final state are written.','Sahih','Bukhari 3208; Muslim 2643','qadar'),
('40 Hadith an-Nawawi',NULL,'5','Aisha','مَن أحدَثَ في أمرِنا هذا ما ليس منه فهو رَدٌّ','Whoever introduces into this matter of ours that which is not part of it, it is rejected.','Sahih','Bukhari 2697; Muslim 1718','bidah innovation'),
('40 Hadith an-Nawawi',NULL,'6','An-Nu''man ibn Bashir','الحلالُ بَيِّنٌ والحرامُ بَيِّنٌ','The lawful is clear and the unlawful is clear, and between them are doubtful matters.','Sahih','Bukhari 52; Muslim 1599','halal haram'),
('40 Hadith an-Nawawi',NULL,'7','Tamim ad-Dari','الدِّينُ النَّصيحةُ','The religion is sincere good counsel (nasihah).','Sahih','Muslim 55','sincerity'),
('40 Hadith an-Nawawi',NULL,'8','Ibn Umar',NULL,'I have been commanded to fight people until they testify to the shahadah, establish prayer and give zakah; then their blood and wealth are protected.','Sahih','Bukhari 25; Muslim 22','shahadah'),
('40 Hadith an-Nawawi',NULL,'9','Abu Hurayrah','ما نَهَيْتُكُم عنه فاجْتَنِبوه','What I have forbidden you, avoid; what I have commanded you, do as much as you can.','Sahih','Bukhari 7288; Muslim 1337','obedience'),
('40 Hadith an-Nawawi',NULL,'10','Abu Hurayrah','إنَّ اللهَ طَيِّبٌ لا يَقبَلُ إلا طَيِّبًا','Allah is Good and accepts only what is good; He commanded the believers as He commanded the messengers.','Sahih','Muslim 1015','provision purity'),
('40 Hadith an-Nawawi',NULL,'11','Al-Hasan ibn Ali','دَعْ ما يُريبُكَ إلى ما لا يُريبُكَ','Leave that which makes you doubt for that which does not make you doubt.','Sahih','Tirmidhi 2518 (sahih)','doubt scruple'),
('40 Hadith an-Nawawi',NULL,'12','Abu Hurayrah','مِن حُسنِ إسلامِ المرءِ تَرْكُهُ ما لا يَعنيه','Part of a person''s good Islam is leaving what does not concern him.','Hasan','Tirmidhi 2317 (hasan)','character'),
('40 Hadith an-Nawawi',NULL,'13','Anas ibn Malik','لا يُؤمِنُ أحدُكُم حتى يُحِبَّ لأخيهِ ما يُحِبُّ لِنَفسِه','None of you truly believes until he loves for his brother what he loves for himself.','Sahih','Bukhari 13; Muslim 45','brotherhood'),
('40 Hadith an-Nawawi',NULL,'14','Ibn Masud',NULL,'The blood of a Muslim is not lawful except in three cases: the married adulterer, a life for a life, and one who leaves the religion forsaking the community.','Sahih','Bukhari 6878; Muslim 1676','law'),
('40 Hadith an-Nawawi',NULL,'15','Abu Hurayrah','مَن كان يُؤمِنُ باللهِ واليومِ الآخِرِ فلْيَقُلْ خيرًا أو لِيَصْمُتْ','Whoever believes in Allah and the Last Day, let him speak good or remain silent; and honour his neighbour and guest.','Sahih','Bukhari 6018; Muslim 47','speech neighbour'),
('40 Hadith an-Nawawi',NULL,'16','Abu Hurayrah','لا تَغضَبْ','A man asked for advice; the Prophet said: Do not become angry. He repeated it several times.','Sahih','Bukhari 6116','anger'),
('40 Hadith an-Nawawi',NULL,'17','Shaddad ibn Aws','إنَّ اللهَ كَتَبَ الإحسانَ على كلِّ شيءٍ','Allah has prescribed excellence (ihsan) in all things; so when you slaughter, slaughter well.','Sahih','Muslim 1955','ihsan mercy'),
('40 Hadith an-Nawawi',NULL,'18','Abu Dharr / Mu''adh','اتَّقِ اللهَ حيثُما كنتَ','Fear Allah wherever you are, follow a bad deed with a good one to erase it, and treat people with good character.','Hasan','Tirmidhi 1987 (hasan)','taqwa character'),
('40 Hadith an-Nawawi',NULL,'19','Ibn Abbas','احْفَظِ اللهَ يَحْفَظْكَ','Be mindful of Allah and He will protect you; be mindful of Allah and you will find Him before you.','Hasan','Tirmidhi 2516 (hasan-sahih)','tawakkul'),
('40 Hadith an-Nawawi',NULL,'20','Abu Mas''ud al-Badri','إذا لم تَسْتَحِ فاصْنَعْ ما شِئتَ','If you feel no shame, then do as you wish (a teaching of the earlier prophets).','Sahih','Bukhari 3483','haya modesty'),
('40 Hadith an-Nawawi',NULL,'21','Sufyan ibn Abdullah','قُلْ آمَنتُ باللهِ ثم استَقِمْ','Say "I believe in Allah" and then be steadfast.','Sahih','Muslim 38','steadfastness'),
('40 Hadith an-Nawawi',NULL,'22','Jabir ibn Abdullah',NULL,'A man asked: if I pray the obligatory, fast Ramadan, treat the lawful as lawful and the unlawful as unlawful, will I enter Paradise? He said yes.','Sahih','Muslim 15','obligations'),
('40 Hadith an-Nawawi',NULL,'23','Abu Malik al-Ash''ari','الطُّهورُ شَطرُ الإيمانِ','Purity is half of faith; "Alhamdulillah" fills the scale; prayer is light; charity is proof.','Sahih','Muslim 223','purity worship'),
('40 Hadith an-Nawawi',NULL,'24','Abu Dharr','يا عِبادي إنّي حَرَّمْتُ الظُّلمَ على نفسي','Hadith Qudsi: O My servants, I have forbidden oppression for Myself and made it forbidden among you, so do not oppress one another.','Sahih','Muslim 2577','justice qudsi'),
('40 Hadith an-Nawawi',NULL,'25','Abu Hurayrah',NULL,'The wealthy took the rewards; the Prophet taught that tasbih, tahmid, takbir and charity are available to all.','Sahih','Muslim 1006','dhikr charity'),
('40 Hadith an-Nawawi',NULL,'26','Abu Hurayrah',NULL,'Every joint of a person owes charity each day; even a good word and removing harm from the road is charity.','Sahih','Bukhari 2989; Muslim 1009','charity'),
('40 Hadith an-Nawawi',NULL,'27','An-Nawwas ibn Sam''an','البِرُّ حُسنُ الخُلُقِ','Righteousness is good character, and sin is what wavers in your heart and you dislike people knowing.','Sahih','Muslim 2553','character sin'),
('40 Hadith an-Nawawi',NULL,'28','Al-Irbad ibn Sariyah','عليكم بسُنَّتي وسُنَّةِ الخُلَفاءِ الرّاشِدينَ','Hold to my Sunnah and the Sunnah of the rightly-guided caliphs; beware of newly-invented matters.','Sahih','Abu Dawud 4607; Tirmidhi 2676 (sahih)','sunnah'),
('40 Hadith an-Nawawi',NULL,'29','Mu''adh ibn Jabal',NULL,'Mu''adh asked about a deed to enter Paradise; the Prophet mentioned worship of Allah alone, prayer, zakah, fasting and Hajj, then the gates of good.','Sahih','Tirmidhi 2616 (hasan-sahih)','worship'),
('40 Hadith an-Nawawi',NULL,'30','Abu Tha''labah','إنَّ اللهَ فَرَضَ فَرائِضَ فلا تُضَيِّعوها','Allah has set obligations, so do not neglect them; set limits, so do not transgress them; and was silent about some things as mercy, not forgetfulness.','Hasan','Daraqutni (hasan)','limits'),
('40 Hadith an-Nawawi',NULL,'31','Sahl ibn Sa''d','ازْهَدْ في الدنيا يُحِبَّكَ اللهُ','Detach from the world and Allah will love you; detach from what people have and people will love you.','Hasan','Ibn Majah 4102 (hasan)','zuhd'),
('40 Hadith an-Nawawi',NULL,'32','Ibn Abbas / Sa''d','لا ضَرَرَ ولا ضِرارَ','There should be neither harming nor reciprocating harm.','Hasan','Ibn Majah 2341 (hasan)','no-harm'),
('40 Hadith an-Nawawi',NULL,'33','Ibn Abbas','لو يُعطى الناسُ بِدَعْواهُم','Were people given by their mere claims, men would claim others'' wealth and blood; rather the burden of proof is on the claimant and the oath on the one who denies.','Sahih','Bayhaqi (sahih)','evidence justice'),
('40 Hadith an-Nawawi',NULL,'34','Abu Sa''id al-Khudri','مَن رأى منكُم مُنكَرًا فلْيُغَيِّرْهُ بيَدِهِ','Whoever sees an evil, let him change it with his hand; if not able, then his tongue; if not, then his heart - and that is the weakest faith.','Sahih','Muslim 49','enjoining-good'),
('40 Hadith an-Nawawi',NULL,'35','Abu Hurayrah','لا تَحاسَدوا ولا تَناجَشوا','Do not envy one another, do not inflate prices, do not hate one another; be brothers, servants of Allah.','Sahih','Muslim 2564','brotherhood'),
('40 Hadith an-Nawawi',NULL,'36','Abu Hurayrah','مَن نَفَّسَ عن مؤمنٍ كُربةً','Whoever relieves a believer''s hardship, Allah will relieve his hardship on the Day of Resurrection; Allah aids a servant so long as he aids his brother.','Sahih','Muslim 2699','mercy knowledge'),
('40 Hadith an-Nawawi',NULL,'37','Ibn Abbas','إنَّ اللهَ كَتَبَ الحَسَناتِ والسَّيِّئاتِ','Hadith Qudsi: Allah recorded good and bad deeds; whoever intends a good deed but does not do it, Allah writes it as a full good deed.','Sahih','Bukhari 6491; Muslim 131','reward qudsi'),
('40 Hadith an-Nawawi',NULL,'38','Abu Hurayrah','مَن عادى لي وَلِيًّا فقد آذَنْتُهُ بالحربِ','Hadith Qudsi: Whoever shows enmity to a friend of Mine, I declare war on him; My servant draws near to Me by obligatory and voluntary acts until I love him.','Sahih','Bukhari 6502','wilayah qudsi'),
('40 Hadith an-Nawawi',NULL,'39','Ibn Abbas','إنَّ اللهَ تَجاوَزَ عن أمَّتي الخطأَ والنِّسيانَ','Allah has pardoned for my Ummah mistakes, forgetfulness, and what they are coerced to do.','Hasan','Ibn Majah 2045 (hasan)','mercy'),
('40 Hadith an-Nawawi',NULL,'40','Ibn Umar','كُنْ في الدنيا كأنَّكَ غَريبٌ','Be in this world as though a stranger or a wayfarer; if you reach evening do not expect morning.','Sahih','Bukhari 6416','zuhd'),
('40 Hadith an-Nawawi',NULL,'41','Abdullah ibn Amr',NULL,'None of you truly believes until his desires conform to what I have brought.','Hasan','an-Nawawi 40 #41 (hasan)','iman'),
('40 Hadith an-Nawawi',NULL,'42','Anas ibn Malik','يا ابنَ آدمَ إنَّكَ ما دَعَوْتَني ورَجَوْتَني غَفَرْتُ لكَ','Hadith Qudsi: O son of Adam, as long as you call upon Me and hope in Me, I forgive you; My forgiveness outweighs all sins.','Hasan','Tirmidhi 3540 (hasan)','forgiveness qudsi'),
('Sahih al-Bukhari','Book of Belief','9','Abu Hurayrah','الإيمانُ بِضْعٌ وسِتُّونَ شُعبةً','Faith has over seventy branches, the highest being "La ilaha illallah" and the lowest removing harm from the road; modesty is a branch of faith.','Sahih','Bukhari 9; Muslim 35','iman'),
('Sahih Muslim','Book of Faith','2564b','Abu Hurayrah','إنَّ اللهَ لا يَنظُرُ إلى صُوَرِكُم','Allah does not look at your forms and wealth, but He looks at your hearts and deeds.','Sahih','Muslim 2564','sincerity'),
('Sahih al-Bukhari','Good Manners','6114','Abu Hurayrah','ليس الشديدُ بالصُّرَعَةِ','The strong is not the one who overcomes people by strength, but the one who controls himself when angry.','Sahih','Bukhari 6114','self-control'),
('Sunan at-Tirmidhi','Chapters on Righteousness','1924','Abdullah ibn Amr','الرّاحِمونَ يَرحَمُهُمُ الرَّحمنُ','The merciful are shown mercy by the Most Merciful. Be merciful to those on earth and the One above the heaven will be merciful to you.','Sahih','Tirmidhi 1924 (sahih)','mercy'),
('Sahih al-Bukhari','Book of Knowledge','79','Abu Musa','مَثَلُ ما بَعَثَني اللهُ به','The guidance and knowledge with which Allah sent me is like abundant rain falling on land.','Sahih','Bukhari 79; Muslim 2282','knowledge'),
('Sahih Muslim','Remembrance','2699b','Abu Hurayrah','مَن سَلَكَ طريقًا يَلتَمِسُ فيه عِلمًا','Whoever follows a path seeking knowledge, Allah makes easy for him a path to Paradise.','Sahih','Muslim 2699','knowledge'),
('Sahih al-Bukhari','Book of Tawhid','7405','Abu Hurayrah','أنا عند ظَنِّ عبدي بي','Hadith Qudsi: I am as My servant thinks of Me, and I am with him when he remembers Me.','Sahih','Bukhari 7405; Muslim 2675','dhikr qudsi'),
('Sahih al-Bukhari','Good Manners','5985','Abu Hurayrah','مَن كان يُؤمِنُ باللهِ واليومِ الآخِرِ فلْيَصِلْ رَحِمَه','Whoever believes in Allah and the Last Day, let him maintain the ties of kinship.','Sahih','Bukhari 5985','kinship family')
ON CONFLICT DO NOTHING;

-- ===================== Islamic sources (10) =====================
INSERT INTO sakina_ai.corpus_islamic_sources (source_name, source_url, language, madhhab, category, trust_level, allowed_usage, restricted_usage, citation_format) VALUES
('Quran (Tanzil/Quran.com)','https://tanzil.net','ar/en',NULL,'quran','primary','Quranic text and verified translations','Do not alter Arabic text','Quran {surah}:{ayah}'),
('Sahih al-Bukhari','https://sunnah.com/bukhari','ar/en',NULL,'hadith','primary','Authentic hadith citation','Cite hadith number','Bukhari {number}'),
('Sahih Muslim','https://sunnah.com/muslim','ar/en',NULL,'hadith','primary','Authentic hadith citation','Cite hadith number','Muslim {number}'),
('Sunan Abi Dawud','https://sunnah.com/abudawud','ar/en',NULL,'hadith','secondary','Hadith with grading','Check grading before use as proof','Abu Dawud {number}'),
('Jami at-Tirmidhi','https://sunnah.com/tirmidhi','ar/en',NULL,'hadith','secondary','Hadith with grading','Check grading','Tirmidhi {number}'),
('Sunan an-Nasai','https://sunnah.com/nasai','ar/en',NULL,'hadith','secondary','Hadith with grading','Check grading','Nasai {number}'),
('Sunan Ibn Majah','https://sunnah.com/ibnmajah','ar/en',NULL,'hadith','secondary','Hadith with grading','Check grading','Ibn Majah {number}'),
('Tafsir Ibn Kathir','https://quran.com/tafsirs','ar/en',NULL,'tafsir','secondary','Classical exegesis reference','Summarise faithfully','Ibn Kathir, {surah}'),
('IslamQA','https://islamqa.info','ar/en','multiple','fatwa','reference','General fatwa reference','Not a substitute for a qualified local scholar on personal matters','IslamQA #{ref}'),
('Dar al-Ifta al-Misriyyah','https://dar-alifta.org','ar/en',NULL,'fatwa','reference','Official fatwa body reference','Verify applicability to the questioner','Dar al-Ifta {ref}')
ON CONFLICT (source_name) DO NOTHING;

-- ===================== Fatwa references (10) =====================
INSERT INTO sakina_ai.corpus_fatwa_refs (title, source_name, reference_url, topic, summary) VALUES
('Conditions of valid wudu','IslamQA','https://islamqa.info/en/answers/2031','purification','Obligatory acts and conditions of ablution.'),
('Rulings of Talaq (divorce)','Dar al-Ifta al-Misriyyah','https://dar-alifta.org','divorce','Divorce is serious and follows the Sunnah process; counselling is encouraged. High-risk; refer to a scholar.'),
('Zakat on savings','IslamQA','https://islamqa.info/en/answers/2795','zakat','Nisab thresholds and 2.5% on wealth held one lunar year.'),
('Inheritance shares (faraid)','Dar al-Ifta al-Misriyyah','https://dar-alifta.org','inheritance','Fixed Quranic shares; complex cases require a scholar.'),
('Combining and shortening prayers in travel','IslamQA','https://islamqa.info/en/answers/82898','prayer','Concessions for the traveller.'),
('Fasting rulings in Ramadan','IslamQA','https://islamqa.info/en/answers/12602','fasting','Who must fast, exemptions, and make-up.'),
('Permissibility of music','Dar al-Ifta al-Misriyyah','https://dar-alifta.org','conduct','Scholarly difference; refer to a qualified scholar for specifics.'),
('Repentance (tawbah) conditions','IslamQA','https://islamqa.info/en/answers/13990','repentance','Sincerity, stopping the sin, regret, resolve, and restoring rights.'),
('Rights of parents','IslamQA','https://islamqa.info/en/answers/5053','family','Obedience in good, kindness and supplication.'),
('Dealing with anxiety and grief','IslamQA','https://islamqa.info/en/answers/22704','wellbeing','Combining means and reliance on Allah; seek professional help for medical conditions.')
ON CONFLICT DO NOTHING;

-- ===================== Authenticity rules (10) =====================
INSERT INTO sakina_ai.source_authenticity_rules (rule_key, rule_text, severity) VALUES
('quran_requires_ref','A Quran citation must include surah and ayah numbers.','block'),
('hadith_requires_ref','A hadith citation must include the collection and hadith number or a clear reference.','block'),
('tafsir_requires_source','A tafsir citation must name its source.','block'),
('fatwa_requires_source','A fatwa citation must name its source and reference/URL where available.','block'),
('no_unsourced_legal','An Islamic legal/fatwa answer with no verified source must be blocked or escalated.','escalate'),
('weak_not_strong','Weak or unknown hadith must not be presented as strong proof.','warn'),
('contradiction_escalate','Contradictory source retrieval must trigger caution or escalation.','escalate'),
('high_risk_scholar','High-risk fatwa topics (divorce, takfir, etc.) must escalate to scholar review.','escalate'),
('no_llm_fabricated_citation','Citations must come from DB/RAG retrieval, never fabricated by the LLM.','block'),
('save_citation_result','Every Islamic answer must store its citation validation result.','warn')
ON CONFLICT (rule_key) DO NOTHING;

COMMIT;
