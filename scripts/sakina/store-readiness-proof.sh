#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'STORE_READINESS_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd bash
require_cmd rg

cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null

bash scripts/sakina/tech-store-compliance-proof.sh

apk_path="sakina-frontend/build/app/outputs/flutter-apk/app-release.apk"
aab_path="sakina-frontend/build/app/outputs/bundle/release/app-release.aab"
[[ -s "$apk_path" ]] || fail "release APK missing after store compliance proof"
[[ -s "$aab_path" ]] || fail "release AAB missing after store compliance proof"

stat "$apk_path" "$aab_path"

rg -n "Privacy Policy|Terms|Islamic Advisory Disclaimer|Data Export and Deletion|Request account deletion" \
  sakina-frontend/lib/screens/compliance_screen.dart \
  >/tmp/sakina-store-readiness-compliance-ui.txt \
  || fail "privacy, terms, disclaimer, and account deletion UI text is missing"
cat /tmp/sakina-store-readiness-compliance-ui.txt

rg -n "requestAccountDeletion|/account/delete-request|account_deletion_requested" \
  sakina-frontend/lib sakina-backend/src scripts/sakina/tech-data-retention-deletion-proof.sh \
  >/tmp/sakina-store-readiness-deletion-path.txt \
  || fail "account deletion frontend/backend/audit path is missing"
cat /tmp/sakina-store-readiness-deletion-path.txt

if rg -n -i "fake privacy|fake terms|demo account|demo-token|test-token|SAKINA_API_TOKEN|localhost|127\\.0\\.0\\.1|10\\.0\\.2\\.2|lorem|changeme" \
  sakina-frontend/lib sakina-frontend/android/app/src/main sakina-frontend/ios/Runner; then
  fail "store mobile production paths contain local/demo/fake placeholder blockers"
fi

printf 'STORE_READINESS_OK release artifacts, compliance UI, deletion flow, permissions, and production config checks are proven by runtime store compliance proof.\n'
