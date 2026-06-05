#!/usr/bin/env bash
set -euo pipefail

REPORT="reports/phase183d-repo-hygiene-secret-scan-report.txt"
mkdir -p "reports"

overall="PASS"

write_line() {
  printf "%s\n" "$1" >> "$REPORT"
}

mark_fail() {
  overall="FAIL"
  write_line "FAIL: $1"
}

mark_pass() {
  write_line "PASS: $1"
}

: > "$REPORT"
write_line "PHASE 183D REPO HYGIENE + SECRET CONTAINMENT SCAN"
write_line "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
write_line ""

# 1) .gitignore exists
if [[ -f ".gitignore" ]]; then
  mark_pass ".gitignore exists"
else
  mark_fail ".gitignore missing"
fi

# 2) gateway-password.txt ignored
if git check-ignore -q "gateway-password.txt"; then
  mark_pass "gateway-password.txt is ignored"
else
  mark_fail "gateway-password.txt is not ignored"
fi

staged_files="$(git diff --cached --name-only)"

# 3) no staged real secret files
if [[ -n "$staged_files" ]] && printf "%s\n" "$staged_files" | grep -Eqi '(^|/)(\.env(\..*)?|gateway-password\.txt|[^/]*\.(key|pem|p12|pfx)|kubeconfig[^/]*|talosconfig[^/]*|secrets/|secret[^/]*\.txt|[^/]*-secret[^/]*\.ya?ml|[^/]*-secrets[^/]*\.ya?ml)$'; then
  mark_fail "staged files contain real secret filenames"
else
  mark_pass "no staged real secret filenames"
fi

# 4) no obvious secret filenames staged
if [[ -n "$staged_files" ]] && printf "%s\n" "$staged_files" | grep -Eqi '(secret|password|passwd|token|api[_-]?key|credential|private[-_]?key)'; then
  mark_fail "staged files contain obvious secret-like filenames"
else
  mark_pass "no obvious secret-like filenames staged"
fi

# 5) no obvious secret content staged
if git diff --cached --no-color | grep -Eiq '^\+.*(BEGIN (RSA|EC|OPENSSH|DSA|PRIVATE) PRIVATE KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-|password[[:space:]]*[:=]|api[_-]?key[[:space:]]*[:=]|secret[[:space:]]*[:=]|token[[:space:]]*[:=])'; then
  mark_fail "staged diff has obvious secret-like content patterns"
else
  mark_pass "no obvious secret-like content in staged diff"
fi

# 6) node_modules ignored
if git check-ignore -q "node_modules/test-file"; then
  mark_pass "node_modules is ignored"
else
  mark_fail "node_modules is not ignored"
fi

# 7) backups ignored
if git check-ignore -q "backups/test-file"; then
  mark_pass "backups is ignored"
else
  mark_fail "backups is not ignored"
fi

# 8) quarantine folder exists if Ayosh file moved
if [[ -f "quarantine/cross-contamination/ayosh-system-prompt.txt" ]]; then
  if [[ -d "quarantine/cross-contamination" && -f "quarantine/cross-contamination/README.md" ]]; then
    mark_pass "quarantine folder and README exist for moved Ayosh file"
  else
    mark_fail "Ayosh file moved but quarantine folder/README incomplete"
  fi
else
  mark_pass "Ayosh quarantine check not required (file not moved)"
fi

write_line ""
write_line "OVERALL: $overall"

echo "Phase 183D scan complete: $overall"
echo "Report: $REPORT"
