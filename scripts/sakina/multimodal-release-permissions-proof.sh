#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  printf 'MULTIMODAL_RELEASE_PERMISSIONS_BLOCKER %s\n' "$1" >&2
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

manifest="sakina-frontend/android/app/src/main/AndroidManifest.xml"
[[ -f "$manifest" ]] || fail "Android main manifest is missing"
rg -n "android.permission.CAMERA" "$manifest" \
  || fail "camera permission is missing while camera upload UI is enabled"
if rg -n "RECORD_AUDIO|READ_MEDIA_AUDIO|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE" \
  sakina-frontend/android; then
  fail "audio/storage permissions are present without live audio/STT exposure"
fi
if [[ -d sakina-frontend/ios ]]; then
  rg -n "NSCameraUsageDescription" sakina-frontend/ios \
    || fail "iOS camera permission description is missing while camera upload UI is enabled"
  if rg -n "NSMicrophoneUsageDescription" sakina-frontend/ios; then
    fail "iOS microphone permission exists while audio/STT is not enabled"
  fi
else
  fail "sakina-frontend/ios is missing, so iOS release permissions cannot be proven"
fi

run_windows_flutter_builds() {
  local pwsh=""
  if [[ -x "/mnt/c/Program Files/PowerShell/7/pwsh.exe" ]]; then
    pwsh="/mnt/c/Program Files/PowerShell/7/pwsh.exe"
  elif command -v pwsh.exe >/dev/null 2>&1; then
    pwsh="pwsh.exe"
  elif command -v powershell.exe >/dev/null 2>&1; then
    pwsh="powershell.exe"
  else
    return 1
  fi

  "$pwsh" -NoLogo -NoProfile -Command "\
    Set-StrictMode -Version Latest; \
    \$ErrorActionPreference = 'Stop'; \
    Set-Location -LiteralPath 'F:\\SakinaAL\\sakina-frontend'; \
    Remove-Item -LiteralPath 'build\\app\\outputs\\flutter-apk\\app-release.apk' -Force -ErrorAction SilentlyContinue; \
    Remove-Item -LiteralPath 'build\\app\\outputs\\bundle\\release\\app-release.aab' -Force -ErrorAction SilentlyContinue; \
    flutter build apk --release; \
    if (\$LASTEXITCODE -ne 0) { throw \"release APK build failed with exit code \$LASTEXITCODE\" }; \
    flutter build appbundle --release; \
    if (\$LASTEXITCODE -ne 0) { throw \"release AAB build failed with exit code \$LASTEXITCODE\" }; \
    \$apk = Get-Item -LiteralPath 'build\\app\\outputs\\flutter-apk\\app-release.apk' -ErrorAction Stop; \
    \$aab = Get-Item -LiteralPath 'build\\app\\outputs\\bundle\\release\\app-release.aab' -ErrorAction Stop; \
    if (\$apk.Length -le 0 -or \$aab.Length -le 0) { throw 'release APK/AAB artifact is empty' }; \
    \$apk | Select-Object FullName,Length,LastWriteTime; \
    \$aab | Select-Object FullName,Length,LastWriteTime"
}

if command -v flutter >/dev/null 2>&1; then
  rm -f sakina-frontend/build/app/outputs/flutter-apk/app-release.apk
  rm -f sakina-frontend/build/app/outputs/bundle/release/app-release.aab
  (cd sakina-frontend && flutter build apk --release) \
    || fail "release APK build failed"
  (cd sakina-frontend && flutter build appbundle --release) \
    || fail "release AAB build failed"
elif run_windows_flutter_builds; then
  :
else
  fail "flutter is not available in WSL or Windows PowerShell; release APK/AAB proof cannot run"
fi

printf 'MULTIMODAL_RELEASE_PERMISSIONS_OK release permissions and Android/iOS release artifacts proved.\n'
