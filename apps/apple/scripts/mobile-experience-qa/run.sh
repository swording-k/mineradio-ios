#!/bin/zsh
set -euo pipefail
scriptdir=${0:A:h}
cd "$scriptdir/../../../.."
output="$PWD/.inspect/mobile-experience-qa"
mkdir -p "$output"
node apps/apple/scripts/build-web-bundle.cjs
python3 -u "$scriptdir/serve.py" > "$output/port" &
serverpid=$!
trap 'kill "$serverpid" 2>/dev/null || true' EXIT
sleep 0.3
xcrun swift "$scriptdir/check.swift" "http://127.0.0.1:$(cat "$output/port")/" "$output" > "$output/verification.log" 2>&1
cat "$output/verification.log"

rg -q '^MOBILE QA COMPLETE$' "$output/verification.log"
