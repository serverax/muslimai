# Sakina Security and User Isolation Checklist

## Security requirements

- No secrets hardcoded in Flutter.
- API keys remain server-side.
- HTTPS/TLS is used in production.
- Device tokens and session material are stored securely.
- Logs do not expose private user data or tokens.
- Error messages do not leak secrets.
- Dependency vulnerability checks are run in CI.

## User isolation requirements

- Every user-owned table is scoped by `user_id` or equivalent ownership.
- API handlers validate authenticated identity server-side.
- Cross-user reads and writes are denied.
- RAG and memory retrieval are scoped per user or workspace.
- Admin routes are role-protected.
- Family, profile, journey, chat, backup, subscription, and notification data are private.

## Current state

- Server-side scope checks exist in several handlers.
- Cross-user denial tests exist for parts of the journey/privacy path.
- Full token-based auth and the full denial matrix still need completion.

