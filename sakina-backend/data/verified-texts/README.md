# Verified Text Corpus

Place reviewed `.txt` source files here before running ingestion.

Production ingestion is intentionally limited to reviewed, license-compatible
Islamic texts. Each file should include visible title/chapter markers such as
`كتاب`, `باب`, `فصل`, `مسألة`, `Book`, `Chapter`, or `Section` so the chunker
can preserve citation context.

Run locally without indexing only for parser checks:

```bash
cargo run --bin sakina-ingest -- --path data/verified-texts --no-index
```

Run production ingestion with Postgres, vLLM, and Qdrant available:

```bash
cargo run --release --bin sakina-ingest -- --path data/verified-texts
```
