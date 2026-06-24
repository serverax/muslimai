-- PHASE 6H/6I: mobile app feature flags — idempotent on fresh and existing DB.
BEGIN;

CREATE TABLE IF NOT EXISTS public.app_feature_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_key TEXT NOT NULL UNIQUE,
    title_en TEXT NOT NULL,
    title_ar TEXT NOT NULL,
    description_en TEXT NOT NULL DEFAULT '',
    description_ar TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'general',
    icon_key TEXT NOT NULL DEFAULT 'apps',
    enabled BOOLEAN NOT NULL DEFAULT true,
    requires_login BOOLEAN NOT NULL DEFAULT false,
    requires_premium BOOLEAN NOT NULL DEFAULT false,
    admin_only BOOLEAN NOT NULL DEFAULT false,
    scholar_only BOOLEAN NOT NULL DEFAULT false,
    coming_soon BOOLEAN NOT NULL DEFAULT false,
    maintenance_mode BOOLEAN NOT NULL DEFAULT false,
    display_order INTEGER NOT NULL DEFAULT 0,
    app_store_visible BOOLEAN NOT NULL DEFAULT true,
    local_test_visible BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_feature_flags_order
    ON public.app_feature_flags (display_order, feature_key);

ALTER TABLE public.app_feature_flags ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'app_feature_flags'
          AND policyname = 'app_feature_flags_read'
    ) THEN
        CREATE POLICY app_feature_flags_read ON public.app_feature_flags
            FOR SELECT USING (true);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'app_feature_flags'
          AND policyname = 'app_feature_flags_service'
    ) THEN
        CREATE POLICY app_feature_flags_service ON public.app_feature_flags
            FOR ALL USING (sakina_ai.rls_service_role())
            WITH CHECK (sakina_ai.rls_service_role());
    END IF;
END $$;

INSERT INTO public.app_feature_flags (
    feature_key, title_en, title_ar, description_en, description_ar,
    category, icon_key, enabled, requires_login, requires_premium,
    admin_only, scholar_only, coming_soon, maintenance_mode, display_order
) VALUES
('ask_ai_shaikh', 'Ask AI Shaikh', 'اسأل الشيخ الذكي',
 'Islamic learning guidance with cited sources.', 'إرشاد إسلامي تعليمي مع مصادر موثقة.',
 'guidance', 'chat', true, true, false, false, false, false, false, 1),
('quran_reader', 'Quran Reader', 'قارئ القرآن',
 'Read the Quran with translation support.', 'اقرأ القرآن مع دعم الترجمة.',
 'study', 'menu_book', true, false, false, false, false, false, false, 2),
('quran_search', 'Quran Search', 'بحث القرآن',
 'Search verses across the Quran.', 'ابحث في آيات القرآن.',
 'study', 'search', true, false, false, false, false, false, false, 3),
('tafsir', 'Tafsir', 'تفسير',
 'Commentary and explanation of verses.', 'تفسير وشرح الآيات.',
 'study', 'auto_stories', true, false, true, false, false, false, false, 4),
('hadith', 'Hadith', 'حديث',
 'Browse authenticated hadith collections.', 'تصفح كتب الحديث الموثقة.',
 'study', 'library_books', true, false, false, false, false, false, false, 5),
('islamic_sources', 'Islamic Sources', 'مصادر إسلامية',
 'Verified knowledge sources and citations.', 'مصادر معرفة موثقة ومراجع.',
 'study', 'source', true, false, false, false, false, false, false, 6),
('dua_library', 'Dua Library', 'مكتبة الأدعية',
 'Search and save duas for daily life.', 'ابحث واحفظ الأدعية اليومية.',
 'daily', 'wb_twilight', true, false, false, false, false, false, false, 7),
('prayer_times', 'Prayer Times', 'أوقات الصلاة',
 'Salah times for your location.', 'أوقات الصلاة حسب موقعك.',
 'daily', 'access_time', true, false, false, false, false, false, false, 8),
('qibla', 'Qibla', 'القبلة',
 'Find the Qibla direction.', 'اعرف اتجاه القبلة.',
 'daily', 'explore', true, false, false, false, false, false, false, 9),
('adhan_preferences', 'Adhan Preferences', 'تفضيلات الأذان',
 'Customize adhan and prayer alerts.', 'خصص الأذان وتنبيهات الصلاة.',
 'daily', 'notifications_active', true, true, false, false, false, false, false, 10),
('islamic_calendar', 'Islamic Calendar', 'التقويم الهجري',
 'Hijri dates and Islamic events.', 'التواريخ الهجرية والمناسبات.',
 'daily', 'calendar_month', true, false, false, false, false, false, false, 11),
('zakat', 'Zakat Calculator', 'حاسبة الزكاة',
 'Estimate zakat on your assets.', 'احسب زكاة أموالك.',
 'tools', 'calculate', true, false, false, false, false, false, false, 12),
('mirath', 'Mirath Calculator', 'حاسبة الميراث',
 'Islamic inheritance distribution guide.', 'دليل توزيع الميراث الإسلامي.',
 'tools', 'family_restroom', true, false, false, false, false, false, false, 13),
('masjid_near_me', 'Masjid Near Me', 'مسجد قريب',
 'Find nearby masjids.', 'اعثر على المساجد القريبة.',
 'community', 'mosque', true, false, false, false, false, true, false, 14),
('new_muslim_guide', 'New Muslim Guide', 'دليل المسلم الجديد',
 'Step-by-step guidance for new Muslims.', 'إرشاد تدريجي للمسلمين الجدد.',
 'guides', 'favorite', true, false, false, false, false, false, false, 15),
('wudu_guide', 'Wudu Guide', 'دليل الوضوء',
 'How to perform wudu correctly.', 'كيفية الوضوء الصحيح.',
 'guides', 'water_drop', true, false, false, false, false, false, false, 16),
('salah_guide', 'Salah Guide', 'دليل الصلاة',
 'How to pray step by step.', 'كيفية الصلاة خطوة بخطوة.',
 'guides', 'self_improvement', true, false, false, false, false, false, false, 17),
('ramadan_guide', 'Ramadan Guide', 'دليل رمضان',
 'Fasting, taraweeh, and Ramadan essentials.', 'الصيام والتراويح وأساسيات رمضان.',
 'guides', 'nightlight', true, false, false, false, false, false, false, 18),
('hajj_umrah_guide', 'Hajj & Umrah Guide', 'دليل الحج والعمرة',
 'Rites and preparation for Hajj and Umrah.', 'مناسك وتحضير الحج والعمرة.',
 'guides', 'flight', true, false, false, false, false, false, false, 19),
('halal_haram_guidance', 'Halal & Haram Guidance', 'إرشاد الحلال والحرام',
 'General guidance on halal and haram matters.', 'إرشاد عام في أمور الحلال والحرام.',
 'guidance', 'gavel', true, true, false, false, false, false, false, 20),
('scholar_review', 'Scholar Review', 'مراجعة العلماء',
 'Submit questions for qualified scholar review.', 'أرسل أسئلة لمراجعة عالم مؤهل.',
 'guidance', 'school', true, true, false, false, false, false, false, 21),
('bookmarks', 'Bookmarks', 'المفضلة',
 'Save verses, duas, and study notes.', 'احفظ الآيات والأدعية والملاحظات.',
 'personal', 'bookmark', true, true, false, false, false, false, false, 22),
('reminders', 'Reminders', 'التذكيرات',
 'Prayer and study reminders.', 'تذكيرات الصلاة والدراسة.',
 'personal', 'alarm', true, true, false, false, false, false, false, 23),
('kids_learning', 'Kids Learning', 'تعليم الأطفال',
 'Islamic lessons and quizzes for children.', 'دروس واختبارات إسلامية للأطفال.',
 'family', 'child_care', true, true, false, false, false, false, false, 24),
('subscription', 'Subscription', 'الاشتراك',
 'Plans, entitlements, and premium access.', 'الخطط والصلاحيات والوصول المميز.',
 'account', 'workspace_premium', true, true, false, false, false, false, false, 25)
ON CONFLICT (feature_key) DO NOTHING;

COMMIT;
