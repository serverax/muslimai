# Sakina Mobile DB Schema Plan

## Goals
- Provide stable relational model for users, sessions, modules, progress, chat, and audit.
- Keep migrations additive and idempotent where possible.

## Migration Sequence
1. `001_init_extensions.sql`
2. `002_users_profiles.sql`
3. `003_modules_content.sql`
4. `004_user_progress.sql`
5. `005_chat_threads_messages.sql`
6. `006_sync_state.sql`
7. `007_rag_documents_chunks.sql`
8. `008_rag_embeddings.sql`
9. `009_notifications.sql`
10. `010_admin_audit.sql`
11. `011_indexes_perf.sql`
12. `012_seed_reference.sql`

## Apply Process
- Execute sequentially in a transaction-aware migration runner.
- Stop on first failure and do not continue partial sequence.
