# Sakina Live Stack Tests

These tests are intended for a deployed local or staging stack with Postgres,
Qdrant, vLLM, and the Sakina API reachable at `http://localhost:8080`.

```bash
pip install -r requirements.txt
pytest integration
```

They validate the production contracts that unit tests cannot prove: health,
Prometheus metrics, RAG response shape, classification, user persistence,
encrypted backup storage, and dashboard guardrail retrieval.
