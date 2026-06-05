# Reference Repository Review

Reviewed for safe reuse against Sakina:

1. `https://github.com/serverax/rahmahislamic`
2. `https://github.com/serverax/rahmah`
3. `https://github.com/serverax/siraj-app`

## Reference repos checked

- rahmahislamic: YES
- rahmah: YES
- siraj-app: YES

## Useful code found

- RahmaIslamic: polished Flutter screen patterns for home, Quran search/reader, adhkar, prayer times, qibla, onboarding, and localization.
- Rahmah: backend route/service structure for Quran, Hadith, Dua, Prayer, RAG, safety, source governance, auth, admin, deployment, and database migrations.
- Siraj: small Flutter widget patterns and devops scaffolding, mostly useful as a cautionary example rather than a direct code source.

## Useful models/config found

- Rahmah:
  - `apps/backend/src/llm/model-policy.ts`
  - `apps/backend/src/llm/prompts/classifier.prompt.ts`
  - `apps/backend/src/llm/prompts/islamic-answer.prompt.ts`
- RahmaIslamic:
  - localization generation and RTL-aware screen structure
  - Quran/adhkar/prayer/qibla tab and navigation patterns

## Useful Islamic content found

- Rahmah:
  - `data/islamic-sources/quran-full-tanzil.json`
  - `data/islamic-sources/quran-metadata.json`
  - `data/source-candidates/islamic-source-candidates.json`
  - `data/islamic-sources/offline-starter-content.json`
  - hadith/prayer/api source candidates and review policy docs
- RahmaIslamic:
  - adhkar JSON assets and authenticated-source references in localization/docs

## Useful mobile/frontend components found

- RahmaIslamic:
  - `lib/presentation/screens/home/home_screen.dart`
  - `lib/presentation/screens/quran/quran_search_screen.dart`
  - `lib/presentation/screens/adhkar/adhkar_home_screen.dart`
  - `lib/presentation/screens/prayer/prayer_times_screen.dart`
  - `lib/presentation/screens/qibla/qibla_screen.dart`
  - `lib/presentation/screens/auth/onboarding_screen.dart`
- Siraj:
  - `lib/core/widgets/sadaqah_jariah_banner.dart` as a reusable UI motif only

## Useful backend components found

- Rahmah:
  - `apps/backend/src/routes/{auth,dua,hadith,prayer,quran,admin,ask,ready,health}.ts`
  - `apps/backend/src/rag/{islamic-rag.service.ts,citation-guard.service.ts,retriever.service.ts,review-escalation.service.ts}`
  - `apps/backend/src/services/{quran,hadith,dua,prayer,source-governance}.ts`
  - `apps/backend/src/wasm/*`
  - `apps/backend/src/db/migrations/*`

## Useful DB/schema/migration files found

- Rahmah:
  - `database/full_schema.sql`
  - `database/rahma_content_schema.sql`
  - `docs/infra/RAHMA_DB_MIGRATION_RUNBOOK.md`
  - `docs/ops/RAHMA_LIVE_DB_MIGRATION_OPERATOR_RUNBOOK.md`
- RahmaIslamic:
  - `IAM_DATABASE_SCHEMA.md`
  - Firestore schema docs and seed definitions

## Useful RAG/citation logic found

- Rahmah:
  - RAG service, citation guard, retrieval service, review escalation
  - approved source registry and source-candidate review process
- Sakina already has working local analogues in Rust; Rahmah is useful mainly for workflow and policy shape.

## Useful CI/CD/Docker/deployment files found

- Rahmah:
  - `deployment/k3s/*`
  - `docs/infra/*`
  - `docs/release/*`
- Siraj:
  - `devops/docker/Dockerfile`
  - `devops/terraform/main.tf`
  - `devops/scripts/deploy.sh`
  - `devops/scripts/backup.sh`

## Security risks found

- Siraj `setup_github_secrets.sh` is not safe to reuse as-is:
  - it is repo-specific
  - it references placeholder token material
  - it should not be copied into Sakina
- Rahma Firebase/app configuration files are project-specific and should not be copied into Sakina.
- Rahma back-end foundation files contain placeholder implementations; they are useful as structure only, not as runtime logic.

## Secrets found

- NO actual secrets were identified in the sampled reference files.

## Files safe to reuse

- RahmaIslamic:
  - screen/layout structure and localization patterns
  - RTL-aware typography and content presentation patterns
- Rahmah:
  - source governance and RAG workflow patterns
  - Islamic content registry/data model patterns
  - migration/runbook structure
- Siraj:
  - only isolated UI motif ideas and generic deployment sequencing notes

## Files not safe to reuse

- RahmaIslamic:
  - Firebase project-specific config files
- Rahmah:
  - any foundation-only stub returning placeholder statuses without real behavior
- Siraj:
  - `setup_github_secrets.sh`
  - project-specific Firebase/Cloud config files

## Recommended integration plan

1. Reuse RahmaIslamic UI structure and localization patterns for Sakina screens that need polish.
2. Reuse Rahmah's source-governance, RAG workflow, citation policy, and migration/runbook patterns as reference material only, then map them onto Sakina's existing Rust backend.
3. Ignore Siraj's placeholder deployment scripts; use it only as a reminder to keep deployment automation explicit and non-interactive.

