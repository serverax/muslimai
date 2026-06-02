# Sakina GitHub Secrets

The following repository secrets are required for staging CI/CD automation.

## Required Secrets

- `ORDINOX_TALOS_KUBECONFIG_B64`  
  Base64-encoded kubeconfig for the validated Ordinox/Talos cluster context.
- `ORDINOX_TALOS_CONTEXT`  
  Exact kube context name expected by deployment scripts.
- `SAKINA_STAGING_POSTGRES_PASSWORD`  
  Postgres password used by `postgres` and migration jobs in staging.
- `SAKINA_STAGING_DATABASE_URL`  
  Connection string consumed by backend and migration workloads.
- `SAKINA_STAGING_JWT_SECRET`  
  JWT signing/verification secret for backend auth.
- `SAKINA_STAGING_OPENAI_API_KEY`  
  API key for RAG and backend model calls.
- `SAKINA_STAGING_BACKEND_IMAGE`  
  Fully-qualified backend image reference.
- `SAKINA_STAGING_RAG_IMAGE`  
  Fully-qualified rag image reference.
- `SAKINA_STAGING_ADMIN_IMAGE`  
  Fully-qualified admin image reference.

## Notes

- Never commit secret values into repository files.
- Keep all staging manifests and deployment jobs restricted to namespace `sakina-mobile-staging`.
- Rotate secrets after incidents, credential sharing, or offboarding events.
