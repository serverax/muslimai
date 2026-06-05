# Sakina Mobile Deployment Runbook

## Deployment Order
1. Apply DB migrations in staging DB.
2. Deploy backend API and workers to `sakina-mobile-staging`.
3. Deploy RAG services to `sakina-rag-staging`.
4. Run backend smoke tests.
5. Validate mobile config and endpoint connectivity.

## Rollback Strategy
- Backend: rollout undo deployment by revision.
- DB: use explicit rollback scripts where provided; otherwise forward-fix.
- RAG: disable ingestion jobs first, then revert service image tags.

## Required Evidence
- Migration logs showing success.
- Smoke script pass output.
- Endpoint status from health checks.
- Release artifact tags and commit SHA.
