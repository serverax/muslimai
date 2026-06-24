//! Ingestion job binary (Phase 2, Step 9).
//!
//! Scans a directory for `.txt` files and ingests each via `IngestionProducer`.
//! Usage: `sakina-ingest --path <dir>` (defaults to `data/verified-texts`).

use sakina_backend::services::IngestionProducer;
use sqlx::postgres::PgPool;
use std::path::PathBuf;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = parse_path_arg().unwrap_or_else(|| PathBuf::from("data/verified-texts"));

    let database_url = std::env::var("DATABASE_URL")
        .map_err(|_| "DATABASE_URL is required for Sakina ingestion")?;
    let pool = PgPool::connect(&database_url).await?;
    let producer = IngestionProducer::new(pool);

    let mut total = 0usize;
    for entry in std::fs::read_dir(&path)? {
        let p = entry?.path();
        if p.extension().and_then(|e| e.to_str()) == Some("txt") {
            println!("Ingesting {:?} ...", p);
            let n = producer.ingest_document(&p, "hanafi", "Unknown").await?;
            println!("  {n} chunks");
            total += n;
        }
    }
    println!("Done. {total} chunks ingested from {path:?}.");
    Ok(())
}

fn parse_path_arg() -> Option<PathBuf> {
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        if a == "--path" {
            return args.next().map(PathBuf::from);
        }
    }
    None
}
