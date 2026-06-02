#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/f/SakinaAl"
BACKEND="$ROOT/sakina-backend"
FRONTEND_CMD='C:\flutter\bin\flutter.bat'

source "$ROOT/scripts/env.sh"

cd "$BACKEND"
cargo check
cargo test

cd "$ROOT"
cmd.exe /c "cd /d F:\SakinaAl\sakina-frontend && ${FRONTEND_CMD} pub get && ${FRONTEND_CMD} analyze && ${FRONTEND_CMD} test"

echo "Sakina demo verification passed"
