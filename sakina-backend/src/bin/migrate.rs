use sqlx::PgPool;

fn env_value(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn database_url() -> Result<String, String> {
    if let Some(url) = env_value("DATABASE_URL") {
        return Ok(url);
    }

    let host = env_value("POSTGRES_HOST").ok_or("POSTGRES_HOST is required")?;
    let port = env_value("POSTGRES_PORT").unwrap_or_else(|| "5432".to_string());
    let db = env_value("POSTGRES_DB").ok_or("POSTGRES_DB is required")?;
    let user = env_value("POSTGRES_USER").ok_or("POSTGRES_USER is required")?;
    let password = env_value("POSTGRES_PASSWORD").ok_or("POSTGRES_PASSWORD is required")?;

    Ok(format!(
        "postgres://{}:{}@{}:{}/{}",
        user, password, host, port, db
    ))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let url = database_url().map_err(|message| format!("database config error: {message}"))?;
    let pool = PgPool::connect(&url).await?;

    let migrations = [
        (
            "001_init_extensions.sql",
            include_str!("../../db/migrations/001_init_extensions.sql"),
        ),
        (
            "002_users_profiles.sql",
            include_str!("../../db/migrations/002_users_profiles.sql"),
        ),
        (
            "003_modules_content.sql",
            include_str!("../../db/migrations/003_modules_content.sql"),
        ),
        (
            "004_user_progress.sql",
            include_str!("../../db/migrations/004_user_progress.sql"),
        ),
        (
            "005_chat_threads_messages.sql",
            include_str!("../../db/migrations/005_chat_threads_messages.sql"),
        ),
        (
            "006_sync_state.sql",
            include_str!("../../db/migrations/006_sync_state.sql"),
        ),
        (
            "007_rag_documents_chunks.sql",
            include_str!("../../db/migrations/007_rag_documents_chunks.sql"),
        ),
        (
            "008_rag_embeddings.sql",
            include_str!("../../db/migrations/008_rag_embeddings.sql"),
        ),
        (
            "009_notifications.sql",
            include_str!("../../db/migrations/009_notifications.sql"),
        ),
        (
            "010_admin_core.sql",
            include_str!("../../db/migrations/010_admin_core.sql"),
        ),
        (
            "010_admin_audit.sql",
            include_str!("../../db/migrations/010_admin_audit.sql"),
        ),
        (
            "011_indexes_perf.sql",
            include_str!("../../db/migrations/011_indexes_perf.sql"),
        ),
        (
            "012_seed_reference.sql",
            include_str!("../../db/migrations/012_seed_reference.sql"),
        ),
        (
            "013_waitlist.sql",
            include_str!("../../db/migrations/013_waitlist.sql"),
        ),
        (
            "014_brain_knowledge_graph.sql",
            include_str!("../../db/migrations/014_brain_knowledge_graph.sql"),
        ),
        (
            "015_user_memory_multimodal.sql",
            include_str!("../../db/migrations/015_user_memory_multimodal.sql"),
        ),
        (
            "016_password_auth.sql",
            include_str!("../../db/migrations/016_password_auth.sql"),
        ),
        (
            "017_rls_user_isolation.sql",
            include_str!("../../db/migrations/017_rls_user_isolation.sql"),
        ),
        (
            "018_replace_fake_rag_seed_content.sql",
            include_str!("../../db/migrations/018_replace_fake_rag_seed_content.sql"),
        ),
        (
            "019_agent_feedback.sql",
            include_str!("../../db/migrations/019_agent_feedback.sql"),
        ),
        (
            "020_workspace_learning_core.sql",
            include_str!("../../db/migrations/020_workspace_learning_core.sql"),
        ),
        (
            "021_sakina_mother_local_topics.sql",
            include_str!("../../db/migrations/021_sakina_mother_local_topics.sql"),
        ),
        (
            "022_sakina_phase4_quran_tafsir.sql",
            include_str!("../../db/migrations/022_sakina_phase4_quran_tafsir.sql"),
        ),
        (
            "023_sakina_phase5_hadith_fatwa_learning.sql",
            include_str!("../../db/migrations/023_sakina_phase5_hadith_fatwa_learning.sql"),
        ),
        (
            "024_sakina_phase6_safety_and_subscriptions.sql",
            include_str!("../../db/migrations/024_sakina_phase6_safety_and_subscriptions.sql"),
        ),
        (
            "025_scholar_resolution.sql",
            include_str!("../../db/migrations/025_scholar_resolution.sql"),
        ),
        (
            "026_entitlements_fix.sql",
            include_str!("../../db/migrations/026_entitlements_fix.sql"),
        ),
        (
            "027_scholar_accounts.sql",
            include_str!("../../db/migrations/027_scholar_accounts.sql"),
        ),
        (
            "028_safety_classifications.sql",
            include_str!("../../db/migrations/028_safety_classifications.sql"),
        ),
        (
            "029_subscriptions.sql",
            include_str!("../../db/migrations/029_subscriptions.sql"),
        ),
        (
            "030_dua_library.sql",
            include_str!("../../db/migrations/030_dua_library.sql"),
        ),
        (
            "031_bookmarks.sql",
            include_str!("../../db/migrations/031_bookmarks.sql"),
        ),
        (
            "032_reminders.sql",
            include_str!("../../db/migrations/032_reminders.sql"),
        ),
        (
            "033_islamic_corpus.sql",
            include_str!("../../db/migrations/033_islamic_corpus.sql"),
        ),
        (
            "034_islamic_corpus_seed.sql",
            include_str!("../../db/migrations/034_islamic_corpus_seed.sql"),
        ),
        (
            "035_guides_kids_prefs.sql",
            include_str!("../../db/migrations/035_guides_kids_prefs.sql"),
        ),
        (
            "036_subscriptions_phase5.sql",
            include_str!("../../db/migrations/036_subscriptions_phase5.sql"),
        ),
        (
            "037_app_feature_flags.sql",
            include_str!("../../db/migrations/037_app_feature_flags.sql"),
        ),
        (
            "038_local_admin_owner_seed.sql",
            include_str!("../../db/migrations/038_local_admin_owner_seed.sql"),
        ),
        (
            "seed_knowledge.sql",
            include_str!("../../db/seed_knowledge.sql"),
        ),
    ];

    if std::env::var("SAKINA_SEED_LOCAL_ADMIN")
        .map(|v| matches!(v.to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
    {
        println!("Local admin seed enabled (SAKINA_SEED_LOCAL_ADMIN=true)");
    }

    for (name, sql) in migrations {
        println!("Applying Sakina migration {name}");
        let mut conn = pool.acquire().await?;
        let result = sqlx::raw_sql(sql).execute(&mut *conn).await;
        if let Err(ref e) = result {
            let _ = sqlx::query("ROLLBACK").execute(&mut *conn).await;
        }
        match result {
            Ok(_) => {}
            Err(e) if is_idempotent_migration_error(&e) => {
                eprintln!("WARN: migration {name} skipped (already applied): {e}");
            }
            Err(e) => return Err(e.into()),
        }
    }

    if std::env::var("SAKINA_SEED_LOCAL_ADMIN")
        .map(|v| matches!(v.to_ascii_lowercase().as_str(), "1" | "true" | "yes"))
        .unwrap_or(false)
    {
        seed_local_admin(&pool).await?;
    }

    let unprotected_tables: Vec<(String, String)> = sqlx::query_as(
        r#"
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname IN ('public','sakina_ai','audit','outbox')
          AND rowsecurity = false
        ORDER BY schemaname, tablename
        "#,
    )
    .fetch_all(&pool)
    .await?;

    if !unprotected_tables.is_empty() {
        eprintln!("Sakina migration RLS verification failed; unprotected tables remain:");
        for (schema, table) in unprotected_tables {
            eprintln!("{schema}.{table}");
        }
        return Err("Sakina migration RLS verification failed".into());
    }

    println!("Sakina migrations applied: {}", migrations.len());
    Ok(())
}

fn is_idempotent_migration_error(err: &sqlx::Error) -> bool {
    let msg = err.to_string().to_ascii_lowercase();
    msg.contains("already exists")
        || msg.contains("duplicate")
        || msg.contains("duplicate key")
        || msg.contains("multiple primary keys")
}

async fn seed_local_admin(pool: &PgPool) -> Result<(), Box<dyn std::error::Error>> {
    const OWNER_ID: &str = "a1111111-1111-4111-8111-111111111111";
    const OWNER_EMAIL: &str = "owner@sakina.local";
    // Password: SakinaLocalOwner2026! — local QA docs only, never production.
    const OWNER_HASH: &str = "$argon2id$v=19$m=19456,t=2,p=1$47/EaEetH9m3u5TZNkwuAw$twCG4s3biiHSNn8PF6Ubt1iCYOO1qHX9mfVS6WDkNoE";

    sqlx::query(
        r#"INSERT INTO public.users (id, email, auth_provider, is_active)
           VALUES ($1::uuid, $2, 'password', true)
           ON CONFLICT (email) DO UPDATE SET is_active = true, updated_at = now()"#,
    )
    .bind(OWNER_ID)
    .bind(OWNER_EMAIL)
    .execute(pool)
    .await?;

    let owner_id: uuid::Uuid = sqlx::query_scalar(
        "SELECT id FROM public.users WHERE email = $1 LIMIT 1",
    )
    .bind(OWNER_EMAIL)
    .fetch_one(pool)
    .await?;

    sqlx::query(
        r#"INSERT INTO public.auth_identities (user_id, provider, provider_user_id, provider_email)
           VALUES ($1, 'password', $2, $2)
           ON CONFLICT (provider, provider_user_id) DO UPDATE
               SET provider_email = EXCLUDED.provider_email, updated_at = now()"#,
    )
    .bind(owner_id)
    .bind(OWNER_EMAIL)
    .execute(pool)
    .await?;

    sqlx::query(
        r#"INSERT INTO public.password_credentials (user_id, password_hash, password_salt, password_version)
           VALUES ($1, $2, 'argon2id', 'argon2id-v1')
           ON CONFLICT (user_id) DO UPDATE
               SET password_hash = EXCLUDED.password_hash,
                   password_salt = EXCLUDED.password_salt,
                   updated_at = now()"#,
    )
    .bind(owner_id)
    .bind(OWNER_HASH)
    .execute(pool)
    .await?;

    sqlx::query(
        r#"INSERT INTO public.admin_users (user_id, admin_email, account_status)
           VALUES ($1, $2, 'active')
           ON CONFLICT (admin_email) DO UPDATE
               SET user_id = EXCLUDED.user_id, account_status = 'active', updated_at = now()"#,
    )
    .bind(owner_id)
    .bind(OWNER_EMAIL)
    .execute(pool)
    .await?;

    println!("Local admin owner seeded: {OWNER_EMAIL}");
    Ok(())
}
