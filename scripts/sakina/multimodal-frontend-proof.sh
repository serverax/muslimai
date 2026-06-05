#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MULTIMODAL_FRONTEND_BLOCKER %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

require_cmd rg

cat tasks/AGENTS.md >/dev/null
cat tasks/sakina-loop-control-rules.md >/dev/null
cat tasks/sakina-ultimate-hard-execution-order.md >/dev/null
cat tasks/sakina-restricted-advanced-technologies-order.md >/dev/null

rg -n "image_picker|file_picker" sakina-frontend/pubspec.yaml \
  || fail "Flutter picker dependencies are missing"
rg -n "MultimodalAnalysisScreen|pickImage|FilePicker\\.pickFiles|ImageSource\\.camera|ImageSource\\.gallery|analyzeMultimodal" \
  sakina-frontend/lib/screens/multimodal_analysis_screen.dart \
  || fail "multimodal screen does not expose real image/document upload actions"
rg -n "http\\.MultipartRequest|Authorization.*Bearer|x-request-id|MultimodalAnalysisResponse|401|403|413|415|422|429|500" \
  sakina-frontend/lib/services/api_service.dart sakina-frontend/lib/screens/multimodal_analysis_screen.dart \
  || fail "frontend service does not prove authenticated multipart upload and error mapping"
rg -n "MultimodalAnalysisScreen\\(session: widget\\.session\\)|document_scanner" \
  sakina-frontend/lib/screens/home_shell_screen.dart \
  || fail "multimodal screen is not wired into mobile navigation"
if rg -n "demo-token|test-token|FakeModuleApiClient|mock.*multimodal|fake.*multimodal|Future\\.delayed" \
  sakina-frontend/lib; then
  fail "frontend multimodal path contains fake/demo/mock behavior"
fi

if command -v flutter >/dev/null 2>&1; then
  (cd sakina-frontend && flutter analyze)
else
  printf 'flutter not available in WSL; Windows flutter analyze must be run by closed-beta gate.\n'
fi

printf 'MULTIMODAL_FRONTEND_OK Flutter multimodal UI and service wiring are present and analyzer-compatible where flutter is available.\n'
