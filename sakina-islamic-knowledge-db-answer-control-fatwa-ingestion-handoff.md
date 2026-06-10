# SAKINA AI — ISLAMIC KNOWLEDGE DB, ANSWER CONTROL & FATWA INGESTION HANDOFF

## 1. Executive Status
* **Verdict:** PARTIAL (Transitioning to full UI wiring)
* **Summary:** The core database schemas, Islamic knowledge APIs, and answer-control structures have been fully defined and migrated. The backend endpoints for Tafsir ingestion and Fatwa verification are implemented and wired. However, the complete 25-feature matrix still requires frontend mobile UI implementation to achieve the final "PASS" verdict for the end-to-end user experience.
* **Remaining Blockers:** Frontend wiring for the new Sakina Free AI Quran and Learning modules. 

## 2. Database Schema List
The following schemas have been fully implemented via migrations `022`, `023`, and `024`:
*   **Users & Isolation:** `users`, `user_profiles`, `workspaces`, `workspace_members`, `user_preferences`, `user_country_context`, `user_safety_flags`, `user_madhhab_preferences`.
*   **Knowledge Sources:** `islamic_sources`, `islamic_documents`, `islamic_chunks`, `islamic_embeddings`.
*   **Quran & Tafsir:** `quran_surahs`, `quran_ayahs`, `quran_translations`, `quran_tafsir_sources`, `quran_tafsir_entries`, `quran_tafsir_citations`.
*   **Hadith:** `hadith_collections`, `hadith_books`, `hadith_narrations`, `hadith_grades`, `hadith_topic_links`.
*   **Fatwa:** `fatwa_sources`, `fatwa_documents`, `fatwa_questions`, `fatwa_answers`, `fatwa_scrape_jobs`.
*   **Answer Control & Safety:** `answer_traces`, `safety_rules`, `out_of_scope_events`, `prompt_injection_events`, `blocked_answer_events`, `high_risk_fatwa_events`.
*   **Learning & Personalisation:** `learning_paths`, `learning_modules`, `learning_lessons`, `user_learning_path_progress`, `user_quiz_attempts`, `user_goals`.
*   **Subscriptions:** `subscription_plans`, `feature_usage`, `usage_limits`, `premium_unlocks`.

## 3. Migration Files Created
1.  `sakina-backend/db/migrations/022_sakina_phase4_quran_tafsir.sql`
2.  `sakina-backend/db/migrations/023_sakina_phase5_hadith_fatwa_learning.sql`
3.  `sakina-backend/db/migrations/024_sakina_phase6_safety_and_subscriptions.sql`

## 4. API Integrations & Scraper Implementation
*   `TafsirIngestionService` implemented to handle `POST /api/quran/tafsir/{id}/ingest`.
*   `FatwaVerifierService` implemented to handle `POST /api/fatwa/verify` logic and verification status updates.
*   The distributed orchestrator (`DistributedClient`) is wired to handle inter-service RAG retrieval and citation validation.

## 5. RAG Ingestion & Answer Workflow Proof
*   `Ask AI Shaikh` seamlessly transitions between Brain orchestration -> Local DB Hybrid RAG -> Citation Guard -> LLM Gateway.
*   Proof script `scripts/proof/ask_shaikh_e2e.sh` validates the end-to-end execution of this controlled pipeline.

## 6. Frontend Wiring Proof
*   *(Pending)*: The backend is ready. The Flutter frontend requires implementation of the `Quran Reader`, `Hadith Assistant`, and `New Muslim Journey` UI flows to consume the newly exposed endpoints.

## 7. Kubernetes Deployment Proof
*   Production and Staging namespaces have been updated with `backend.yaml`, `rag.yaml`, `llm-gateway.yaml`, `citation-guard.yaml`, and `brain.yaml`. TLS is enforced via `ingress.yaml` (cert-manager).

## 8. Security, User Isolation, and Paid Features
*   RLS (Row-Level Security) is structurally supported by the schema inclusion of `user_id` and `workspace_id` in all transactional and preference tables.
*   `feature_usage` and `usage_limits` tables are established to enable strict subscription enforcement at the backend level.

## 9. Final Sign-Off
The backend foundation for the 25-feature matrix is complete. We are now ready to commence the massive UI/UX implementation phase for the Sakina Free AI Quran and companion modules. 
