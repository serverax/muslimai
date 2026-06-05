# Sakina AI No Fake Code Gate

Date: 2026-06-04

## Final Gate Result

Production-path gate: PASS WITH JUSTIFIED SECURITY-CONTROL HITS.

Whole-repo gate: NOT CLEAN because documentation and test fixtures intentionally contain historical audit terms and test-only mocks.

## Production Paths Scanned

Command:

```bash
git grep -n -i -E "todo|fixme|stub|mock|fake|dummy|placeholder|hardcoded|echo.*passed|Smoke validation passed|mode.:.mock|DATABASE_URL not set|sub-1|test-token|demo-token|SAKINA_API_TOKEN|FakeModuleApiClient|unimplemented!|panic!|unwrap\(" sakina-backend/src sakina-backend/db/migrations sakina-frontend/lib scripts .github sakina-infra infra k8s helm 2>$null
```

Output after adding fail-closed startup controls:

```text
sakina-backend/src/main.rs:69:            && !value.to_ascii_lowercase().contains("dummy")
sakina-backend/src/main.rs:74:fn fake_mode_disabled() -> bool {
sakina-backend/src/main.rs:76:        && !env_flag("ALLOW_MOCK_AI")
sakina-backend/src/main.rs:77:        && !env_flag("ALLOW_MOCK_RAG")
sakina-backend/src/main.rs:78:        && !env_flag("ALLOW_MOCK_AUTH")
sakina-backend/src/main.rs:79:        && !env_flag("ALLOW_MOCK_PAYMENTS")
sakina-backend/src/main.rs:80:        && !env_flag("ALLOW_FAKE_CI_PASS")
sakina-backend/src/main.rs:143:    if base.starts_with("mock://") {
sakina-backend/src/main.rs:166:    let fake_disabled = fake_mode_disabled();
sakina-backend/src/main.rs:177:        "fake_mode": if fake_disabled { "disabled" } else { "enabled" },
sakina-backend/src/main.rs:194:        && snapshot["fake_mode"] == "disabled"
sakina-backend/src/services/embeddings.rs:80:        if self.base_url.starts_with("mock://") {
sakina-backend/src/services/embeddings.rs:81:            return Err("mock embedding endpoints are not allowed in production paths".into());
sakina-backend/src/services/embeddings.rs:121:        if self.base_url.starts_with("mock://") {
sakina-frontend/lib/services/api_service.dart:784:        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
sakina-frontend/lib/services/api_service.dart:804:        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
sakina-frontend/lib/services/api_service.dart:1388:        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
```

Status: PASS WITH JUSTIFICATION. The `ALLOW_MOCK_*`, `ALLOW_FAKE_CI_PASS`, `mock://`, `fake_mode`, and `dummy` hits are fail-closed detection logic. They reject unsafe configuration rather than enabling simulated behavior. The Flutter `confidence` hits are normal response-field parsing and do not match any simulated-path behavior.

## Whole Repo Scanner Classification

Command:

```bash
git grep -n -i -E "todo|fixme|stub|mock|fake|dummy|placeholder|hardcoded|echo.*passed|Smoke validation passed|mode.:.mock|DATABASE_URL not set|sub-1|test-token|demo-token|SAKINA_API_TOKEN|FakeModuleApiClient|unimplemented!|panic!|unwrap\(" .
```

Classification:

- Allowed test-only mock: `sakina-frontend/test/**`, including `MockClient`, `_FakeApiService`, `FakeModuleApiClient`, `sub-1`, and `SharedPreferences.setMockInitialValues`.
- Documentation only: historical audit/order/status documents under root docs, `sakina-docs/**`, and `reports/qa/**`.
- Dangerous production mock: none remaining in the production paths scanned above.
- Production blocker: none from this scanner in the production paths scanned above.
- Must be removed now: none from the production paths scanned above.

## Production Fixes Made For This Gate

- Removed static mobile API token fallback from `sakina-frontend/lib/services/api_service.dart`.
- Removed production `SAKINA_API_TOKEN` Kubernetes env wiring from `sakina-infra/manifests/sakina-api-deployment.yaml`.
- Removed production-path fake pass wording from Sakina scripts and staging workflow.
- Removed production-path TODO/placeholder wording from ingestion producer and replaced content hashing with SHA-256.
- Removed `panic!` and `unwrap()` scanner hits from production source and DB-test helper paths.
- Removed `phase2_placeholder_screen.dart` from Flutter production `lib/`.
- Added fail-closed config checks for `ALLOW_DEMO_MODE=false`, `ALLOW_MOCK_AI=false`, `ALLOW_MOCK_RAG=false`, `ALLOW_MOCK_AUTH=false`, `ALLOW_MOCK_PAYMENTS=false`, and `ALLOW_FAKE_CI_PASS=false`.

## Remaining Notes

The gate proves scanner cleanliness only for production paths. It does not prove full production readiness; the final sign-off report lists remaining runtime blockers.
