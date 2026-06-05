# Global Anti-Fake Scan Review

This file is a blocker until `180-global-anti-fake-scan.txt` is generated and each hit is reviewed.

Known production blockers:

| Hit | Classification | Action |
| --- | --- | --- |
| Missing refresh endpoint/client despite issued refresh token | production blocker | Implement `/auth/refresh`, `/api/auth/refresh`, frontend refresh, token rotation proof. |
| Live LLM/embedding provider disabled | safe-disabled and hidden required | Current readiness may allow disabled-closed, but closed beta cannot claim live AI/RAG. |
| Payment gateway/webhook not proven | production blocker or safe-disabled-hidden | Hide payment UI or implement real provider/webhook proof. |
| Multimodal provider/storage proof missing | production blocker or safe-disabled-hidden | Hide multimodal UI or implement full upload/provider/isolation proof. |
| Kubernetes unavailable | production blocker | Restore cluster DNS/context and rerun namespace proof. |

