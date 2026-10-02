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
restored_postgres="${COMPOSE_PROJECT_NAME}-restore-db"
restored_volume="${COMPOSE_PROJECT_NAME}-restore-data"
cleanup() {
  docker rm -f "${restored_worker}" >/dev/null 2>&1 || true
  docker rm -f "${restored_postgres}" >/dev/null 2>&1 || true
  docker volume rm "${restored_volume}" >/dev/null 2>&1 || true
  "${compose[@]}" down -v --remove-orphans >/dev/null
  rm -rf "${temporary}"
}
trap cleanup EXIT
"${compose[@]}" build
"${compose[@]}" up -d --wait postgres worker dashboard
"${compose[@]}" exec -T worker node scripts/verify-runtime.mjs
"${compose[@]}" exec -T dashboard node scripts/verify-runtime.mjs
bash scripts/smoke.sh
task_id="$("${compose[@]}" exec -T worker node scripts/smoke.mjs enqueue-crash)"
"${compose[@]}" kill -s SIGKILL worker
"${compose[@]}" exec -T postgres pg_dump -U workhorse -d workhorse -Fc > "${temporary}/pending.dump"
restore_image="$("${compose[@]}" config --format json | jq -r '.services.postgres.image')"
printf 'Source volume=%s_postgres-data; distinct fresh restore volume=%s; restore database=%s\n' "${COMPOSE_PROJECT_NAME}" "${restored_volume}" "${restored_postgres}"
docker volume create --label "com.docker.compose.project=${COMPOSE_PROJECT_NAME}" "${restored_volume}" >/dev/null
docker run -d --name "${restored_postgres}" --label "com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
  --network "${COMPOSE_PROJECT_NAME}_default" -e POSTGRES_PASSWORD -e POSTGRES_USER=workhorse \
  -e POSTGRES_DB=workhorse_restore -e PGDATA=/var/lib/postgresql/data/pgdata \
  --mount "type=volume,src=${restored_volume},dst=/var/lib/postgresql/data" \
  --health-cmd 'pg_isready -U workhorse -d workhorse_restore' --health-interval 2s \
  --health-timeout 3s --health-retries 30 "${restore_image}" >/dev/null
restore_ready=false
for attempt in $(seq 1 60); do
  if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${restored_postgres}")" == healthy ]]; then
    restore_ready=true
    break
  fi
  sleep 1
done
[[ "${restore_ready}" == true ]]
docker exec -i "${restored_postgres}" pg_restore -U workhorse -d workhorse_restore --no-owner < "${temporary}/pending.dump"
"${compose[@]}" run -d --no-deps --name "${restored_worker}" -e "DATABASE_URL=postgresql://workhorse:${POSTGRES_PASSWORD}@${restored_postgres}:5432/workhorse_restore" worker >/dev/null
docker exec "${restored_worker}" node scripts/verify-runtime.mjs
docker exec "${restored_worker}" node scripts/smoke.mjs check "${task_id}"
docker exec "${restored_worker}" node scripts/smoke.mjs
docker rm -f "${restored_worker}" >/dev/null
"${compose[@]}" start worker
"${compose[@]}" exec -T worker node scripts/smoke.mjs check "${task_id}"
bash scripts/smoke.sh
echo "Workhorse build/start/auth/retry/delay/SIGKILL/checkpoint/distinct fresh-volume restore gates passed"
