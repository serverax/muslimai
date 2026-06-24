#!/usr/bin/env python3
"""Index approved Sakina Islamic chunks from Postgres into Qdrant."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from typing import Any


DATABASE_URL = os.environ.get("DATABASE_URL", "postgres://sakina_user:sakina_password@localhost:5434/sakina")
QDRANT_URL = os.environ.get("QDRANT_URL", "http://localhost:6333").rstrip("/")
QDRANT_COLLECTION = os.environ.get("QDRANT_COLLECTION", "sakina_islamic_chunks_en")
VLLM_URL = os.environ.get("VLLM_URL", "http://localhost:18080").rstrip("/")
EMBEDDING_MODEL = os.environ.get("VLLM_EMBEDDING_MODEL", "sakina-feature-hash-128")


def http_json(method: str, url: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=body, method=method)
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"{method} {url} returned {exc.code}: {exc.read().decode('utf-8')}") from exc


def fetch_chunks() -> list[dict[str, Any]]:
    sql = r"""
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
    FROM (
      SELECT
        c.id::text AS chunk_id,
        d.id::text AS document_id,
        s.id::text AS source_id,
        s.title,
        s.source_type,
        c.language,
        c.review_status,
        c.citation_text,
        c.chunk_text
      FROM sakina_ai.islamic_chunks c
      JOIN sakina_ai.islamic_documents d ON d.id = c.document_id
      JOIN sakina_ai.islamic_sources s ON s.id = d.source_id
      WHERE c.review_status IN ('verified', 'approved')
        AND c.source_status = 'approved'
        AND d.review_status IN ('verified', 'approved')
        AND d.source_status = 'approved'
        AND s.review_status IN ('verified', 'approved')
        AND s.source_status = 'approved'
      ORDER BY s.title, c.chunk_index
    ) t;
    """
    output = subprocess.check_output(
        ["psql", DATABASE_URL, "-v", "ON_ERROR_STOP=1", "-At", "-c", sql],
        text=True,
    )
    return json.loads(output)


def embed(text: str) -> list[float]:
    payload = {"model": EMBEDDING_MODEL, "input": text}
    response = http_json("POST", f"{VLLM_URL}/v1/embeddings", payload)
    return response["data"][0]["embedding"]


def ensure_collection(size: int) -> None:
    try:
        http_json(
            "PUT",
            f"{QDRANT_URL}/collections/{QDRANT_COLLECTION}",
            {"vectors": {"size": size, "distance": "Cosine"}},
        )
        return
    except RuntimeError as exc:
        if "returned 409" not in str(exc):
            raise

    existing = http_json("GET", f"{QDRANT_URL}/collections/{QDRANT_COLLECTION}")
    vectors = existing.get("result", {}).get("config", {}).get("params", {}).get("vectors", {})
    existing_size = vectors.get("size") if isinstance(vectors, dict) else None
    if existing_size != size:
        raise RuntimeError(
            f"existing collection {QDRANT_COLLECTION} has vector size {existing_size}, expected {size}"
        )


def upsert(points: list[dict[str, Any]]) -> None:
    http_json(
        "PUT",
        f"{QDRANT_URL}/collections/{QDRANT_COLLECTION}/points?wait=true",
        {"points": points},
    )


def main() -> int:
    chunks = fetch_chunks()
    if len(chunks) < 10:
        print(f"INDEX_RAG_CORPUS_BLOCKER approved chunk count below 10: {len(chunks)}", file=sys.stderr)
        return 1
    first_vector = embed(chunks[0]["chunk_text"])
    ensure_collection(len(first_vector))
    points = []
    for chunk in chunks:
        points.append(
            {
                "id": chunk["chunk_id"],
                "vector": embed(chunk["chunk_text"]),
                "payload": {
                    "chunk_id": chunk["chunk_id"],
                    "document_id": chunk["document_id"],
                    "source_id": chunk["source_id"],
                    "title": chunk["title"],
                    "source_name": chunk["title"],
                    "source_type": chunk["source_type"],
                    "source_reference": chunk["citation_text"],
                    "citation": chunk["citation_text"],
                    "language": chunk["language"],
                    "review_status": chunk["review_status"],
                    "authenticity_grade": chunk["review_status"],
                },
            }
        )
    upsert(points)
    print(json.dumps({"indexed_chunks": len(points), "collection": QDRANT_COLLECTION, "dimension": len(first_vector)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
