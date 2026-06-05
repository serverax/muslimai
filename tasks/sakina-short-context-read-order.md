# Short Context for Agent

Read the full order from:

```text
/F:/SakinaAL/reports/sakina-ultimate-hard-execution-order.md
```

or in WSL:

```text
/mnt/f/SakinaAL/reports/sakina-ultimate-hard-execution-order.md
```

You must execute that Markdown file as the source of truth.

Do not rely on memory or previous chat summaries.

The project is Sakina AI only.

Do not work on lawapp.

Do not work on unrelated OrdinoxAI tasks unless required for Sakina deployment.

Current classification is:

```text
NOT READY — REAL BLOCKERS REMAIN
```

Your job is to make it genuinely ready for closed beta or prove exactly why it remains blocked.

You must not produce another optimistic report.

You must not use fake, mock, placeholder, static, demo, or screenshot-only evidence.

You must not mark anything complete unless there is command output, runtime proof, DB proof where needed, frontend/backend wiring proof where needed, and CI/Kubernetes proof where needed.

The required final gates are:

```bash
cd /mnt/f/SakinaAL || exit 1

bash scripts/sakina/final-wiring-gate.sh
bash scripts/sakina/final-new-technologies-gate.sh
bash scripts/sakina/final-closed-beta-gate.sh
```

Sakina can only be marked:

```text
READY FOR CLOSED BETA — HARD EVIDENCE PASSED
```

if every blocking gate passes with real evidence.

If any blocking gate fails, the final verdict must remain:

```text
NOT READY — REAL BLOCKERS REMAIN
```

or, if the failure is wiring:

```text
NOT READY — BACKEND/FRONTEND/DB WIRING BLOCKERS REMAIN
```

or, if the failure is new technologies:

```text
NOT READY — NEW TECHNOLOGY WIRING BLOCKERS REMAIN
```
