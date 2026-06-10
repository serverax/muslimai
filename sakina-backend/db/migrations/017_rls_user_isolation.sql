CREATE TABLE IF NOT EXISTS public.password_credentials (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    password_version TEXT NOT NULL DEFAULT 'argon2id-v1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
DECLARE
    tbl RECORD;
    user_id_type TEXT;
    policy_name TEXT;
BEGIN
    FOR tbl IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname IN ('public', 'sakina_ai', 'audit', 'outbox')
    LOOP
        EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', tbl.schemaname, tbl.tablename);
        EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', tbl.schemaname, tbl.tablename);

        policy_name := format('rls_%s_%s_service', tbl.schemaname, tbl.tablename);
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', policy_name, tbl.schemaname, tbl.tablename);
        EXECUTE format(
            'CREATE POLICY %I ON %I.%I FOR ALL USING (sakina_ai.rls_service_role()) WITH CHECK (sakina_ai.rls_service_role())',
            policy_name,
            tbl.schemaname,
            tbl.tablename
        );

        SELECT data_type
        INTO user_id_type
        FROM information_schema.columns
        WHERE table_schema = tbl.schemaname
          AND table_name = tbl.tablename
          AND column_name = 'user_id'
        LIMIT 1;

        IF user_id_type = 'uuid' THEN
            policy_name := format('rls_%s_%s_user_id', tbl.schemaname, tbl.tablename);
            EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', policy_name, tbl.schemaname, tbl.tablename);
            EXECUTE format(
                'CREATE POLICY %I ON %I.%I FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role()) WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())',
                policy_name,
                tbl.schemaname,
                tbl.tablename
            );
        ELSIF user_id_type IS NOT NULL THEN
            policy_name := format('rls_%s_%s_user_id_text', tbl.schemaname, tbl.tablename);
            EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', policy_name, tbl.schemaname, tbl.tablename);
            EXECUTE format(
                'CREATE POLICY %I ON %I.%I FOR ALL USING (user_id = sakina_ai.current_user_id()::text OR sakina_ai.rls_service_role()) WITH CHECK (user_id = sakina_ai.current_user_id()::text OR sakina_ai.rls_service_role())',
                policy_name,
                tbl.schemaname,
                tbl.tablename
            );
        END IF;
        user_id_type := NULL;
    END LOOP;
END $$;

DROP POLICY IF EXISTS rls_public_users_self ON public.users;
CREATE POLICY rls_public_users_self ON public.users
FOR ALL
USING (id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
WITH CHECK (id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

DROP POLICY IF EXISTS rls_public_password_credentials_self ON public.password_credentials;
CREATE POLICY rls_public_password_credentials_self ON public.password_credentials
FOR ALL
USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

DROP POLICY IF EXISTS rls_sakina_messages_conversation_owner ON sakina_ai.messages;
CREATE POLICY rls_sakina_messages_conversation_owner ON sakina_ai.messages
FOR ALL
USING (
    sakina_ai.rls_service_role()
    OR user_id = sakina_ai.current_user_id()
    OR EXISTS (
        SELECT 1
        FROM sakina_ai.conversations c
        WHERE c.id = conversation_id
          AND c.user_id = sakina_ai.current_user_id()
    )
)
WITH CHECK (
    sakina_ai.rls_service_role()
    OR user_id = sakina_ai.current_user_id()
    OR EXISTS (
        SELECT 1
        FROM sakina_ai.conversations c
        WHERE c.id = conversation_id
          AND c.user_id = sakina_ai.current_user_id()
    )
);

DO $$
BEGIN
    IF to_regclass('public.child_profiles') IS NOT NULL
       AND to_regclass('public.family_profiles') IS NOT NULL THEN
        DROP POLICY IF EXISTS rls_public_child_profiles_family_owner ON public.child_profiles;
        CREATE POLICY rls_public_child_profiles_family_owner ON public.child_profiles
        FOR ALL
        USING (
            sakina_ai.rls_service_role()
            OR user_id = sakina_ai.current_user_id()
            OR EXISTS (
                SELECT 1
                FROM public.family_profiles fp
                WHERE fp.id = family_profile_id
                  AND fp.user_id = sakina_ai.current_user_id()
            )
        )
        WITH CHECK (
            sakina_ai.rls_service_role()
            OR user_id = sakina_ai.current_user_id()
            OR EXISTS (
                SELECT 1
                FROM public.family_profiles fp
                WHERE fp.id = family_profile_id
                  AND fp.user_id = sakina_ai.current_user_id()
            )
        );
    END IF;

    IF to_regclass('public.notification_delivery_attempts') IS NOT NULL
       AND to_regclass('public.user_notifications') IS NOT NULL THEN
        DROP POLICY IF EXISTS rls_public_notification_delivery_attempts_owner ON public.notification_delivery_attempts;
        CREATE POLICY rls_public_notification_delivery_attempts_owner ON public.notification_delivery_attempts
        FOR ALL
        USING (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.user_notifications n
                WHERE n.id = user_notification_id
                  AND n.user_id = sakina_ai.current_user_id()
            )
        )
        WITH CHECK (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.user_notifications n
                WHERE n.id = user_notification_id
                  AND n.user_id = sakina_ai.current_user_id()
            )
        );
    END IF;

    IF to_regclass('public.support_ticket_messages') IS NOT NULL
       AND to_regclass('public.support_tickets') IS NOT NULL THEN
        DROP POLICY IF EXISTS rls_public_support_ticket_messages_owner ON public.support_ticket_messages;
        CREATE POLICY rls_public_support_ticket_messages_owner ON public.support_ticket_messages
        FOR ALL
        USING (
            sakina_ai.rls_service_role()
            OR sender_user_id = sakina_ai.current_user_id()
            OR EXISTS (
                SELECT 1
                FROM public.support_tickets t
                WHERE t.id = support_ticket_id
                  AND t.user_id = sakina_ai.current_user_id()
            )
        )
        WITH CHECK (
            sakina_ai.rls_service_role()
            OR sender_user_id = sakina_ai.current_user_id()
            OR EXISTS (
                SELECT 1
                FROM public.support_tickets t
                WHERE t.id = support_ticket_id
                  AND t.user_id = sakina_ai.current_user_id()
            )
        );
    END IF;

    IF to_regclass('public.payment_methods') IS NOT NULL
       AND to_regclass('public.payment_customers') IS NOT NULL THEN
        DROP POLICY IF EXISTS rls_public_payment_methods_customer_owner ON public.payment_methods;
        CREATE POLICY rls_public_payment_methods_customer_owner ON public.payment_methods
        FOR ALL
        USING (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.payment_customers c
                WHERE c.id = customer_id
                  AND c.user_id = sakina_ai.current_user_id()
            )
        )
        WITH CHECK (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.payment_customers c
                WHERE c.id = customer_id
                  AND c.user_id = sakina_ai.current_user_id()
            )
        );
    END IF;

    IF to_regclass('public.subscription_events') IS NOT NULL
       AND to_regclass('public.user_subscriptions') IS NOT NULL THEN
        DROP POLICY IF EXISTS rls_public_subscription_events_subscription_owner ON public.subscription_events;
        CREATE POLICY rls_public_subscription_events_subscription_owner ON public.subscription_events
        FOR ALL
        USING (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.user_subscriptions s
                WHERE s.id = user_subscription_id
                  AND s.user_id = sakina_ai.current_user_id()
            )
        )
        WITH CHECK (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.user_subscriptions s
                WHERE s.id = user_subscription_id
                  AND s.user_id = sakina_ai.current_user_id()
            )
        );
    END IF;

    IF to_regclass('public.refunds') IS NOT NULL
       AND to_regclass('public.payment_transactions') IS NOT NULL THEN
        DROP POLICY IF EXISTS rls_public_refunds_transaction_owner ON public.refunds;
        CREATE POLICY rls_public_refunds_transaction_owner ON public.refunds
        FOR ALL
        USING (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.payment_transactions tx
                WHERE tx.id = payment_transaction_id
                  AND tx.user_id = sakina_ai.current_user_id()
            )
        )
        WITH CHECK (
            sakina_ai.rls_service_role()
            OR EXISTS (
                SELECT 1
                FROM public.payment_transactions tx
                WHERE tx.id = payment_transaction_id
                  AND tx.user_id = sakina_ai.current_user_id()
            )
        );
    END IF;
END $$;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'payment_providers',
        'subscription_plans',
        'entitlements',
        'seo_pages',
        'seo_metadata',
        'landing_sections',
        'landing_feature_cards',
        'blog_posts',
        'faq_items',
        'legal_pages',
        'app_store_assets',
        'waitlist_entries',
        'notification_templates',
        'feature_flags',
        'module_status',
        'app_config',
        'release_flags',
        'maintenance_windows'
    ]
    LOOP
        IF to_regclass('public.' || tbl) IS NOT NULL THEN
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'rls_public_' || tbl || '_read', tbl);
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR SELECT USING (true)',
                'rls_public_' || tbl || '_read',
                tbl
            );
        END IF;
    END LOOP;
END $$;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'islamic_source_providers',
        'islamic_sources',
        'islamic_source_licences',
        'islamic_documents',
        'islamic_chunks',
        'islamic_embeddings',
        'knowledge_graph_entities',
        'knowledge_graph_edges'
    ]
    LOOP
        IF to_regclass('sakina_ai.' || tbl) IS NOT NULL THEN
            EXECUTE format('DROP POLICY IF EXISTS %I ON sakina_ai.%I', 'rls_sakina_ai_' || tbl || '_verified_read', tbl);
            EXECUTE format(
                'CREATE POLICY %I ON sakina_ai.%I FOR SELECT USING (true)',
                'rls_sakina_ai_' || tbl || '_verified_read',
                tbl
            );
        END IF;
    END LOOP;
END $$;
