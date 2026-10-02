#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"
: "${SOURCE_REPO:?Set SOURCE_REPO to the chosen existing publication repository}"
input="${1:?Pass a local serializedConfig JSON file}"
output="${2:?Pass a new local output JSON path}"
graph="$(mktemp)"
trap 'rm -f "${graph}"' EXIT
./node_modules/.bin/railway-iac-ts .railway/railway.ts > "${graph}"
python3 scripts/draft_tools.py restore "${input}" "${graph}" "${output}"
