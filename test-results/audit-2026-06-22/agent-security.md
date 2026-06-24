# Security audit (agent result, 2026-06-22)

## Findings table
| # | Finding | Severity |
|---|---|---|
| 1 | Hardcoded "production"-named creds in docker-compose.distributed.yml | HIGH |
| 2 | No rate-limit/brute-force protection on /auth/login & /auth/register | HIGH |
| 3 | PII redactor phrase/heuristic — misses most real PII | MEDIUM |
| 4 | guardrails.rs = similarity-threshold only, not prompt-injection filter | MEDIUM |
| 5 | Predictable dev secrets in committed compose/CI fallbacks | LOW |
| 6 | expect() in 2 non-test request paths | LOW |

## 1. Secrets — Finding 1 HIGH
docker-compose.distributed.yml commits static secrets across 5 services: POSTGRES_PASSWORD sakina_password (:9), DATABASE_URL (:50,68,86,107,141), JWT_SECRET sakina_production_jwt_secret_32_chars_long (:57,75,93,118,150), ENCRYPTION_KEY sakina_production_encryption_key_32_ch. Guessable, named "production". Move to ${VAR:?required} like main compose.
GOOD: docker-compose.yml fail-fast env refs. Backend secrets via std::env::var. No hardcoded keys in src/. CI secret-scan.yml gitleaks 8.24.3. kubeconfig written to file+chmod600 (not leak).

## 2. Dangerous code
- 170 unwrap/expect/panic in src/ non-test, overwhelmingly #[cfg(test)].
- Mock/demo toggles GATED fail-closed: main.rs:83-88 fake_mode_disabled() requires explicit ALLOW_MOCK_*; readiness main.rs:300 refuses ready unless disabled. embeddings reject mock:// unless override. Good.
- Finding 6: rag.rs:370-371 expect (invariant-protected), ai_router.rs:310. LOW.

## 3. Injection — PASS
- All SQL parameterized (.bind). format! near SQL = error msg or bound LIKE (hybrid_rag.rs:98). No string-built SQL.
- SSRF low: service URLs from env not bodies. connectors.rs no outbound HTTP. No path traversal.

## 4. Auth/crypto
- Argon2id passwords (phase2.rs:2126-2147 OsRng salt; 016 argon2id-v1). No plaintext/SHA.
- JWT HS256 (auth.rs:62-76). Secret ≥32 (auth.rs:48, main.rs:260). Session binding live DB row (auth.rs:134-157). Enc key ≥32 readiness (main.rs:261).
- CORS allowlist no wildcard (main.rs:404-427).
- Finding 2 HIGH: only WaitlistRateLimiter (main.rs:563). register/login (phase2.rs:31,58) NO rate-limit/lockout. Argon2 cost doesn't stop credential stuffing.

## 5. PII — Finding 3 MEDIUM
Wired into ask (sakina_ask.rs:394 before RAG/LLM; brain_controller.rs:117, multimodal.rs:83). pii_redaction.rs catches only emails, ≥4-digit, phrase-prefixed names/addresses. Misses bare names, intl phones, IDs.

## 6. Guardrails — Finding 4 MEDIUM
guardrails.rs = similarity threshold only (0.85, rag.rs:90). NOT injection filter. Real content guardrails in sakina_ask.rs are keyword blocklist (bypassable by paraphrase). Jailbreak phrase checks exist (ai_router.rs:534). Component named "Guardrails" does no content safety — naming hazard.
