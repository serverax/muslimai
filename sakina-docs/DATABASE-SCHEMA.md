# PostgreSQL Schema

## Schemas
- verified_knowledge
- audit
- outbox
- public

## Tables

### verified_knowledge.chunks
- id (UUID, PRIMARY KEY)
- source_document_id (UUID, FOREIGN KEY)
- content_chunk (TEXT)
- madhhab (ENUM: hanafi, maliki, shafii, hanbali)
- scholar (VARCHAR)
- book_title (VARCHAR)
- chapter (VARCHAR)
- authenticity_grade (ENUM: sahih, hasan, weak)
- token_count (INTEGER)
- created_at (TIMESTAMP)

### verified_knowledge.source_documents
- id (UUID, PRIMARY KEY)
- title (VARCHAR)
- author (VARCHAR)
- integrity_hash (VARCHAR UNIQUE)
- approved_by (VARCHAR)
- approved_at (TIMESTAMP)

### audit.logs
- id (BIGSERIAL, PRIMARY KEY)
- timestamp (TIMESTAMP DEFAULT NOW())
- event_type (VARCHAR)
- payload (JSONB)
- user_id (UUID NULLABLE)

### outbox.events
- id (UUID, PRIMARY KEY)
- event_type (VARCHAR)
- payload (JSONB)
- status (ENUM: Pending, Processing, Sent, Failed)
- retry_count (INTEGER DEFAULT 0)
- max_retries (INTEGER DEFAULT 5)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

### outbox.dead_letters
- id (UUID, PRIMARY KEY)
- event_id (UUID, FOREIGN KEY)
- error_message (TEXT)
- created_at (TIMESTAMP)

### public.users
- id (UUID, PRIMARY KEY)
- pub_key (VARCHAR UNIQUE)
- madhhab_preference (ENUM)
- created_at (TIMESTAMP)

### public.user_backups
- id (UUID, PRIMARY KEY)
- user_id (UUID, FOREIGN KEY)
- encrypted_blob (BYTEA)
- backup_hash (VARCHAR)
- created_at (TIMESTAMP)
