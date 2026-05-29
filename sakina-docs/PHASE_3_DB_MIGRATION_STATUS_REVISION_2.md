# SAKINA Full Product DB Schema - Revision 2 (Schema Package)

Date: 2026-05-29  
Branch: `qa-security-hardening`

## Status

- Revision 2 is prepared as a **schema-only package for review**.
- No deployment commands were executed.
- No SQL apply operation was executed against any database runtime.

## Migration files in package

- `sakina-backend/db/20260528_phase3_chat_foundation.sql`  
  Base chat foundation schema.
- `sakina-backend/db/20260529_phase3_schema_hardening.sql`  
  Phase 3 hardening for governance and Islamic/RAG decision domains.
- `sakina-backend/db/20260529_phase3_full_product_schema_revision2.sql`  
  Full product-domain Revision 2 schema package with non-destructive, idempotent table/constraint/index coverage.
- `sakina-backend/db/20260529_phase3_full_product_schema_revision2_rollback_procedure.md`  
  Explicit rollback procedure (snapshot restore strategy) for environments where Revision 2 is executed.

## Excluded file from production apply path

- `sakina-backend/db/init.sql` is **excluded** from production apply path.
- Reason:
  - legacy bootstrap script, not a versioned migration step;
  - includes environment bootstrap responsibilities outside migration sequencing;
  - contains hardcoded local bootstrap credential material and should not be used as an auditable production migration source.

## Revision 2 policy checks

- Idempotent style used: `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
- Non-destructive style used: no `DROP TABLE`, no `DROP COLUMN`, no destructive rewrites.
- Governance constraints included for Islamic source status/type/language using safe `DO $$ ... IF NOT EXISTS` blocks.
- Payment records use provider references only (`provider_*_ref` style fields); no card PAN/CVV storage.
- Optional madhhab preference retained as nullable profile field (not forced).

## Review note

This package is marked **ready for approval review** at schema level and intentionally not applied in this revision.

## Rollback support

- Rollback companion is documented in:
  `sakina-backend/db/20260529_phase3_full_product_schema_revision2_rollback_procedure.md`
- A destructive down-SQL file is intentionally not provided for this broad idempotent package because safe rollback depends on pre-apply state capture.
- Approved rollback method: restore the pre-Revision-2 DB snapshot/backup and verify post-restore schema consistency.
