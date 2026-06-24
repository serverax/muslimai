# SAKINA FULL PROJECT HANDOFF

## Product summary

Sakina AI is a Muslim companion app centered on Islamic Q&A, Quran/Hadith browsing, source citations, and safe guidance for higher-risk religious questions. The product is meant to build trust by preferring sourced answers, showing provenance, and refusing to invent rulings when confidence is low.

## Target users

| User type | Needs | Features | Risk level |
| --- | --- | --- | --- |
| General Muslim user | fast trustworthy answers | chat, citations, source browsing | medium |
| New Muslim/revert | clear guidance | plain-language explanations, safe refusal for fatwa | high |
| Parent/family | family-safe guidance | preferences, child-safe controls | medium |
| Arabic-speaking user | RTL and Arabic content | Arabic UI, Arabic sources, citations | medium |
| English-speaking user | accessible answers | English UI, evidence display | medium |
| Islamic student | source study | Quran/Hadith/library search, metadata | medium |
| Admin reviewer | moderation/source control | audit logs, flagged answer review | high |
| Scholar reviewer | content validation | source review queue, citation verification | high |
| Premium user | advanced features | entitlement gating if present | medium |

## User stories

As a Muslim user, I want to ask an Islamic question, so that I can receive a useful answer based on trusted sources.

Acceptance criteria:
- Given I ask a normal Islamic question
- When the system answers
- Then it should show the answer and source/citation when relevant

As a Muslim user, I want the app to avoid unsupported fatwas, so that I am not misled by an AI answer.

Acceptance criteria:
- Given I ask a high-risk fatwa question
- When trusted source confidence is low
- Then the app should not invent a ruling
- And it should recommend consulting a qualified scholar

## UI/UX

| Screen | Status | Backend wired? | UX gaps | Priority |
| --- | --- | --- | --- | --- |
| Home | partial | partial | no runtime proof | high |
| Chat | partial | partial | compile/runtime proof missing | high |
| Islamic Library | partial | partial | Flutter verification blocked | high |
| Quran | partial | partial | dedicated flow not fully proven | medium |
| Hadith | partial | partial | dedicated flow not fully proven | medium |
| Duas | partial | partial | not runtime verified | medium |
| Prayer | partial | partial | not runtime verified | medium |
| Profile | partial | partial | not runtime verified | medium |
| Settings | partial | partial | not runtime verified | medium |
| Subscription | partial | partial | payment schema runtime not proven | medium |
| Admin Dashboard | partial | partial | no runtime proof | high |

## Architecture snapshot

- Backend: Actix-web Rust API with PostgreSQL and service modules for chat, RAG, Islamic knowledge, guardrails, and decision routing.
- Frontend: Flutter mobile app with an Islamic library screen and chat/client service layer.
- DB: additive SQL migrations plus a large phase-3 schema covering users, auth, chat, Islamic sources, RAG, admin, subscriptions, logs, and events.
- RAG: Qdrant + embeddings service integration exists in code, but runtime proof is still missing.
- Brain/algorithm: semantic router + decision algorithm + guardrails exist in code.
- WASM: no concrete build target was proven; defer until core backend/RAG are stable.

## Security status

Tool-backed security scans were not possible in this pass because the scanners were not available as runnable tools in the shell.

## Demo plan

1. Restore a Cargo-compatible network/cache state or vendor dependencies.
2. Run backend format/check/test to completion.
3. Restore Flutter tooling and run pub get/analyze/test.
4. Validate local DB/runtime behavior.
5. Re-run security scans and then move to live persistence proofs.

## Blockers

- Cargo dependency resolution blocked by crates.io DNS/network access
- Flutter toolchain not available in PATH
- gitleaks/semgrep/trivy not available
- no live DB/runtime proof

