# Sakina API Reference

Base URL: `http://localhost:8080/v1`

All request/response bodies are JSON unless noted.

## Health

### GET /health
Returns service and database status.

**Response 200**
```json
{
  "status": "healthy",
  "database": "ok",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Users

### POST /users
Create a user.

**Request**
```json
{
  "pub_key": "<public key>",
  "madhhab_preference": "hanafi"
}
```

**Response 201**
```json
{
  "id": "<uuid>",
  "pub_key": "<public key>",
  "madhhab_preference": "hanafi",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### GET /users/{user_id}
Fetch a user by id.

## RAG

### POST /rag/query
Run a retrieval-augmented query against the verified knowledge base.

**Request**
```json
{
  "query": "Is music permissible in Islam?",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "madhhab_filter": "hanafi"
}
```

**Response 200**
```json
{
  "answer": "...",
  "sources": [
    {
      "id": "chunk-1",
      "title": "Islamic Text",
      "author": "Scholar",
      "chapter": "Chapter 1",
      "authenticity_grade": "sahih"
    }
  ],
  "confidence": 0.92,
  "guardrail_triggered": false,
  "processing_time_ms": 450
}
```

## Classification

### POST /classify
Classify user intent for routing.

**Request**
```json
{ "text": "Is music permissible in Islam?" }
```

**Response 200**
```json
{
  "intent": "FiqhQuery",
  "confidence": 0.95,
  "routing_decision": "RAG"
}
```

## Sync

### POST /sync/backup
Upload an encrypted user backup blob.

### GET /sync/backup/{user_id}
Download an encrypted user backup blob.

## Dashboard

### GET /dashboard/guardrails
Return recent guardrail trigger events for monitoring.
