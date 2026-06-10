# AGENT-llm-rag — Hostile QA Audit (Areas A & B)

Auditor mode: hostile, static source + manifest only. No cargo build/check/test run.
Date: 2026-06-06. Branch: qa-security-hardening.

---

## (1) Exact files inspected

- `sakina-backend/src/bin/llm_gateway.rs` — the gateway service binary (the ONLY component allowed to talk to Ollama)
- `sakina-backend/src/services/llm_gateway.rs` — backend-side gateway CLIENT (`SakinaLlmGateway`)
- `sakina-backend/src/handlers/sakina_ask.rs` — main answer handler / orchestration
- `sakina-backend/src/services/hybrid_rag.rs` — hybrid RAG (keyword + vector + graph)
- `sakina-backend/src/services/islamic_knowledge.rs` — `IslamicAnswerService.answer` (RAG answer assembly + policy gate)
- `sakina-backend/src/services/graph_rag.rs` — `GraphRagService` (suspected dead)
- `sakina-backend/src/services/knowledge_graph_service.rs` — `KnowledgeGraphService` (live graph)
- `sakina-backend/src/services/llm.rs` — `LlmService` vLLM client (suspected dead)
- `sakina-backend/src/services/qdrant_client.rs` — Qdrant vector search (reqwest HTTP)
- `sakina-backend/src/services/embeddings.rs` — vLLM embeddings client
- `sakina-backend/src/services/pii_redaction.rs` — PII redaction
- `sakina-wasm/fatwa-policy-gate/src/lib.rs` — deterministic fatwa publish gate
- `sakina-backend/src/main.rs` — service wiring
- `infra/k8s/sakina-mobile-staging/{llm-gateway,ollama,backend,ollama-preload,smoke-tests}.yaml` — manifests
- `scripts/sakina/final-llm-gateway-isolation-gate.sh` — isolation CI gate
- `.github/workflows/sakina-deploy.yml` — deploy/smoke

## (2) Exact line numbers per finding

### Area A — LLM Gateway / Ollama isolation

- Backend client targets the GATEWAY, never Ollama: `sakina-backend/src/services/llm_gateway.rs:55-56`
  (`SAKINA_LLM_GATEWAY_URL`, default `http://sakina-llm-gateway:8087`). Unit test asserts this: `llm_gateway.rs:135-138`.
- Gateway binary is the ONLY place `OLLAMA_BASE_URL` and `/api/generate` appear in app code:
  `sakina-backend/src/bin/llm_gateway.rs:234` (`OLLAMA_BASE_URL` default `http://sakina-ollama:11434`),
  `:69` (`/api/tags` for /ready), `:125-128` (`/api/generate`).
- Manifest enforces isolation: `OLLAMA_BASE_URL` env exists ONLY on the gateway pod
  (`infra/k8s/sakina-mobile-staging/llm-gateway.yaml:70-71`); backend pod gets only
  `SAKINA_LLM_GATEWAY_URL=http://sakina-llm-gateway:8087` (`backend.yaml:89-90`).
- Gateway requires trace_id AND workspace_id, else 400 rejected: `bin/llm_gateway.rs:105-110`.
- Gateway blocks when NO allowed context (local_db + rag + graph all empty), else 400
  `rejected_no_allowed_context`: `bin/llm_gateway.rs:111-121`. Client mirrors this fail-closed at
  `services/llm_gateway.rs:87-101` (`blocked_no_allowed_context`).
- Gateway is fail-closed when disabled: `services/llm_gateway.rs:75-86` (`disabled_closed`, `used:false`).
- Controlled system prompt forbids invention of Quran/hadith/fatwa and forces "cannot verify" on weak
  context: `bin/llm_gateway.rs:26-59`.
- PII handling: redaction happens in the BACKEND before the gateway call
  (`handlers/sakina_ask.rs:369-370` `redact_pii`), and only `safe_user_message` is sent
  (`sakina_ask.rs:549`). Gateway consumes the already-redacted `safe_user_message`
  (`bin/llm_gateway.rs:47-48,57`) and test proves raw PII never reaches the prompt
  (`bin/llm_gateway.rs:258-276`). Redaction engine: `services/pii_redaction.rs:7-71`.

### Area B — RAG / Citation grounding

- Real keyword search via sqlx ILIKE, filtered to `review_status IN ('verified','approved')` for BOTH
  chunk and source: `hybrid_rag.rs:83-107` (esp. `:92-93`).
- Real vector search via Qdrant + vLLM embeddings: `hybrid_rag.rs:170-272`; Qdrant HTTP search
  `qdrant_client.rs:142-166` (`/collections/{}/points/search`); embeddings via vLLM
  `embeddings.rs:79-91` (`/v1/embeddings`). Vector-resolved chunks re-filtered to verified/approved
  `hybrid_rag.rs:231-233`.
- Real graph retrieval wired through `KnowledgeGraphService.lookup`: `hybrid_rag.rs:286`; backing SQL
  against `sakina_ai.knowledge_graph_entities`: `knowledge_graph_service.rs:52-145+`.
- Hybrid scoring/ranking real: `hybrid_rag.rs:163-168` (weighted), graph affects score
  `:289-298`, sort/truncate `:312-322`.
- Weak-evidence block flag: `hybrid_rag.rs:376-380` (`weak_evidence_blocked` when no chunks or top
  score < 0.25).
- Fatwa policy gate (deterministic, fail-closed): `islamic_knowledge.rs:357-371` calling
  `sakina-wasm/fatwa-policy-gate/src/lib.rs:31-62`. Public answers require BOTH scholar approval AND a
  verified Quran/hadith citation or they are blocked.
- `generated_from_verified_sources` = `!citations.is_empty()`: `islamic_knowledge.rs:389`.
- sakina_ask short-circuit guardrails (crisis/out-of-scope/high-risk fatwa/fabricated ritual) all
  return canned refusals with empty citations: `handlers/sakina_ask.rs:422-470`.
- LLM only invoked AFTER local_db/RAG/graph already attempted and only if answer still empty + gateway
  enabled: `handlers/sakina_ask.rs:535-570`. Final fallback "cannot verify" when still empty: `:573-580`.

## (3) Commands run

```
mkdir -p reports/ultimate-hostile-audit
rg -n "OLLAMA_BASE_URL|ollama|/api/generate|SAKINA_LLM_GATEWAY_URL|sakina-llm-gateway|11434|8087" sakina-backend infra .github scripts > reports/ultimate-hostile-audit/060-llm-gateway-isolation.txt
rg -n -i "rag|qdrant|embedding|vector|graph|citation|chunk|retrieval|hallucination|grounding" sakina-backend/src > reports/ultimate-hostile-audit/090-rag-citation-scan.txt
rg -n "generate_sakina_answer|SakinaLlmGateway|pii_redaction|redact|safe_user_message|safety_flags" sakina-backend/src --type rust
rg -n "GraphRagService|graph_rag|KnowledgeGraphService|knowledge_graph_service" sakina-backend/src --type rust
rg -n "\.traverse\(|GraphRagService::new" sakina-backend/src
rg -n "VllmChatClient|LlmClient|LlmService|generate_grounded_answer|build_grounded_prompt" sakina-backend/src --type rust
rg -n "fn search|reqwest|points/search" sakina-backend/src/services/qdrant_client.rs
rg -n "fn embed|/v1/embeddings|VLLM" sakina-backend/src/services/embeddings.rs
rg -n "fn lookup|sqlx::query|FROM sakina" sakina-backend/src/services/knowledge_graph_service.rs
```

## (4) Evidence files created

- `reports/ultimate-hostile-audit/060-llm-gateway-isolation.txt` (117 lines)
- `reports/ultimate-hostile-audit/090-rag-citation-scan.txt` (1039 lines)
- `reports/ultimate-hostile-audit/AGENT-llm-rag.md` (this file)

## (5) Failures found

- None CRITICAL. No backend component hits Ollama directly. `OLLAMA_BASE_URL` / `/api/generate`
  appear in application code ONLY inside the gateway binary (`bin/llm_gateway.rs`) and in
  infra/CI/scripts (manifests, deploy smoke tests, isolation gate, local-runtime proof) — never in
  the Rust backend request path.
- MINOR (defense-in-depth gap, not a bypass): the gateway does NOT independently re-validate that
  `safe_user_message` is redacted, nor does it run its own unsafe-prompt classifier. It trusts the
  backend's redaction + guardrails and relies on the controlled system prompt. If any FUTURE caller
  other than `sakina_ask` calls the gateway with un-redacted text, the gateway would forward it.
  Today the only caller is `sakina_ask.rs` which DOES redact first. Recommend adding a redaction
  assertion / safety_flags enforcement inside the gateway.
- MINOR: `IslamicAnswerService.answer` does not hard-error on zero citations; it returns a
  payload with a "could not find enough verified evidence" message and `fallback_used:true`,
  `generated_from_verified_sources:false` (`islamic_knowledge.rs:347-352,389`). This is fail-soft
  (graceful refusal) not fail-closed-with-error. Acceptable for a chat product but worth noting:
  the LLM generation path is only reached when this returns an empty answer, and the gateway itself
  hard-blocks empty-context, so no ungrounded LLM answer can be produced.

## (6) Not-wired / dead code

- `GraphRagService` (`services/graph_rag.rs`) is DEAD. It is exported (`services/mod.rs:47`) but
  `GraphRagService::new(...)` and `.traverse(...)` have ZERO callers anywhere in the backend
  (verified: `rg "\.traverse\(|GraphRagService::new"` returns nothing). The LIVE graph component is
  `KnowledgeGraphService`, instantiated in `main.rs:504` and injected into `HybridRagService`
  (`main.rs:543`, `hybrid_rag.rs:51,286`). CONFIRMS the backend-wiring agent's suspicion.
- `LlmService` (`services/llm.rs`, vLLM `/v1/chat/completions` client) is DEAD/unwired. No
  instantiation in `main.rs` or any handler; references are confined to its own file + tests. It
  correctly refuses without context (`llm.rs:73`) but is not part of the live answer path. The live
  LLM path is `SakinaLlmGateway` -> `sakina-llm-gateway` bin -> Ollama.

## (7) Fake / mock / bypasses

- None found in the live path. keyword (sqlx), vector (Qdrant HTTP), graph (sqlx), embeddings (vLLM
  HTTP), and the fatwa policy gate are all real implementations, not stubs.
- `qdrant_hit_to_citation` in `islamic_knowledge.rs:457-487` is marked `#[allow(dead_code)]`
  "legacy ... retained for compatibility with older tests" — dead but harmless.

## (8) Repairs made

- None. All findings are either non-issues or design notes; no trivial-and-needed fix was required.
  The two MINOR items (gateway-side redaction re-assertion; deleting dead `GraphRagService`/`LlmService`)
  are recommendations, not applied, to avoid touching code paths outside a static-audit scope.

## (9) Proof after

Re-ran the isolation grep restricted to the backend request path (excluding the gateway bin and
infra): the only `OLLAMA_BASE_URL` / `/api/generate` hits are `bin/llm_gateway.rs`, manifests,
scripts, and CI — confirming backend isolation holds. Evidence preserved in
`060-llm-gateway-isolation.txt` (see lines 79-117 for the only Ollama-touching app code, all inside
`bin/llm_gateway.rs`).

---

## VERDICTS

- **LLM Gateway / Ollama isolation: PASS** — Backend uses `SAKINA_LLM_GATEWAY_URL` exclusively
  (services/llm_gateway.rs:55-56, asserted by test :135-138). `OLLAMA_BASE_URL`/`/api/generate` live
  only in the gateway binary (bin/llm_gateway.rs) and infra. Gateway enforces trace_id + workspace_id
  (:105-110), blocks on no-allowed-context (:111-121), uses a controlled anti-hallucination prompt
  (:26-59), and consumes only pre-redacted text (:47-48). One MINOR defense-in-depth recommendation
  (gateway-side redaction assertion).

- **RAG / Citation grounding: PASS (with one fail-soft note)** — hybrid_rag.rs does real
  keyword + vector + graph retrieval against verified/approved sources only; the fatwa policy gate
  (fatwa-policy-gate/src/lib.rs) hard-blocks public answers lacking scholar approval + verified
  citation; the LLM is only reachable after retrieval and the gateway independently refuses with no
  context. The single nuance: `IslamicAnswerService.answer` refuses gracefully (fail-soft message)
  rather than returning an error on zero citations — but it cannot emit an ungrounded LLM answer
  because the gateway blocks empty-context generation.

- **Dead code (informational):** `GraphRagService` (graph_rag.rs) and `LlmService` (llm.rs) are
  exported but unwired. Recommend deletion to avoid confusion; not a security/correctness failure.
