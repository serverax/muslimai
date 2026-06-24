# Schema Gap Analysis

Comparing the requested schemas against `20260529_phase3_full_product_schema_revision2.sql`.

## 1. Core Users and Isolation (Mostly Present)
*   **users:** Present (`public.users`)
*   **user_profiles:** Present (`public.user_profiles`)
*   **workspaces:** Present (`sakina_ai.workspaces`)
*   **workspace_members:** Missing
*   **auth_sessions:** Present (`public.auth_sessions`)
*   **user_preferences:** Present (split into `profile_preferences`, `language_preferences`, etc.)
*   **user_language_preferences:** Present (`public.language_preferences`)
*   **user_madhhab_preferences:** Missing (likely part of preferences jsonb, needs explicit table per new orders)
*   **user_country_context:** Missing
*   **user_safety_flags:** Missing

## 2. Islamic Knowledge Sources (Mostly Present, needs expansion)
*   **islamic_sources:** Present (`sakina_ai.islamic_sources`)
*   **islamic_source_collections:** Missing
*   **islamic_source_documents:** Present (`sakina_ai.islamic_documents`)
*   **islamic_source_chunks:** Present (`sakina_ai.islamic_chunks`)
*   **islamic_source_translations:** Missing
*   **islamic_source_metadata:** Missing
*   **islamic_source_authenticity:** Missing
*   **islamic_source_citation_map:** Missing

## 3. Quran Tables (All Missing - Critical Gap for Sakina Free AI Quran)
*   **quran_surahs:** Missing
*   **quran_ayahs:** Missing
*   **quran_translations:** Missing
*   **quran_tafsir:** Missing
*   **quran_topics:** Missing
*   **quran_topic_links:** Missing
*   **quran_bookmarks:** Present generally (`user_bookmarks`), needs specific table.
*   **quran_notes:** Missing
*   **quran_reading_progress:** Present generally (`user_quran_progress`), might need specific table.

## 4. Hadith Tables (All Missing)
*   **hadith_collections:** Missing
*   **hadith_books:** Missing
*   **hadith_narrations:** Missing
*   **hadith_chains:** Missing
*   **hadith_grades:** Missing
*   **hadith_topics:** Missing
*   **hadith_topic_links:** Missing
*   **hadith_translations:** Missing
*   **hadith_bookmarks:** Missing
*   **hadith_notes:** Missing

## 5. Fatwa Tables (All Missing)
*   **fatwa_sources:** Missing
*   **fatwa_documents:** Missing
*   **fatwa_questions:** Missing
*   **fatwa_answers:** Missing
*   **fatwa_topics:** Missing
*   **fatwa_madhhab_tags:** Missing
*   **fatwa_country_tags:** Missing
*   **fatwa_language_versions:** Missing
*   **fatwa_scholar_body:** Missing
*   **fatwa_verification_status:** Missing
*   **fatwa_citations:** Missing
*   **fatwa_scrape_jobs:** Missing
*   **fatwa_scrape_errors:** Missing
*   **fatwa_update_history:** Missing

## 6. RAG and Vector Tables (Partially Present)
*   **rag_documents:** (covered by islamic_documents)
*   **rag_chunks:** (covered by islamic_chunks)
*   **rag_embeddings:** (covered by islamic_embeddings)
*   **rag_retrieval_logs:** Present (`sakina_ai.rag_retrieval_audit`)
*   **rag_query_logs:** Missing
*   **rag_answer_sources:** Missing
*   **rag_source_rankings:** Missing
*   **rag_failed_retrievals:** Missing

## 7. Answer Control and Workflow Tables (Partially Present)
*   **answer_requests:** Missing
*   **answer_traces:** Covered by `brain_cache_metadata`/`conversations`/`messages`.
*   **answer_workflow_steps:** Missing
*   **answer_classifications:** Missing
*   **answer_risk_assessments:** Missing
*   **answer_policy_decisions:** Missing
*   **answer_citation_checks:** Present (`sakina_ai.citation_verification_events`)
*   **answer_confidence_scores:** Missing
*   **answer_rejections:** Missing
*   **answer_escalations:** Missing
*   **answer_feedback:** Present (`public.user_chat_feedback`)

## 8. Safety and Guardrails (Partially Present)
*   **safety_rules:** Missing
*   **safety_events:** Present (`sakina_ai.safety_classifications`)
*   **out_of_scope_events:** Missing
*   **medical_emergency_events:** Missing
*   **self_harm_events:** Missing
*   **high_risk_fatwa_events:** Missing
*   **prompt_injection_events:** Missing
*   **pii_redaction_events:** Missing
*   **blocked_answer_events:** Missing

## 9. Paid Features and Usage (Mostly Present)
*   **subscriptions:** Present (`public.user_subscriptions`)
*   **subscription_plans:** Present (`public.subscription_plans`)
*   **feature_entitlements:** Present (`public.entitlements`)
*   **feature_usage:** Missing explicitly
*   **payment_events:** Present (`public.payment_transactions`)
*   **usage_limits:** Missing explicitly
*   **premium_unlocks:** Missing explicitly
*   **billing_audit_logs:** Missing explicitly

## 10. Learning and Personalisation (Partially Present)
*   **learning_paths:** Missing
*   **learning_modules:** Missing
*   **learning_lessons:** Missing
*   **user_learning_progress:** Present (`public.user_learning_progress`)
*   **quizzes:** Missing
*   **quiz_questions:** Missing
*   **quiz_answers:** Missing
*   **user_quiz_attempts:** Missing
*   **user_goals:** Missing
*   **user_daily_tasks:** Missing
*   **user_dashboard_stats:** Missing

## 11. Tafsir Specifics (All Missing)
*   **quran_tafsir_sources:** Missing
*   **quran_tafsir_books:** Missing
*   **quran_tafsir_entries:** Missing
*   **quran_tafsir_languages:** Missing
*   **quran_tafsir_versions:** Missing
*   **quran_tafsir_ingestion_jobs:** Missing
*   **quran_tafsir_ingestion_errors:** Missing
*   **quran_tafsir_citations:** Missing
*   **quran_tafsir_cross_references:** Missing
*   **quran_tafsir_topic_tags:** Missing
*   **quran_tafsir_audit_logs:** Missing
*   **quran_tafsir_quality_reviews:** Missing
