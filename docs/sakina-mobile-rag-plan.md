# Sakina Mobile RAG Plan

## Objectives
- Build staging RAG pipeline for curated Islamic knowledge content.
- Maintain traceability from source document to chunk to response citation.

## Components
- Ingestion pipeline with chunking and metadata extraction.
- Embedding generation worker.
- Retrieval API with hybrid scoring hooks.
- Evaluation tests for grounding and citation presence.

## Data Flow
1. Source bundles dropped into staging storage.
2. Ingestion normalizes and chunks documents.
3. Embeddings generated and stored in staging vector index.
4. Query service retrieves top-k chunks and returns citations.

## Validation
- Unit tests for chunker and retrieval scoring.
- Integration smoke test against mock corpus in CI.
