#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-local-structure-fixture}"
export WORKHORSE_DASHBOARD_PASSWORD="${WORKHORSE_DASHBOARD_PASSWORD:-local-structure-fixture}"
export NTFY_BOOTSTRAP_PASSWORD="${NTFY_BOOTSTRAP_PASSWORD:-local-structure-fixture}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-LocalStructureFixture123}"
docker compose config --quiet
for script in scripts/*.sh; do bash -n "${script}"; done
python3 scripts/verify_contract.py
export SOURCE_REPO="${SOURCE_REPO:-qualification-owner/qualification-repo}"
export VERIFY_GRAPH="$(mktemp)"
trap 'rm -f "${VERIFY_GRAPH}"' EXIT
./node_modules/.bin/railway-iac-ts .railway/railway.ts > "${VERIFY_GRAPH}"
jq -e '.ok == true and (.diagnostics | all(.severity != "error"))' "${VERIFY_GRAPH}" >/dev/null
npm test
python3 -m unittest discover -s tests
echo "Local structural verification passed; remote publication gates remain pending."
