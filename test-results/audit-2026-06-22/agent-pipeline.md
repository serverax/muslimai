# Ask pipeline / RAG / safety audit (agent result, 2026-06-22)

## TWO answer engines
- Engine A `handlers/sakina_ask.rs::ask` = real `/api/sakina/ask`, hand-rolled keyword pipeline.
- Engine B `decision_algorithm::decide` + BrainController = cleaner trait pipeline w/ real safety classifier + citation gating. `/api/sakina/ask` NEVER calls decide. Only reachable via `/v1/rag/decide` (rag.rs:291) wired with EmptyRetriever (aia_orchestrator.rs:98) → always escalates. Good engine effectively DEAD.

## Actual ask flow (sakina_ask.rs::ask @346)
0. Distributed passthrough if SAKINA_BRAIN_URL set, forwards before auth (357-371)
1. Auth/user id 373-376; 2. Workspace ensure 386-389; 3. PII redaction 394-395 (heuristic); 4. Language+intent 396-397 (keyword); 5. trace_uuid 398-399; 6. local_sunni_topics 426-445; 7. Rules engine 448-492 (only if SAKINA_RULES_ENGINE_URL); 8. Safety classifier 496-544 (KEYWORD); 9. Brain route 550-561 (cosmetic, only can_generate read); 10. RAG 563-610; 11. LLM compose 617-689 gated; 12. Citation guard 693-736 (only if SAKINA_CITATION_GUARD_URL); 13. Empty refuse 738-745; 14. Anon learning 747-755; 15. Persist trace+answer 769-788; 16. Return 796-812.
- Answer validation/eval AI: MISSING on ask path (only in dead Engine B).
- Brain escalation/review flags computed (brain_policy.rs) but NEVER read.

## trace_id — generated+persisted for EVERY non-distributed answer
- trace_uuid @398-399 unconditional; persist_trace @769 before response; insert brain_decision_traces (213-254) + ask_shaikh_answers (265-284). persist fail → 500. Distributed passthrough does NOT persist locally.

## Safety classifier — keyword STUB
- crisis (88-102), out-of-scope/hacking (74-86), high_risk_fatwa (104-118: divorce/talaq/inheritance/killing/war/فتوى/طلاق), fabricated ritual (120-131). if/else 496-544 first-match. NO model.
- High-risk fatwa DOES insert scholar_review_queue (enqueue_scholar_review 331-344, pending/high, keyed trace_uuid).
- GAPS: crisis (518-527) does NOT insert escalation. enqueue result discarded `let _=` (332) → failed insert silently swallowed, user still told "escalated".

## RAG + citations
- HybridRagService::search (274-395) REAL: SQL keyword over islamic_chunks + embeddings + Qdrant REST + graph + fusion.
- vector_search silently returns Ok(empty) on error (176-182) → degrades keyword-only no signal. min_score from ask = Some(0.0) (571).
- Empty retrieval → REFUSES (islamic_knowledge.rs:404-418; llm.rs:72-74; sakina_ask.rs:738-745). No hallucination.
- CITATION ENFORCEMENT: only real guard is distributed (693-736, needs SAKINA_CITATION_GUARD_URL). If unset, NO local guard → zero-citation Islamic answer CAN be returned. LLM-compose path IS gated (617-620), non-LLM path NOT. Hard gate in dead Engine B.

## LLM gateway / Ollama
- Ask calls SakinaLlmGateway (639, llm_gateway.rs:71) → POST SAKINA_LLM_GATEWAY_URL. Only gateway binary talks Ollama (bin/llm_gateway.rs:134-154). Test asserts backend→gateway not ollama (135-138).
- Ollama internal-only by NETWORK only; no app-layer auth.
- Gated SAKINA_LLM_ENABLED (41-48,75-86), context gate (87-101), requires trace_id+workspace_id, safety gate (final else 545), citation gate compose (617-620).
- SAKINA_LLM_ENABLED=false → compose skipped, DB/RAG answer or refusal, no error. Default-closed holds.

## PII before LLM — YES (heuristic/shallow)
- redact top (394-395), safe_message → RAG (570) + gateway safe_user_message (652). Misses free-form names/addresses.

## Scholar escalation — partial, read side MISSING
- write REAL (enqueue scholar_review_queue). crisis does NOT insert. generic enqueue route only #[cfg(test)] not prod.
- queue READ MISSING — no GET/list in prod router (only assign+resolve POST, main.rs:845-851).
- assign REAL (phase2.rs:1364-1388 → scholar_review_assignments). resolve REAL (1390-1433 → updates scholar_review_queue.review_status match id OR request_id, upserts scholar_resolved_answers, transactional).
- NOT closed loop: no read pending queue; crisis never enqueues; resolved answer never delivered back to user.

## Top risks
1. Safe-engine (decide) NOT used by ask; live path = keyword.
2. Without external citation-guard, zero-citation Islamic answer deliverable.
3. Crisis/self-harm produces no human-review record.
4. Scholar escalation no read-back / no user-delivery loop.
