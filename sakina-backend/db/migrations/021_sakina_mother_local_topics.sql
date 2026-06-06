CREATE TABLE IF NOT EXISTS sakina_ai.local_sunni_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_key TEXT NOT NULL,
    language TEXT NOT NULL,
    section TEXT NOT NULL,
    intent TEXT NOT NULL,
    title TEXT NOT NULL,
    answer TEXT NOT NULL,
    citations JSONB NOT NULL DEFAULT '[]'::jsonb,
    next_steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    source_status TEXT NOT NULL DEFAULT 'local_verified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (topic_key, language)
);

CREATE TABLE IF NOT EXISTS sakina_ai.anonymous_learning_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    language TEXT NOT NULL,
    intent TEXT NOT NULL,
    section TEXT NOT NULL,
    pii_removed BOOLEAN NOT NULL DEFAULT FALSE,
    safe_pattern TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.ask_shaikh_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
    workspace_id UUID NULL REFERENCES sakina_ai.workspaces(id) ON DELETE SET NULL,
    language TEXT NOT NULL,
    intent TEXT NOT NULL,
    question_redacted TEXT NOT NULL,
    answer TEXT NOT NULL,
    citations JSONB NOT NULL DEFAULT '[]'::jsonb,
    source_path JSONB NOT NULL DEFAULT '{}'::jsonb,
    safety JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sakina_ai.scholar_review_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL,
    mastermind_decision_id UUID NULL,
    conversation_id UUID NULL,
    priority TEXT NOT NULL DEFAULT 'normal',
    review_status TEXT NOT NULL DEFAULT 'pending',
    assigned_reviewer TEXT NULL,
    approved_by TEXT NULL,
    approved_at TIMESTAMPTZ NULL,
    reviewer_notes TEXT NULL,
    due_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_local_sunni_topics_topic_language
    ON sakina_ai.local_sunni_topics (topic_key, language);
CREATE INDEX IF NOT EXISTS idx_anonymous_learning_events_trace
    ON sakina_ai.anonymous_learning_events (trace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_anonymous_learning_events_intent_language
    ON sakina_ai.anonymous_learning_events (intent, language, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ask_shaikh_answers_trace
    ON sakina_ai.ask_shaikh_answers (trace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ask_shaikh_answers_user_workspace
    ON sakina_ai.ask_shaikh_answers (user_id, workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scholar_review_queue_status
    ON sakina_ai.scholar_review_queue (review_status, priority, created_at DESC);

INSERT INTO sakina_ai.local_sunni_topics (
    topic_key, language, section, intent, title, answer, citations, next_steps
)
VALUES
(
    'wudu', 'en', 'prayer_and_wudu_help', 'wudu',
    'How to make wudu',
    'Begin with the intention to purify yourself for prayer. Wash the hands, rinse the mouth and nose, wash the face, wash the arms to the elbows, wipe the head, and wash the feet to the ankles. If you are unsure, review the steps calmly and ask a trusted local teacher for practical correction.',
    '[{"id":"quran:5:6","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"Quran 5:6","author":"Tanzil Project","chapter":"Al-Ma''idah 5:6","ayah":"5:6","authenticity_grade":"high"}]'::jsonb,
    '["Practice the steps slowly before prayer","Ask a trusted teacher to check your wudu if you are new"]'::jsonb
),
(
    'wudu', 'ar', 'prayer_and_wudu_help', 'wudu',
    'صفة الوضوء',
    'ابدأ بنية الطهارة للصلاة، ثم اغسل اليدين، وتمضمض واستنشق، واغسل الوجه، ثم اليدين إلى المرفقين، وامسح الرأس، واغسل القدمين إلى الكعبين. إن كنت جديدًا فتعلّم الخطوات بهدوء واسأل معلّمًا موثوقًا للتطبيق العملي.',
    '[{"id":"quran:5:6","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"القرآن 5:6","author":"Tanzil Project","chapter":"المائدة 5:6","ayah":"5:6","authenticity_grade":"high"}]'::jsonb,
    '["تدرّب على الخطوات بهدوء قبل الصلاة","اسأل معلّمًا موثوقًا إن كنت جديدًا"]'::jsonb
),
(
    'salah', 'en', 'prayer_and_wudu_help', 'salah',
    'First steps in salah',
    'Salah is learned step by step. Start by learning the prayer times, wudu, and the opening words. Keep the prayer simple while you learn, and ask a trusted local teacher for details such as posture and recitation.',
    '[{"id":"quran:2:43","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"Quran 2:43","author":"Tanzil Project","chapter":"Al-Baqarah 2:43","ayah":"2:43","authenticity_grade":"high"}]'::jsonb,
    '["Learn one prayer at a time","Use a beginner prayer guide from a trusted mosque"]'::jsonb
),
(
    'salah', 'ar', 'prayer_and_wudu_help', 'salah',
    'الخطوات الأولى في الصلاة',
    'تُتعلّم الصلاة خطوة خطوة. ابدأ بمعرفة الأوقات والوضوء وتكبيرة الإحرام، واجعل التعلم هادئًا متدرجًا، واسأل معلّمًا موثوقًا عن الهيئات والقراءة.',
    '[{"id":"quran:2:43","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"القرآن 2:43","author":"Tanzil Project","chapter":"البقرة 2:43","ayah":"2:43","authenticity_grade":"high"}]'::jsonb,
    '["تعلّم صلاة واحدة في البداية","استعن بدليل مبتدئين من مسجد موثوق"]'::jsonb
),
(
    'shahadah', 'en', 'new_muslim_journey', 'new_muslim',
    'The shahadah',
    'The shahadah is the testimony that there is no god worthy of worship except Allah and that Muhammad is the Messenger of Allah. For a new Muslim, the next steps are gentle: learn purification, prayer, and basic belief at a steady pace.',
    '[{"id":"quran:47:19","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"Quran 47:19","author":"Tanzil Project","chapter":"Muhammad 47:19","ayah":"47:19","authenticity_grade":"high"}]'::jsonb,
    '["Learn wudu","Learn the daily prayers gradually","Connect with a trusted mosque or teacher"]'::jsonb
),
(
    'shahadah', 'ar', 'new_muslim_journey', 'new_muslim',
    'الشهادة',
    'الشهادة هي أن لا إله إلا الله وأن محمدًا رسول الله. وللمسلم الجديد تكون الخطوات التالية برفق: تعلّم الطهارة والصلاة وأصول الإيمان بالتدرج.',
    '[{"id":"quran:47:19","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"القرآن 47:19","author":"Tanzil Project","chapter":"محمد 47:19","ayah":"47:19","authenticity_grade":"high"}]'::jsonb,
    '["تعلّم الوضوء","تعلّم الصلاة تدريجيًا","تواصل مع مسجد أو معلّم موثوق"]'::jsonb
),
(
    'basic_dua', 'en', 'daily_dua', 'dua',
    'A simple daily dua',
    'A gentle daily dua is: “Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.” Say it calmly and remember that dua is a direct call to Allah.',
    '[{"id":"quran:2:201","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"Quran 2:201","author":"Tanzil Project","chapter":"Al-Baqarah 2:201","ayah":"2:201","authenticity_grade":"high"}]'::jsonb,
    '["Repeat it after prayer","Learn the meaning before memorising more"]'::jsonb
),
(
    'basic_dua', 'ar', 'daily_dua', 'dua',
    'دعاء يومي بسيط',
    'من الدعاء الجامع: ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار. قلها بهدوء وتذكر أن الدعاء مناجاة مباشرة لله.',
    '[{"id":"quran:2:201","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"القرآن 2:201","author":"Tanzil Project","chapter":"البقرة 2:201","ayah":"2:201","authenticity_grade":"high"}]'::jsonb,
    '["كرّرها بعد الصلاة","افهم المعنى قبل حفظ أدعية أكثر"]'::jsonb
),
(
    'new_muslim_first_steps', 'en', 'new_muslim_journey', 'new_muslim',
    'New Muslim first steps',
    'Take one gentle step at a time. Hold firmly to tawhid, learn wudu and salah gradually, keep company with trustworthy Muslims, and do not overload yourself. Allah knows your effort.',
    '[{"id":"quran:2:286","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"Quran 2:286","author":"Tanzil Project","chapter":"Al-Baqarah 2:286","ayah":"2:286","authenticity_grade":"high"}]'::jsonb,
    '["Learn wudu","Learn one short surah","Find a trusted local mosque or teacher"]'::jsonb
),
(
    'new_muslim_first_steps', 'ar', 'new_muslim_journey', 'new_muslim',
    'خطوات المسلم الجديد',
    'خذ الأمر خطوة برفق. اثبت على التوحيد، وتعلّم الوضوء والصلاة تدريجيًا، وصاحب مسلمين موثوقين، ولا تُثقل على نفسك. والله يعلم جهدك.',
    '[{"id":"quran:2:286","api_source":"Tanzil Project verified Quran text","source_type":"quran","book":"Quran","title":"القرآن 2:286","author":"Tanzil Project","chapter":"البقرة 2:286","ayah":"2:286","authenticity_grade":"high"}]'::jsonb,
    '["تعلّم الوضوء","احفظ سورة قصيرة","ابحث عن مسجد أو معلّم موثوق"]'::jsonb
)
ON CONFLICT (topic_key, language) DO UPDATE SET
    section = EXCLUDED.section,
    intent = EXCLUDED.intent,
    title = EXCLUDED.title,
    answer = EXCLUDED.answer,
    citations = EXCLUDED.citations,
    next_steps = EXCLUDED.next_steps,
    updated_at = NOW();

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'local_sunni_topics',
        'anonymous_learning_events',
        'ask_shaikh_answers',
        'scholar_review_queue'
    ]
    LOOP
        EXECUTE format('ALTER TABLE sakina_ai.%I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('ALTER TABLE sakina_ai.%I FORCE ROW LEVEL SECURITY', tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I ON sakina_ai.%I', 'rls_sakina_ai_' || tbl || '_service', tbl);
        EXECUTE format(
            'CREATE POLICY %I ON sakina_ai.%I FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role())',
            'rls_sakina_ai_' || tbl || '_service',
            tbl
        );
    END LOOP;
END $$;

DROP POLICY IF EXISTS rls_sakina_ai_ask_shaikh_answers_user
    ON sakina_ai.ask_shaikh_answers;
CREATE POLICY rls_sakina_ai_ask_shaikh_answers_user
    ON sakina_ai.ask_shaikh_answers
    FOR ALL
    USING (
        user_id = sakina_ai.current_user_id()
        OR sakina_ai.rls_service_role()
    )
    WITH CHECK (
        user_id = sakina_ai.current_user_id()
        OR sakina_ai.rls_service_role()
    );
