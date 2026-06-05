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
    ];

    for (name, sql) in migrations {
        println!("Applying Sakina migration {name}");
        sqlx::raw_sql(sql).execute(&pool).await?;
    }

    println!("Sakina migrations applied");
    Ok(())
}
