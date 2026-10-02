#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
old_ref=""
new_ref=""
old_postgres_ref=""
new_postgres_ref=""
port=18120
usage() {
  echo 'Usage: bash scripts/upgrade-smoke.sh --old-image FROZEN_0.6.0 --new-image BUILT_0.6.1 --old-postgres-image IMAGE@sha256:DIGEST --new-postgres-image IMAGE@sha256:DIGEST [--port 18120..18129]'
  echo 'Docker-only, stop-before-replace upgrade; existing local images only. No binary/schema downgrade or live-publication claim.'
}
while (($#)); do
  case "$1" in
    --old-image|--new-image|--old-postgres-image|--new-postgres-image|--port)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { usage >&2; exit 2; }
      case "$1" in
        --old-image) old_ref="$2" ;;
        --new-image) new_ref="$2" ;;
        --old-postgres-image) old_postgres_ref="$2" ;;
        --new-postgres-image) new_postgres_ref="$2" ;;
        --port) port="$2" ;;
      esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$old_ref" && -n "$new_ref" && "$old_ref" != "$new_ref" ]] || { usage >&2; exit 2; }
[[ "$old_postgres_ref" =~ ^[^[:space:]]+@sha256:[a-f0-9]{64}$ && "$new_postgres_ref" =~ ^[^[:space:]]+@sha256:[a-f0-9]{64}$ && "$old_postgres_ref" != "$new_postgres_ref" ]] || { echo 'Explicit distinct digest-pinned old/new PostgreSQL artifacts are required' >&2; exit 2; }
[[ "$port" =~ ^1812[0-9]$ ]] || { echo 'Use an isolated port in 18120..18129' >&2; exit 2; }
for tool in docker openssl curl jq timeout; do command -v "$tool" >/dev/null; done
old_image="$(docker image inspect --format '{{.Id}}' "$old_ref")"
new_image="$(docker image inspect --format '{{.Id}}' "$new_ref")"
[[ "$old_image" != "$new_image" ]] || { echo 'Old and new must be distinct artifacts' >&2; exit 2; }
old_postgres_image="$(docker image inspect --format '{{.Id}}' "$old_postgres_ref")"
new_postgres_image="$(docker image inspect --format '{{.Id}}' "$new_postgres_ref")"
[[ "$old_postgres_image" != "$new_postgres_image" ]] || { echo 'Old and new PostgreSQL must be distinct artifacts' >&2; exit 2; }
project="rt-workhorse-upgrade-$$-$(openssl rand -hex 5)"
owner_label="io.tech-progress.workhorse-upgrade=${project}"
temporary="$(mktemp -d -t workhorse-upgrade.XXXXXXXX)"
mkdir -m 755 "${temporary}/state"
evidence="${root}/.verification/upgrade-${project}"
mkdir -m 700 -p "$evidence"
source_db="${project}-postgres"
restore_db="${project}-restore-postgres"
source_volume="${project}-source-data"
restore_volume="${project}-restore-data"
cleanup() {
  local status=$? cleanup_failed=0 temporary_removed=false container_id volume_name network_id
  trap - EXIT INT TERM
  set +e
  for container_id in $(docker ps -aq --filter "label=${owner_label}"); do
    if [[ "$(docker inspect --format '{{.State.Running}}' "$container_id")" == true ]]; then
      docker stop --time 5 "$container_id" >/dev/null || docker kill "$container_id" >/dev/null || cleanup_failed=1
    fi
    docker rm "$container_id" >/dev/null || cleanup_failed=1
  done
  for volume_name in $(docker volume ls -q --filter "label=${owner_label}"); do
    docker volume rm "$volume_name" >/dev/null || cleanup_failed=1
  done
  for network_id in $(docker network ls -q --filter "label=${owner_label}"); do
    docker network rm "$network_id" >/dev/null || cleanup_failed=1
  done
  local containers volumes networks
  containers="$(docker ps -aq --filter "label=${owner_label}" | wc -w)" || cleanup_failed=1
  volumes="$(docker volume ls -q --filter "label=${owner_label}" | wc -w)" || cleanup_failed=1
  networks="$(docker network ls -q --filter "label=${owner_label}" | wc -w)" || cleanup_failed=1
  [[ "$containers" == 0 && "$volumes" == 0 && "$networks" == 0 ]] || cleanup_failed=1
  if rm -r -- "$temporary"; then temporary_removed=true; else cleanup_failed=1; fi
  jq -n --argjson workflowExit "$status" --argjson cleanupFailure "$cleanup_failed" \
    --argjson containers "$containers" --argjson volumes "$volumes" --argjson networks "$networks" --argjson temporaryRemoved "$temporary_removed" \
    '{workflowExit:$workflowExit,cleanupFailure:$cleanupFailure,containers:$containers,volumes:$volumes,networks:$networks,secretsAndDumpsRetained:($temporaryRemoved|not)}' > "${evidence}/cleanup.json"
  if ((cleanup_failed)); then echo "Cleanup incomplete: ${evidence}/cleanup.json" >&2; exit 1; fi
  echo "Owned containers/volumes/networks: 0; temporary credentials/dumps removed. Evidence: ${evidence}"
  exit "$status"
}
trap cleanup EXIT
trap 'echo "Upgrade failed at script line ${LINENO}" >&2' ERR
trap 'exit 130' INT
trap 'exit 143' TERM
cat > "${temporary}/contract.mjs" <<'UPGRADE_CONTRACT'
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { Admin, Queue } from "@stablemates/workhorse";
import { connect } from "/app/app/database.mjs";

const pool = connect();
const queue = new Queue(pool);
const admin = new Admin(pool);
const action = process.argv[2];
async function until(operation) {
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    const value = await operation();
    if (value) return value;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error("Timed out waiting for native task/checkpoint state");
}
async function completed(taskId, key) {
  const task = await until(async () => {
    const current = await admin.getTask(taskId);
    return current?.state === "succeeded" && current;
  });
  assert.deepEqual(task.result, { key, completed: true });
  assert.equal((await pool.query("SELECT count(*)::int AS count FROM recipe.effects WHERE effect_key=$1 AND task_id=$2", [key, taskId])).rows[0].count, 1);
  assert.equal((await pool.query("SELECT count(*)::int AS count FROM recipe.effects WHERE effect_key=$1", [key])).rows[0].count, 1);
  assert.deepEqual((await admin.listCheckpoints(taskId)).map(checkpoint => checkpoint.name).sort(), ["effect", "prepared"]);
  return task;
}
async function snapshot(seed) {
  const taskIds = [seed.completedTaskId, seed.pendingTaskId];
  const rows = async (table, identity, order) => (await pool.query(`SELECT to_jsonb(entry) AS row FROM ${table} entry WHERE ${identity}=ANY($1::uuid[]) ORDER BY ${order}`, [taskIds])).rows.map(entry => entry.row);
  return {
    schemaVersions: (await pool.query("SELECT version FROM workhorse.schema_version ORDER BY version")).rows,
    tasks: await rows("workhorse.task", "id", "id"),
    runtime: await rows("workhorse.task_runtime", "task_id", "task_id"),
    outcomes: await rows("workhorse.task_outcome", "task_id", "task_id"),
    events: await rows("workhorse.task_event", "task_id", "to_jsonb(entry)::text"),
    checkpoints: await rows("workhorse.task_checkpoint", "task_id", "task_id, checkpoint_name"),
    effects: await rows("recipe.effects", "task_id", "effect_key"),
  };
}
try {
  if (action === "seed") {
    const completedKey = `upgrade_completed_${randomUUID()}`;
    const pendingKey = `upgrade_pending_${randomUUID()}`;
    const completedTaskId = await queue.enqueue("recipe.effect", { key: completedKey, failOnce: true, delayMs: 500 }, { maxAttempts: 4, retryPolicy: { type: "fixed", delayMs: 200 } });
    await completed(completedTaskId, completedKey);
    const pendingTaskId = await queue.enqueue("recipe.effect", { key: pendingKey, holdMs: 60_000 }, { maxAttempts: 4 });
    await until(async () => (await admin.listCheckpoints(pendingTaskId)).some(checkpoint => checkpoint.name === "prepared"));
    assert.equal((await admin.getTask(pendingTaskId)).state, "active");
    assert.equal((await pool.query("SELECT count(*)::int AS count FROM recipe.effects WHERE effect_key=$1", [pendingKey])).rows[0].count, 0);
    console.log(JSON.stringify({ completedTaskId, pendingTaskId, completedKey, pendingKey }));
  } else {
    const seed = JSON.parse(await readFile("/verification/seed.json", "utf8"));
    const before = action === "snapshot" ? null : JSON.parse(await readFile("/verification/before.json", "utf8"));
    if (action === "snapshot") {
      const current = await snapshot(seed);
      assert.deepEqual(current.schemaVersions, [{ version: 52 }]);
      assert.equal(current.tasks.length, 2);
      assert.ok(current.events.length >= 2);
      assert.equal(current.effects.length, 1);
      assert.equal(current.effects[0].task_id, seed.completedTaskId);
      assert.ok(current.runtime.some(task => task.task_id === seed.pendingTaskId && task.state === "active" && task.current_attempt === 1));
      assert.equal(current.checkpoints.filter(checkpoint => checkpoint.task_id === seed.pendingTaskId).length, 1);
      assert.ok(current.checkpoints.some(checkpoint => checkpoint.task_id === seed.pendingTaskId && checkpoint.checkpoint_name === "prepared" && checkpoint.checkpoint_value.key === seed.pendingKey));
      console.log(JSON.stringify(current));
    } else if (action === "installer-check") {
      assert.deepEqual(await snapshot(seed), before, "Installer must preserve populated old task/event/checkpoint/effect rows exactly");
      console.log(JSON.stringify({ action, populatedRowsPreserved: true, schema: 52 }));
    } else if (action === "recover") {
      await completed(seed.completedTaskId, seed.completedKey);
      const recovered = await completed(seed.pendingTaskId, seed.pendingKey);
      assert.ok(recovered.currentAttempt >= 2, "Pending old lease must recover, not complete before upgrade");
      const current = await snapshot(seed);
      for (const table of ["tasks", "events", "checkpoints", "effects"]) {
        for (const original of before[table]) assert.ok(current[table].some(row => JSON.stringify(row) === JSON.stringify(original)), `Original ${table} row lost or rewritten`);
      }
      const key = `upgrade_new_${randomUUID()}`;
      const taskId = await queue.enqueue("recipe.effect", { key, failOnce: true, delayMs: 500 }, { maxAttempts: 4, retryPolicy: { type: "fixed", delayMs: 200 } });
      await completed(taskId, key);
      assert.equal((await pool.query("SELECT count(*)::int AS count FROM recipe.effects")).rows[0].count, 3);
      console.log(JSON.stringify({ action, originalTaskIds: [seed.completedTaskId, seed.pendingTaskId], originalEvents: before.events.length, originalCheckpointsPreserved: true, originalEffectsExactlyOnce: true, recoveredAttempt: recovered.currentAttempt, newTaskId: taskId, newJobPassed: true, effectCount: 3 }));
    } else throw new Error(`Unknown upgrade action: ${action}`);
  }
} finally { await pool.end(); }
UPGRADE_CONTRACT
chmod 644 "${temporary}/contract.mjs"
version_check() {
  timeout 30 docker run --rm --pull never --network none --label "$owner_label" --entrypoint node "$1" \
    --input-type=module -e 'import assert from "node:assert/strict"; import {readFileSync} from "node:fs"; const versions={}; for(const name of ["@stablemates/workhorse","@stablemates/workhorse-dashboard"]){ const version=JSON.parse(readFileSync(`/app/node_modules/${name}/package.json`)).version; assert.equal(version,process.argv[1],name); versions[name]=version; } console.log(JSON.stringify(versions));' "$2"
}
version_check "$old_image" 0.6.0 > "${evidence}/old-versions.json"
version_check "$new_image" 0.6.1 > "${evidence}/new-versions.json"
postgres_version_check() {
  local output
  output="$(timeout 30 docker run --rm --pull never --network none --read-only --label "$owner_label" \
    --mount type=tmpfs,dst=/var/lib/postgresql/data --entrypoint postgres "$1" --version)"
  [[ "$output" == "postgres (PostgreSQL) $2" || "$output" == "postgres (PostgreSQL) $2 "* ]] || { echo "Unexpected PostgreSQL binary: ${output}" >&2; return 1; }
  printf '%s\n' "$output"
}
postgres_version_check "$old_postgres_image" 17.9 > "${evidence}/old-postgres-version.txt"
postgres_version_check "$new_postgres_image" 17.11 > "${evidence}/new-postgres-version.txt"
postgres_password="$(openssl rand -hex 24)"
dashboard_password="$(openssl rand -hex 24)"
cat > "${temporary}/database.env" <<ENV
POSTGRES_USER=workhorse
POSTGRES_DB=workhorse
POSTGRES_PASSWORD=${postgres_password}
PGDATA=/var/lib/postgresql/data/pgdata
ENV
app_environment() {
  cat > "$2" <<ENV
DATABASE_URL=postgresql://workhorse:${postgres_password}@$1:5432/workhorse
WORKHORSE_DASHBOARD_USERNAME=upgrade-operator
WORKHORSE_DASHBOARD_PASSWORD=${dashboard_password}
DASHBOARD_PUBLIC_ORIGIN=https://localhost:${port}
WORKER_CONCURRENCY=1
PORT=3000
ENV
}
app_environment "$source_db" "${temporary}/source.env"
app_environment "$restore_db" "${temporary}/restore.env"
printf 'user = "upgrade-operator:%s"\n' "$dashboard_password" > "${temporary}/dashboard.curl"
unset postgres_password dashboard_password
docker network create --label "$owner_label" "$project" >/dev/null
for volume in "$source_volume" "$restore_volume"; do docker volume create --label "$owner_label" "$volume" >/dev/null; done
start_database() {
  docker run -d --pull never --name "$1" --label "$owner_label" --network "$project" \
    --env-file "${temporary}/database.env" --mount "type=volume,src=$2,dst=/var/lib/postgresql/data" \
    --health-cmd 'pg_isready -U workhorse -d workhorse' --health-interval 2s --health-timeout 3s --health-retries 45 "$3" >/dev/null
  for attempt in $(seq 1 90); do
    [[ "$(docker inspect --format '{{.State.Health.Status}}' "$1")" != healthy ]] || return 0
    sleep 1
  done
  echo "Database readiness timed out: $1" >&2; return 1
}
install() {
  timeout 120 docker run --rm --pull never --label "$owner_label" --network "$project" --env-file "$2" "$1" node app/install.mjs
}
contract() {
  timeout 120 docker run --rm --pull never -i --label "$owner_label" --network "$project" --env-file "$2" \
    --mount "type=bind,src=${temporary}/state,dst=/verification,readonly" --workdir /app --entrypoint node "$1" \
    --input-type=module - "$3" < "${temporary}/contract.mjs"
}
schema_digest() {
  docker exec "$1" pg_dump -U workhorse -d workhorse --schema-only --no-owner --no-privileges \
    | sed '/^\\restrict /d; /^\\unrestrict /d' | openssl dgst -sha256
}
cluster_identity_and_roles() {
  docker exec "$1" psql -X -U workhorse -d workhorse -Atc \
    "SELECT jsonb_build_object('systemIdentifier',(SELECT system_identifier::text FROM pg_control_system()),'roles',(SELECT jsonb_agg(to_jsonb(role) - 'rolpassword' ORDER BY role.rolname) FROM pg_roles role),'memberships',(SELECT coalesce(jsonb_agg(to_jsonb(member) ORDER BY member.roleid,member.member,member.grantor),'[]'::jsonb) FROM pg_auth_members member));"
}
start_app() {
  local image="$1" env_file="$2" prefix="$3"
  docker run -d --pull never --name "${project}-${prefix}-worker" --label "$owner_label" --network "$project" --env-file "$env_file" "$image" node app/worker.mjs >/dev/null
  docker run -d --pull never --name "${project}-${prefix}-dashboard" --label "$owner_label" --network "$project" --env-file "$env_file" \
    -p "127.0.0.1:${port}:3000" "$image" node app/dashboard.mjs >/dev/null
  for service in worker dashboard; do
    local ready=false
    for attempt in $(seq 1 90); do
      if docker exec "${project}-${prefix}-${service}" node -e "fetch('http://localhost:3000/readyz').then(response=>process.exit(response.ok?0:1)).catch(()=>process.exit(1))" >/dev/null 2>&1; then ready=true; break; fi
      [[ "$(docker inspect --format '{{.State.Running}}' "${project}-${prefix}-${service}")" == true ]] || { echo "${prefix}-${service} exited" >&2; return 1; }
      sleep 1
    done
    [[ "$ready" == true ]] || { echo "${prefix}-${service} readiness timed out" >&2; return 1; }
  done
  local url="http://127.0.0.1:${port}/workhorse/"
  local anonymous_status wrong_status authenticated_status
  anonymous_status="$(curl --max-time 10 --silent --output /dev/null --write-out '%{http_code}' "$url")"
  wrong_status="$(curl --max-time 10 --silent -u upgrade-operator:invalid --output /dev/null --write-out '%{http_code}' "$url")"
  authenticated_status="$(curl --max-time 10 --silent --config "${temporary}/dashboard.curl" --output /dev/null --write-out '%{http_code}' "$url")"
  echo "${prefix} dashboard HTTP status: anonymous=${anonymous_status}, wrong=${wrong_status}, original-credentials=${authenticated_status}"
  [[ "$anonymous_status" == 401 && "$wrong_status" == 401 && "$authenticated_status" == 200 ]]
}
stop_app() {
  docker stop --time 25 "${project}-$1-worker" "${project}-$1-dashboard" >/dev/null
  [[ "$(docker inspect --format '{{.State.Running}}' "${project}-$1-worker")" == false ]]
  [[ "$(docker inspect --format '{{.State.Running}}' "${project}-$1-dashboard")" == false ]]
}
start_database "$source_db" "$source_volume" "$old_postgres_image"
old_source_db_id="$(docker inspect --format '{{.Id}}' "$source_db")"
install "$old_image" "${temporary}/source.env" > "${evidence}/old-install.log"
start_app "$old_image" "${temporary}/source.env" old
contract "$old_image" "${temporary}/source.env" seed > "${temporary}/state/seed.json"
chmod 644 "${temporary}/state/seed.json"
docker kill --signal SIGKILL "${project}-old-worker" >/dev/null
stop_app old
contract "$old_image" "${temporary}/source.env" snapshot > "${temporary}/state/before.json"
chmod 644 "${temporary}/state/before.json"
docker exec "$source_db" pg_dump -U workhorse -d workhorse -Fc > "${temporary}/pre-upgrade.dump"
[[ -s "${temporary}/pre-upgrade.dump" ]]
docker exec -i "$source_db" pg_restore --list < "${temporary}/pre-upgrade.dump" > "${evidence}/backup-contents.txt"
cluster_identity_and_roles "$source_db" > "${evidence}/source-cluster-before.json"
docker stop --time 60 "$source_db" >/dev/null
[[ "$(docker inspect --format '{{.State.Running}} {{.State.ExitCode}} {{.State.OOMKilled}}' "$source_db")" == 'false 0 false' ]]
docker logs --tail 30 "$source_db" > "${evidence}/old-postgres-shutdown.log" 2>&1
grep -F 'database system is shut down' "${evidence}/old-postgres-shutdown.log" >/dev/null
docker rm "$source_db" >/dev/null
start_database "$source_db" "$source_volume" "$new_postgres_image"
new_source_db_id="$(docker inspect --format '{{.Id}}' "$source_db")"
[[ "$new_source_db_id" != "$old_source_db_id" ]]
cluster_identity_and_roles "$source_db" > "${evidence}/source-cluster-after.json"
cmp "${evidence}/source-cluster-before.json" "${evidence}/source-cluster-after.json"
source_system_identifier="$(jq -r '.systemIdentifier' "${evidence}/source-cluster-before.json")"
[[ "$source_system_identifier" =~ ^[0-9]+$ ]]
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$source_db")" == "$source_volume" ]]
docker exec "$source_db" postgres --version > "${evidence}/running-new-postgres-version.txt"
install "$new_image" "${temporary}/source.env" > "${evidence}/new-install-once.log"
contract "$new_image" "${temporary}/source.env" installer-check > "${evidence}/same-database-preserved.json"
first_schema_digest="$(schema_digest "$source_db")"
install "$new_image" "${temporary}/source.env" > "${evidence}/new-install-idempotent-rerun.log"
[[ "$(schema_digest "$source_db")" == "$first_schema_digest" ]]
contract "$new_image" "${temporary}/source.env" installer-check > "${evidence}/installer-idempotence.json"
[[ "$(docker inspect --format '{{.Id}}' "$source_db")" == "$new_source_db_id" ]]
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$source_db")" == "$source_volume" ]]
start_app "$new_image" "${temporary}/source.env" new
contract "$new_image" "${temporary}/source.env" recover > "${evidence}/same-database-recovery.json"
stop_app new
start_database "$restore_db" "$restore_volume" "$new_postgres_image"
[[ "$source_volume" != "$restore_volume" ]]
cluster_identity_and_roles "$restore_db" > "${evidence}/restore-cluster.json"
restore_system_identifier="$(jq -r '.systemIdentifier' "${evidence}/restore-cluster.json")"
[[ "$restore_system_identifier" =~ ^[0-9]+$ && "$restore_system_identifier" != "$source_system_identifier" ]]
[[ "$(docker exec "$restore_db" psql -U workhorse -d workhorse -Atc "SELECT count(*) FROM pg_namespace WHERE nspname IN ('workhorse','recipe')")" == 0 ]]
docker exec -i "$restore_db" pg_restore --exit-on-error -U workhorse -d workhorse --no-owner < "${temporary}/pre-upgrade.dump"
contract "$new_image" "${temporary}/restore.env" installer-check > "${evidence}/fresh-restore-before-install.json"
install "$new_image" "${temporary}/restore.env" > "${evidence}/restore-install-once.log"
contract "$new_image" "${temporary}/restore.env" installer-check > "${evidence}/fresh-restore-installed.json"
start_app "$new_image" "${temporary}/restore.env" restored
contract "$new_image" "${temporary}/restore.env" recover > "${evidence}/fresh-restore-recovery.json"
stop_app restored
[[ "$(docker image inspect --format '{{.Id}}' "$old_ref")" == "$old_image" ]]
[[ "$(docker image inspect --format '{{.Id}}' "$new_ref")" == "$new_image" ]]
[[ "$(docker image inspect --format '{{.Id}}' "$old_postgres_ref")" == "$old_postgres_image" ]]
[[ "$(docker image inspect --format '{{.Id}}' "$new_postgres_ref")" == "$new_postgres_image" ]]
cp "${temporary}/state/seed.json" "${temporary}/state/before.json" "$evidence/"
jq -n --arg project "$project" --arg oldImage "$old_image" --arg newImage "$new_image" \
  --arg oldPostgresRef "$old_postgres_ref" --arg newPostgresRef "$new_postgres_ref" --arg oldPostgresImage "$old_postgres_image" --arg newPostgresImage "$new_postgres_image" \
  --arg oldSourceContainer "$old_source_db_id" --arg newSourceContainer "$new_source_db_id" --arg sourceSystemIdentifier "$source_system_identifier" --arg restoreSystemIdentifier "$restore_system_identifier" \
  --arg sourceVolume "$source_volume" --arg restoreVolume "$restore_volume" \
  '{project:$project,oldImage:$oldImage,newImage:$newImage,oldPostgresRef:$oldPostgresRef,newPostgresRef:$newPostgresRef,oldPostgresImage:$oldPostgresImage,newPostgresImage:$newPostgresImage,oldSourceContainer:$oldSourceContainer,newSourceContainer:$newSourceContainer,sourceSystemIdentifier:$sourceSystemIdentifier,restoreSystemIdentifier:$restoreSystemIdentifier,sourceVolume:$sourceVolume,restoreVolume:$restoreVolume,oldVersion:"0.6.0",newVersion:"0.6.1",oldPostgresVersion:"17.9",newPostgresVersion:"17.11",sameDatabase:true,sameClusterAndVolume:true,postgresContainerReplaced:true,postgresStoppedGracefully:true,rolesPreserved:true,preUpgradeBackupRestorePassed:true,sourceInstallerExecutions:2,secondInstallerIsExplicitIdempotenceTest:true,originalCredentialsPreserved:true,dashboardAuthenticatedBeforeAndAfter:true,stopBeforeReplace:true,noDownMigrationClaim:true,localOnly:true}' > "${evidence}/result.json"
echo 'Upgrade workflow PASS: populated Workhorse0.6.0/PostgreSQL17.9 -> Workhorse0.6.1/PostgreSQL17.11, same cluster/volume/roles, original credentials/task/event/checkpoint/effect continuity, new jobs, and distinct fresh-volume backup restore.'
