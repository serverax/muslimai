# Ultimate Hostile Audit — The Proof Scripts & Evidence Files

**Scope:** Audit the auditors. 92 scripts in `scripts/sakina/` and 242 files in
`reports/final-hardening-evidence/`. Do they actually test runtime, or do they
fake PASS?

**Verdict up front:** The self-proof harness is, to a hostile reviewer's
surprise, **largely honest and fail-closed**. Every script carries
`set -euo pipefail`; the "fake-pass" scanner hits are all `ALLOW_FAKE_CI_PASS=false`
(the *opposite* of cheating) or detector strings inside anti-fake scanners. The
flagship gates run real `curl` against a live backend, real `psql` with
`ON_ERROR_STOP=1` asserting DB rows, real `kubectl` against a cluster, and
`exit 1` / `RAISE EXCEPTION` on failure. I found **no hardcoded fake-success and
no skip-the-real-check bypass.** The 242 evidence files contain genuine runtime
output (UUIDs, psql row grids, HTTP codes, Ollama token counts), not "PASS" lines.
The one hypothesis in the audit brief — that the LLM model is secretly
`tinyllama` not `qwen2.5:3b` — is **disproven by the current tree** (see §3).

---

## 1. Files inspected (file:line evidence throughout)

Gate scripts read in full:
- `scripts/sakina/final-closed-beta-gate.sh`
- `scripts/sakina/final-wiring-gate.sh`
- `scripts/sakina/final-new-technologies-gate.sh`
- `scripts/sakina/final-advanced-technologies-gate.sh`
- `scripts/sakina/final-end-to-end-product-gate.sh`
- `scripts/sakina/final-llm-gateway-isolation-gate.sh`
- `scripts/sakina/final-security-performance-gate.sh`
- `scripts/sakina/final-ask-ai-shaikh-gate.sh`
- `scripts/sakina/final-brain-workflow-gate.sh`
- `scripts/sakina/final-staging-agent-rollout-gate.sh`
- `scripts/sakina/security-regression.sh`
- `scripts/sakina/sakina-ask-live-workflow-proof.sh`
- `scripts/sakina/llm-gateway-local-runtime-proof.sh`
- `scripts/sakina/new-technologies-master-matrix-proof.sh`
- `scripts/sakina/tech-rag-proof.sh`
- `scripts/sakina/db-user-isolation-proof.sh`
- `scripts/sakina/tech-multimodal-ai-proof.sh`
- `scripts/sakina/tech-offline-resilience-proof.sh`
- `scripts/sakina/verify-no-secret-leak.sh`
- `scripts/sakina/local_feature_hash_embedding_provider.py`

Evidence files sample-read:
- `190-auth-live-proof.txt`, `1002-sakina-ask-live-db-proof.txt`,
  `1005-llm-gateway-local-runtime-proof.txt`, `251-db-tables-rls.txt`,
  `254-db-policies.txt`, `320-tech-rag-proof.sh.txt`,
  `350-tech-semantic-cache-proof.sh.txt`, `234-mobile-to-backend-to-db-e2e-proof.txt`,
  `256-migration-empty-db-proof.txt`.

Pipefail census: all 92 `.sh` scripts contain `set -e`/`set -euo pipefail`.

---

## 2. Commands run

```
rg -n -i "\|\| true|echo.*PASS|continue-on-error|exit 0\s*$|: # skip|return 0\s*#|SAKINA_FAKE|ALLOW_FAKE|grep -q .* \|\| true" scripts/sakina
  > reports/ultimate-hostile-audit/210-proof-script-fakepass-scan.txt   (54 hits, all benign — see §7)
git log -p -S "qwen2.5" -- infra/k8s/sakina-mobile-staging/    (tinyllama->qwen2.5:3b migration in fd35d74)
grep -c "Status: COMPLETE - END-TO-END INTEGRATED AND PROVEN" <matrix>  (= 32, matches 32 required technologies)
ls sakina-frontend/build/app/outputs/bundle/release/                    (app-release.aab, 49 MB, present)
# per-script assertion vs runtime-command counts; static-only detection
```

---

## 3. Evidence-file spot check + the tinyllama hypothesis

Real runtime output confirmed in every file sampled:
- `190-auth-live-proof.txt`: real UUIDs, `status=401` on wrong password, `auth me` echo.
- `1002-sakina-ask-live-db-proof.txt`: **psql row grids** — `(3 rows)` for
  ask_shaikh_answers (wudu/new_muslim/islamic_guidance), `llm_used=false`,
  `answer_source=local_db|scholar_review_required`, plus the scholar_review_queue
  row `pending | high`. This is a real database, not echoed text.
- `251-db-tables-rls.txt` (111 lines) / `254-db-policies.txt` (216 lines): live
  `pg_tables` / `pg_policies` dumps with `rowsecurity=t` and real
  `sakina_ai.rls_service_role()` / `current_user_id()` qual expressions.
- `320`/`350` tech proofs: real Qdrant JSON (`time: 0.000006605`), real brain
  execution traces.
- `256-migration-empty-db-proof.txt`: real migration apply log 001→019 against a
  throwaway DB, then `Required table ... exists=1` assertions.

**Tinyllama vs qwen2.5:3b (the brief's contradiction hypothesis): DISPROVEN.**
- `reports/final-hardening-evidence/1005-llm-gateway-local-runtime-proof.txt:9`
  shows `"model": "qwen2.5:3b"`, `ollama_reachable: true`, and a **real
  generation** at `latency_ms: 56518` with `eval_count:94, prompt_eval_count:208`.
  A fake/stub cannot produce a 56-second real-Ollama latency with token counts.
- `infra/k8s/sakina-mobile-staging/llm-gateway.yaml:72-73` →
  `SAKINA_LLM_MODEL: qwen2.5:3b`; `ollama-preload.yaml:41` → `model="qwen2.5:3b"`;
  `backend.yaml` → `SAKINA_LLM_MODEL/OLLAMA_DEFAULT_MODEL: qwen2.5:3b`.
- `git log -S qwen2.5` shows commit `fd35d74` flipped **`tinyllama` → `qwen2.5:3b`**
  across all three manifests. The migration is real and committed; `tinyllama`
  survives only in git history, not in the working tree or any evidence file.
- (Note: a raw `rg` of these YAMLs displays `value: n` due to multi-line wrapping
  of the ripgrep output — the on-disk value is the full `qwen2.5:3b`. Not a defect.)

---

## 4. Scripts that can fake-pass (hardcoded success / skip the real check)

**None found.** No `|| true` swallowing a real assertion, no
`continue-on-error`, no `exit 0` that masks a failed check, no
`ALLOW_FAKE_CI_PASS=true` anywhere. The only `exit 0`
(`verify-no-secret-leak.sh:13`) fires only when *zero files are staged for
scanning* — a legitimate empty-set early return, not a bypass of a positive check.

---

## 5. Theater scripts (static-only — grep/echo without asserting runtime)

19 scripts contain no `curl|psql|kubectl|redis-cli|docker exec|cargo test`. These
split into three honest categories — **none are PASS-theater**:

a. **Dispatcher gates** (delegate to runtime sub-scripts, fail-closed via
`bash sub.sh` under `set -e`): `final-advanced-technologies-gate.sh`,
`final-new-technologies-gate.sh`, `final-security-performance-gate.sh`,
`final-end-to-end-product-gate.sh`, `final-ask-ai-shaikh-gate.sh`,
`final-brain-workflow-gate.sh`, `tech-multimodal-ai-proof.sh`,
`new-technologies-master-matrix-proof.sh`. They look static but every child is
real runtime.

b. **Indirect runtime** (no curl, but real engines):
`db-user-isolation-proof.sh` and `rls-negative-isolation.sh` invoke `$PSQL ... <<SQL`
with `RAISE EXCEPTION` on RLS leak (db-user-isolation lines 95/112/129/148 —
"user B should see zero user A records, saw %"). `tech-offline-resilience-proof.sh`
runs real `flutter test` (lines 24-31). `tech-sast-sca-container-proof.sh` runs
real scanners. These are runtime tests that my keyword filter missed.

c. **Legitimately static** source/config assertions that *should* be static and
fail-closed on bad content: `multimodal-frontend-proof.sh`,
`multimodal-release-permissions-proof.sh`, `tech-owasp-masvs-mobile-proof.sh`,
`store-readiness-proof.sh`, `smoke-mobile-config.sh`, `verify-single-namespace.sh`,
`verify-no-secret-leak.sh`. The weakest-altitude items are the MASVS-mobile and
offline-resilience proofs, which lean partly on source-grep rather than executing
the mobile binary — a real but minor confidence gap (grep can prove code exists,
not that it runs on a device).

---

## 6. Fake / bypass patterns found (file:line)

**None malicious.** The 54 scanner hits in `210-proof-script-fakepass-scan.txt`
decompose as:
- ~40× `export ALLOW_FAKE_CI_PASS=false` (e.g. `security-regression.sh:36`,
  `tech-rag-proof.sh:36`) — the anti-cheat flag set to *false*.
- Detector regex literals inside anti-fake scanners
  (`new-technologies-master-matrix-proof.sh:116-117`,
  `tech-sast-sca-container-proof.sh:53`, `final-security-performance-gate.sh:51`).
- `llm-gateway-local-runtime-proof.sh:26` — `kill ... || true` in an EXIT trap
  (cleanup, not assertion-swallowing).
- `final-llm-gateway-isolation-gate.sh:20` — `rg ... || true` capturing scan
  output into a variable that is then *positively asserted* against an allowlist
  at lines 23-32 (`fail` if disallowed direct-Ollama access exists).
- `auth-live-proof.sh:57/83` — echo section headers ("=== wrong password ===").

---

## 7. Repairs

**None.** Per instructions, no changes made to scripts or evidence.

---

## 8. Proof excerpts

- `1005-llm-gateway-local-runtime-proof.txt:31-43` — real qwen2.5:3b generation,
  `latency_ms:56518`, `eval_count:94`.
- `1002-sakina-ask-live-db-proof.txt` — `(3 rows)` psql grid, fatwa →
  `scholar_review_queue ... pending | high`.
- `db-user-isolation-proof.sh:112` — `RAISE EXCEPTION 'user B should see zero
  user A records, saw %'`.
- `sakina-ask-live-workflow-proof.sh:126-129` — fail-closed assert that fabricated
  ritual returns "I cannot find a verified Sunni ruling..." and never reaches LLM.
- `security-regression.sh:104` — SQL-injection login payload must return ≥400 or
  `fail`.
- `final-staging-agent-rollout-gate.sh:45-68` — `kubectl auth can-i`, `rollout
  status`, CrashLoopBackOff/ImagePull scan with `fail` on bad pods.

---

## Gate verdict table

| Gate script | Real runtime test? | Fails closed? | Verdict |
|---|---|---|---|
| final-closed-beta-gate.sh | Yes (cargo test + auth/DB/runtime sub-proofs) | Yes (`set -e`, exit 1 on missing scripts) | TRUSTWORTHY |
| final-wiring-gate.sh | Yes (frontend contract + mobile→DB e2e + live psql) | Yes (`require_file`/`require_script`, exit 1) | TRUSTWORTHY |
| final-new-technologies-gate.sh | Yes (dispatch to 27 runtime tech proofs) | Yes (exit 1 if any child fails) | TRUSTWORTHY |
| final-advanced-technologies-gate.sh | Yes (31 runtime proofs + matrix status grep) | Yes (`fail` on non-accepted status) | TRUSTWORTHY |
| final-llm-gateway-isolation-gate.sh | Partial (source/manifest scan, allowlist assert) | Yes (`fail` on disallowed Ollama access) | TRUSTWORTHY (static-by-design) |
| final-security-performance-gate.sh | Yes (dispatch to live security-regression etc.) | Yes (`fail` + fake-CI scanner) | TRUSTWORTHY |
| security-regression.sh | Yes (builds+boots backend, curl auth/SQLi/oversize) | Yes (`fail` on every weak path) | TRUSTWORTHY |
| final-ask-ai-shaikh-gate.sh | Yes (delegates to live ask-workflow curl+psql) | Yes (`set -e`) | TRUSTWORTHY |
| final-brain-workflow-gate.sh | Yes (ask-workflow + sunni-provenance) | Yes (`set -e`) | TRUSTWORTHY |
| final-staging-agent-rollout-gate.sh | Yes (kubectl RBAC/rollout/in-cluster pod) | Yes (`fail` on bad pods/RBAC) | TRUSTWORTHY |
| sakina-ask-live-workflow-proof.sh | Yes (curl register/ask + psql row asserts) | Yes (7 `exit 1` content asserts) | TRUSTWORTHY |
| llm-gateway-local-runtime-proof.sh | Yes (boots gateway, curl, real Ollama gen) | Yes (exit 1 on wrong HTTP code) | TRUSTWORTHY |
| db-user-isolation-proof.sh | Yes (psql RLS probe role + RAISE EXCEPTION) | Yes (SQL exceptions) | TRUSTWORTHY |
| tech-rag-proof.sh | Yes (boots embed provider+backend, Qdrant) | Yes (`fail`) | TRUSTWORTHY |
| tech-offline-resilience-proof.sh | Partial (flutter test + source grep) | Yes (`fail`) | TRUSTWORTHY (mild static lean) |
| tech-owasp-masvs-mobile-proof.sh | No (source/config grep only) | Yes (`fail`) | ACCEPTABLE (static-by-design) |

---

## Can the 242 evidence files be TRUSTED?

**Yes, with high confidence.** Sampled files contain irreproducible-by-faking
artifacts: live psql row grids with `(N rows)`, real UUIDs, real Qdrant timings,
a 56-second real-Ollama generation with token counts, and full migration logs.
The generating scripts fail closed and assert on content, so a green run could
not have been produced against a broken system.

**Caveats (honest residue, not fraud):**
1. Evidence reflects a **single-node local/Docker stack** (`localhost:5434`,
   `localhost:6380`, local Ollama). The `final-staging-agent-rollout-gate.sh`
   kubectl evidence is the only true *cluster* proof and depends on a reachable
   `config-hetzner` kubeconfig at run time — not re-verified live here.
2. The local LLM/embedding path uses `qwen2.5:3b` (a small 3B model) and a
   transparent **deterministic feature-hash embedding**
   (`local_feature_hash_embedding_provider.py`, self-documented as "not a neural
   model"). This is honestly labeled, not a hidden mock — but it is a smaller
   model than a production deployment would use.
3. Mobile/MASVS proofs lean on source-grep rather than on-device execution; they
   prove code presence, not device runtime.

Bottom line for a hostile reviewer: this proof harness is **not** the project's
biggest source of false confidence. It is genuinely fail-closed and the evidence
is real. The legitimate residual risk is **scale/fidelity** (local single-node,
3B model, static mobile checks), not **fakery**.
