#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root}"
export COMPOSE_PROJECT_NAME="rt-workhorse-check-$$"
export POSTGRES_PASSWORD="$(openssl rand -hex 16)"
export WORKHORSE_DASHBOARD_PASSWORD="$(openssl rand -hex 16)"
export WORKHORSE_DASHBOARD_USERNAME=operator
export DASHBOARD_PORT="${DASHBOARD_TEST_PORT:-18110}"
export DASHBOARD_PUBLIC_ORIGIN="https://localhost:${DASHBOARD_PORT}"
compose=(docker compose -p "${COMPOSE_PROJECT_NAME}")
temporary="$(mktemp -d)"
restored_worker="${COMPOSE_PROJECT_NAME}-restored"
cleanup() {
  docker rm -f "${restored_worker}" >/dev/null 2>&1 || true
  "${compose[@]}" down -v --remove-orphans >/dev/null
  rm -rf "${temporary}"
}
trap cleanup EXIT
"${compose[@]}" build
"${compose[@]}" up -d --wait postgres worker dashboard
bash scripts/smoke.sh
task_id="$("${compose[@]}" exec -T worker node scripts/smoke.mjs enqueue-crash)"
"${compose[@]}" kill -s SIGKILL worker
"${compose[@]}" exec -T postgres pg_dump -U workhorse -d workhorse -Fc > "${temporary}/pending.dump"
"${compose[@]}" exec -T postgres createdb -U workhorse workhorse_restore
"${compose[@]}" exec -T postgres pg_restore -U workhorse -d workhorse_restore --no-owner < "${temporary}/pending.dump"
"${compose[@]}" run -d --no-deps --name "${restored_worker}" -e "DATABASE_URL=postgresql://workhorse:${POSTGRES_PASSWORD}@postgres:5432/workhorse_restore" worker >/dev/null
docker exec "${restored_worker}" node scripts/smoke.mjs check "${task_id}"
docker rm -f "${restored_worker}" >/dev/null
"${compose[@]}" start worker
"${compose[@]}" exec -T worker node scripts/smoke.mjs check "${task_id}"
bash scripts/smoke.sh
echo "Workhorse build/start/auth/retry/delay/SIGKILL/checkpoint/logical-restore gates passed"
