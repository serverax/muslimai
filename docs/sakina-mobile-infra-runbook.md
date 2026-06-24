# Sakina Mobile Infrastructure Runbook

## Preconditions
- Azure CLI authenticated to correct tenant/subscription.
- Terraform installed locally or in CI runner.
- Access limited to `rg-sakina-mobile-staging-uksouth`.

## Safe Target Validation
Run before any write action:
1. Confirm active subscription intended for staging.
2. Ensure all target names are prefixed `sakina-mobile-staging` or `sakina-*staging`.
3. Abort if command references existing non-staging namespaces or workloads.

## Provisioning Steps
1. Initialize Terraform in `infra/sakina-mobile`.
2. Validate and plan with staging tfvars.
3. Review diff for only fresh resources.
4. Apply after approval.

## Post-Provision Checks
- AKS reachable and cluster-info returns expected cluster name.
- Namespaces created exactly:
  - `sakina-mobile-staging`
  - `sakina-rag-staging`
  - `sakina-monitoring-staging`
  - `sakina-security-staging`

## Incident Notes
- Never run destructive commands against unknown namespaces.
- For failed apply, inspect plan and state references before retrying.
