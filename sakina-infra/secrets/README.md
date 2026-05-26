# Production Secret Management

Do not commit production secrets to `manifests/`.

The checked-in `db-credentials` Secret inside
`manifests/sakina-api-deployment.yaml` is a local-development default that
matches `sakina-backend/db/init.sql`. For staging and production, replace it
with one of these approaches:

- External Secrets Operator pulling from a cloud secret manager or Vault.
- Sealed Secrets encrypted for the target cluster.
- A manually created namespace Secret during a controlled deployment.

The required API secret shape is:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: sakina-api
type: Opaque
stringData:
  connection-string: postgres://USER:PASSWORD@postgres.sakina-data.svc.cluster.local:5432/sakina
```

Production deployments must also set non-default database credentials in the
Postgres deployment and rotate any previously used development passwords.
