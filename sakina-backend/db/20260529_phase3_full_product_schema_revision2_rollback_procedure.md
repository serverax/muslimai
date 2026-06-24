# Revision 2 Rollback Procedure (Schema Package)

Date: 2026-05-29
Branch: `qa-security-hardening`
Target migration: `20260529_phase3_full_product_schema_revision2.sql`

## Why there is no destructive down-SQL file

Revision 2 introduces a broad, idempotent, non-destructive schema package across multiple domains.  
A single generic `DROP ...` rollback SQL would be unsafe because many objects may pre-exist in shared environments and cannot be reliably distinguished from pre-migration state without a baseline snapshot.

## Approved rollback strategy

Use **snapshot restore rollback** for any environment where Revision 2 was executed.

1. Confirm whether Revision 2 was executed in that environment (migration log/change record).
2. If not executed, rollback is a no-op.
3. If executed, restore the database to the pre-Revision-2 snapshot/backup taken immediately before apply.
4. Verify restoration:
   - `sakina_ai` objects introduced in Revision 2 return to their pre-change state.
   - governance constraints added in Revision 2 are absent unless they existed previously.
   - application smoke checks pass against restored schema.
5. Record rollback completion in the migration change log.

## Scope guardrails

- This procedure is schema-only.
- No deployment, cluster, or runtime orchestration commands are part of this rollback step.
- Do not run destructive SQL in production without a verified backup restore point.
