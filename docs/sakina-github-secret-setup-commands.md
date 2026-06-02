# Sakina GitHub Secret Setup Commands

Use GitHub CLI to configure required secrets without exposing values in commit history.

## Prerequisites

- `gh auth status` reports a valid authenticated session.
- You are in repository root (`F:/SakinaAL`).
- Secret values are exported as local shell environment variables before running commands.

## Commands

```bash
gh secret set ORDINOX_TALOS_KUBECONFIG_B64 --body "$ORDINOX_TALOS_KUBECONFIG_B64"
gh secret set ORDINOX_TALOS_CONTEXT --body "$ORDINOX_TALOS_CONTEXT"
gh secret set SAKINA_STAGING_POSTGRES_PASSWORD --body "$SAKINA_STAGING_POSTGRES_PASSWORD"
gh secret set SAKINA_STAGING_DATABASE_URL --body "$SAKINA_STAGING_DATABASE_URL"
gh secret set SAKINA_STAGING_JWT_SECRET --body "$SAKINA_STAGING_JWT_SECRET"
gh secret set SAKINA_STAGING_OPENAI_API_KEY --body "$SAKINA_STAGING_OPENAI_API_KEY"
gh secret set SAKINA_STAGING_BACKEND_IMAGE --body "$SAKINA_STAGING_BACKEND_IMAGE"
gh secret set SAKINA_STAGING_RAG_IMAGE --body "$SAKINA_STAGING_RAG_IMAGE"
gh secret set SAKINA_STAGING_ADMIN_IMAGE --body "$SAKINA_STAGING_ADMIN_IMAGE"
```

## Verify Secret Names (No Values)

```bash
gh secret list
```

## Security Reminder

- Do not paste secret values into chat, commits, PR comments, or workflow logs.
