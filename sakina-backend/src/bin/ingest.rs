//! Ingestion job binary (Phase 2, Step 9).
//!
//! Scans a directory for `.txt` files and ingests each via `IngestionProducer`.
//! Usage: `sakina-ingest --path <dir>` (defaults to `data/verified-texts`).
//! Pass `--no-index` only for offline schema/chunking tests; production
//! ingestion indexes chunks into Qdrant.

use sakina_backend::services::{EmbeddingsService, IngestionProducer, QdrantVectorDB};
use sqlx::postgres::PgPoolOptions;
use std::path::PathBuf;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = IngestArgs::parse();
    let path = args
        .path
        .unwrap_or_else(|| PathBuf::from("data/verified-texts"));

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool = PgPoolOptions::new()
        .max_connections(8)
        .acquire_timeout(std::time::Duration::from_secs(10))
        .connect(&database_url)
        .await?;
    let producer = if args.index {
        let qdrant_url =
            std::env::var("QDRANT_URL").unwrap_or_else(|_| "http://localhost:6333".to_string());
        let vllm_url =
            std::env::var("VLLM_URL").unwrap_or_else(|_| "http://localhost:8000".to_string());
        let collection =
            std::env::var("QDRANT_COLLECTION").unwrap_or_else(|_| "verified_knowledge".to_string());
        let vector_size = std::env::var("QDRANT_VECTOR_SIZE")
            .ok()
            .and_then(|v| v.parse::<usize>().ok())
            .unwrap_or(1536);
        let qdrant = QdrantVectorDB::new(&qdrant_url, &collection);
        qdrant.ensure_collection(vector_size).await?;
        IngestionProducer::with_indexer(pool, EmbeddingsService::new(&vllm_url), qdrant)
    } else {
        IngestionProducer::new(pool)
    };

    let mut total = 0usize;
    for entry in std::fs::read_dir(&path)? {
        let p = entry?.path();
        if p.extension().and_then(|e| e.to_str()) == Some("txt") {
            println!("Ingesting {:?} ...", p);
            let n = producer
                .ingest_document(&p, &args.madhhab, &args.scholar)
                .await?;
            println!("  {n} chunks");
            total += n;
        }
    }
    println!("Done. {total} chunks ingested from {path:?}.");
    Ok(())
}

struct IngestArgs {
    path: Option<PathBuf>,
    madhhab: String,
    scholar: String,
    index: bool,
}

impl IngestArgs {
    fn parse() -> Self {
        let mut args = std::env::args().skip(1);
        let mut out = IngestArgs {
            path: None,
            madhhab: "hanafi".to_string(),
            scholar: "Unknown".to_string(),
            index: true,
        };

        while let Some(a) = args.next() {
            match a.as_str() {
                "--path" => out.path = args.next().map(PathBuf::from),
                "--madhhab" => {
                    if let Some(v) = args.next() {
                        out.madhhab = v;
                    }
                }
                "--scholar" => {
                    if let Some(v) = args.next() {
                        out.scholar = v;
                    }
                }
                "--no-index" => out.index = false,
                _ => {}
            }
        }

        out
    }
}

#[allow(dead_code)]
fn parse_path_arg() -> Option<PathBuf> {
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        if a == "--path" {
            return args.next().map(PathBuf::from);
        }
    }
    None
}
