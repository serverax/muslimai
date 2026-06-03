# Sakina CI/CD Status

This repository now includes the following automation:

- `.github/workflows/sakina-ci.yml`
- `.github/workflows/sakina-android-build.yml`
- `.github/workflows/sakina-ios-build.yml`
- `.github/workflows/sakina-backend-image.yml`
- `.github/workflows/sakina-deploy.yml`

## Intent

- Run Sakina Flutter checks on push, pull request, and manual dispatch.
- Run backend formatting, lint, and tests when `sakina-backend/` exists.
- Run repository secret and namespace guardrails before release activity.
- Build Android release artifacts with GitHub Secrets-based signing.
- Build iOS artifacts on macOS when iOS support and Apple signing inputs are present.
- Build and push the backend image to GHCR with immutable SHA tags.
- Deploy only to Sakina manifests and run rollout, logs, endpoint, and health checks.

## Current blockers

- Android release signing requires `android/key.properties` generated from secrets.
- iOS target must exist before the iOS workflow can succeed.
- Release deployment requires a valid `SAKINA_KUBECONFIG_B64`.
- Store submission paperwork still needs to be finalized in the app store checklists.

## Safety

- The automation is Sakina-only.
- The guard script refuses lawapp paths, lawapp remotes, and mixed-project command targets.
- Secrets are not committed to the repository.
