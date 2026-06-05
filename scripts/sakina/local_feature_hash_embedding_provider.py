#!/usr/bin/env python3
"""OpenAI-compatible local feature-hashing embedding provider for Sakina.

This service is intentionally small and dependency-free so local closed-beta
proofs can exercise the real HTTP embedding path without requiring GPU access.
It implements deterministic lexical feature hashing, not a neural model.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


MODEL_NAME = os.environ.get("SAKINA_LOCAL_EMBEDDING_MODEL", "sakina-feature-hash-128")
DIMENSION = int(os.environ.get("SAKINA_LOCAL_EMBEDDING_DIM", "128"))
TOKEN_RE = re.compile(r"[\w\u0600-\u06ff]+", re.UNICODE)


def vectorize(text: str) -> list[float]:
    vector = [0.0] * DIMENSION
    tokens = TOKEN_RE.findall(text.lower())
    for token in tokens:
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        bucket = int.from_bytes(digest[:8], "big") % DIMENSION
        vector[bucket] += 1.0
        vector[(bucket + 1) % DIMENSION] += 0.25
    norm = math.sqrt(sum(value * value for value in vector))
    if norm > 0:
        vector = [value / norm for value in vector]
    return vector


class Handler(BaseHTTPRequestHandler):
    server_version = "SakinaFeatureHashEmbedding/1.0"

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/v1/models":
            self._send_json(
                200,
                {
                    "object": "list",
                    "data": [
                        {
                            "id": MODEL_NAME,
                            "object": "model",
                            "owned_by": "sakina-local-runtime",
                        }
                    ],
                },
            )
            return
        if self.path.rstrip("/") == "/health":
            self._send_json(200, {"status": "ok", "model": MODEL_NAME, "dimension": DIMENSION})
            return
        self._send_json(404, {"error": {"message": "not found"}})

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/v1/embeddings":
            self._send_json(404, {"error": {"message": "not found"}})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(size).decode("utf-8"))
            input_value = payload.get("input", "")
            if isinstance(input_value, str):
                inputs = [input_value]
            elif isinstance(input_value, list) and all(isinstance(item, str) for item in input_value):
                inputs = input_value
            else:
                self._send_json(400, {"error": {"message": "input must be a string or string array"}})
                return
            self._send_json(
                200,
                {
                    "object": "list",
                    "model": payload.get("model") or MODEL_NAME,
                    "data": [
                        {
                            "object": "embedding",
                            "index": index,
                            "embedding": vectorize(text),
                        }
                        for index, text in enumerate(inputs)
                    ],
                },
            )
        except Exception as exc:  # pragma: no cover - server guard path
            self._send_json(500, {"error": {"message": str(exc)}})

    def log_message(self, format: str, *args: Any) -> None:
        return


def main() -> None:
    host = os.environ.get("SAKINA_LOCAL_EMBEDDING_HOST", "127.0.0.1")
    port = int(os.environ.get("SAKINA_LOCAL_EMBEDDING_PORT", "18080"))
    ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == "__main__":
    main()
