# Backend Unused Route Handler Review

This review must be completed from `241-backend-routes-scan.txt` and `242-backend-functions-scan.txt` after the scanner runs.

Current known blocker:

| Item | Classification | Reason |
| --- | --- | --- |
| `/auth/refresh`, `/api/auth/refresh` | missing route/handler | Required by the task, but not present in `sakina-backend/src/main.rs`. |
| Account deletion endpoint | missing route/handler | Required for closed beta/store readiness, but not mapped in current backend route matrix. |
| Several phase2/admin/support/notification handlers | review required | Existing functions need exhaustive route/test mapping before this gate can pass. |

