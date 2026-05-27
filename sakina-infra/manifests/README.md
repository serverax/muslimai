# Sakina Manifest Layout

- `sakina-prod/` contains the active deployment manifests for `7jzi.com` and `api.7jzi.com`.
- `sakina-api-deployment.yaml` is retained only as a legacy reference from the earlier `sakina-api` namespace rollout path.
- Any `sakinaai-*` historical exports/backups should remain outside active deploy paths and treated as legacy artifacts.

Redis PVC/data retention is explicitly out-of-scope for these manifest-only hardening updates.
