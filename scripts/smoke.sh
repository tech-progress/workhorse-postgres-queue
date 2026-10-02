#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"
: "${COMPOSE_PROJECT_NAME:?Set the project name of your running local stack}"
: "${WORKHORSE_DASHBOARD_PASSWORD:?Set the dashboard password}"
compose=(docker compose -p "${COMPOSE_PROJECT_NAME}")
url="${WORKHORSE_SMOKE_URL:-http://127.0.0.1:${DASHBOARD_PORT:-18100}}"
curl --fail --silent "${url}/readyz" >/dev/null
[[ "$(curl --silent --output /dev/null --write-out '%{http_code}' "${url}/workhorse/")" == 401 ]]
[[ "$(curl --silent -u "${WORKHORSE_DASHBOARD_USERNAME:-operator}:invalid" --output /dev/null --write-out '%{http_code}' "${url}/workhorse/")" == 401 ]]
curl --fail --silent -u "${WORKHORSE_DASHBOARD_USERNAME:-operator}:${WORKHORSE_DASHBOARD_PASSWORD}" "${url}/workhorse/" >/dev/null
"${compose[@]}" exec -T worker node scripts/smoke.mjs
echo "Dashboard anonymous/wrong-password rejection and authenticated UI passed"
