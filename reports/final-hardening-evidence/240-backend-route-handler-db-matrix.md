# Backend Route Handler DB Matrix

This matrix is intentionally not marked complete. The task requires every route to be exhaustively mapped and tested. Current known blockers are listed first.

| Endpoint | HTTP Method | Auth Required | Handler File | Service/Function File | DB Tables | Migration File | RLS Policy | Positive Test | Negative Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| /health | GET | No | sakina-backend/src/handlers/health.rs | sakina-backend/src/main.rs readiness helpers | N/A | N/A | N/A | local-runtime-proof | missing dependency readiness negative | COMPLETE BUT LOCAL ONLY |
| /health/ready | GET | No | sakina-backend/src/main.rs::production_readiness_check | readiness_snapshot | pg_tables, Qdrant HTTP, env config | 017_rls_user_isolation.sql | checks RLS status | local-runtime-proof | Qdrant/DB down proof not captured in this gate | PARTIAL |
| /health/observability | GET | No | sakina-backend/src/main.rs::observability_check | SQL counters | public.audit_logs, sakina_ai.brain_decision_traces, sakina_ai.rag_retrieval_audit, sakina_ai.safety_classifications | multiple | RLS enabled | local-runtime-proof | none | PARTIAL |
| /auth/register | POST | No | handlers/phase2.rs::register_user | services/phase2.rs::register_user | public.users, auth_identities, password_credentials, auth_sessions, auth_refresh_tokens | 002_users_profiles.sql, 016_password_auth.sql | RLS enabled | auth-live-proof | duplicate/weak password in security-regression | COMPLETE BUT LOCAL ONLY |
| /auth/login | POST | No | handlers/phase2.rs::login | services/phase2.rs::login_password | public.users, password_credentials, auth_sessions, auth_refresh_tokens | 016_password_auth.sql | RLS enabled | auth-live-proof | wrong password proof | COMPLETE BUT LOCAL ONLY |
| /auth/refresh | POST | Refresh token | Missing | Missing | public.auth_refresh_tokens, public.auth_sessions | 016_password_auth.sql | RLS enabled | Missing | Missing | FAILED |
| /auth/logout | POST | Yes | handlers/phase2.rs::logout | services/auth.rs token hash helpers | public.auth_sessions | 016_password_auth.sql | RLS enabled | auth-live-proof | revoked token proof | COMPLETE BUT LOCAL ONLY |
| /auth/me | GET | Yes | handlers/phase2.rs::current_user | services/auth.rs::authenticated_user_id; services/phase2.rs::get_user_summary | public.users, public.auth_sessions | 002_users_profiles.sql, 016_password_auth.sql | RLS enabled | auth-live-proof | no-token proof | COMPLETE BUT LOCAL ONLY |
| /api/auth/register | POST | No | handlers/phase2.rs::register_user | services/phase2.rs::register_user | same as /auth/register | same | same | route alias tests | Missing full live proof | PARTIAL |
| /api/auth/login | POST | No | handlers/phase2.rs::login | services/phase2.rs::login_password | same as /auth/login | same | same | route alias tests | Missing full live proof | PARTIAL |
| /api/auth/refresh | POST | Refresh token | Missing | Missing | public.auth_refresh_tokens | 016_password_auth.sql | RLS enabled | Missing | Missing | FAILED |
| /api/auth/logout | POST | Yes | handlers/phase2.rs::logout | services/auth.rs | public.auth_sessions | 016_password_auth.sql | RLS enabled | route alias tests | Missing full live proof | PARTIAL |
| /api/auth/me | GET | Yes | handlers/phase2.rs::current_user | services/auth.rs; services/phase2.rs | public.users, public.auth_sessions | same | RLS enabled | route alias tests | Missing full live proof | PARTIAL |
| /chat/conversations | POST | Yes | handlers/chat.rs::create_conversation | AiaOrchestrator route + SQL | sakina_ai.conversations | 005_chat_threads_messages.sql | RLS enabled | e2e-real-user-journey | cross-user proof | COMPLETE BUT LOCAL ONLY |
| /chat/conversations/{id}/messages | POST | Yes | handlers/chat.rs::add_message | AiaOrchestrator route + SQL | sakina_ai.messages | 005_chat_threads_messages.sql | RLS enabled | e2e-real-user-journey | unsafe message test | PARTIAL: no assistant response |
| /api/brain/trace | POST | No in current handler | handlers/brain.rs::test_route | services/aia_orchestrator.rs | sakina_ai.brain_decision_traces if pool-backed orchestrator | 014_brain_knowledge_graph.sql | RLS enabled | e2e-real-user-journey | bypass negative missing | PARTIAL |
| /api/memory/write | POST | Yes | handlers/memory.rs::write | services/memory_engine.rs::write | sakina_ai.user_memory_entries | 015_user_memory_multimodal.sql | RLS enabled | e2e-real-user-journey | cross-user proof | COMPLETE BUT LOCAL ONLY |
| /api/memory/read | GET | Yes | handlers/memory.rs::read | services/memory_engine.rs::read | sakina_ai.user_memory_entries | 015_user_memory_multimodal.sql | RLS enabled | e2e-real-user-journey | cross-user proof | COMPLETE BUT LOCAL ONLY |
| /api/memory/delete | DELETE | Yes | handlers/memory.rs::delete | services/memory_engine.rs::delete | sakina_ai.user_memory_entries | 015_user_memory_multimodal.sql | RLS enabled | missing | missing | PARTIAL |
| /v1/rag/query | POST | Intended yes, current proof mixed | handlers/rag.rs::query_rag | EmbeddingsService, QdrantVectorDB, Guardrails, AiaOrchestrator | Qdrant collection, sakina_ai Islamic chunks | 007, 008 | RLS enabled | Missing live provider proof | Missing provider-down proof | FAILED |
| /v1/islamic/ask | POST | No/unknown | handlers/islamic.rs::ask | IslamicAnswerService, HybridRagService | islamic source/chunk/cache tables | 007, 014 | RLS enabled | Islamic safety local script | live LLM missing | PARTIAL |
| Payment routes | Mixed | Yes | handlers/phase2.rs subscription handlers | services/phase2.rs payment/subscription functions | public payment/subscription/user_entitlements tables | migrations under db | RLS enabled | entitlement listing local | payment webhook proof missing | FAILED |
| Multimodal routes | Mixed | Yes | handlers/multimodal.rs | services/multimodal.rs | sakina_ai.multimodal_assets | 015_user_memory_multimodal.sql | RLS enabled | missing | missing | SAFE DISABLED / PARTIAL |
| Account deletion endpoint | Missing | Yes | Missing | Missing | public.users and dependent user-owned tables | Missing | RLS enabled | Missing | Missing | FAILED |

