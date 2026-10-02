import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import test from "node:test";

const scriptPath = new URL("../scripts/upgrade-smoke.sh", import.meta.url);
const script = readFileSync(scriptPath, "utf8");
const run = argumentsList => spawnSync("bash", [scriptPath.pathname, ...argumentsList], { encoding: "utf8", timeout: 10_000 });
const explicitArtifacts = ["--old-image", "old", "--new-image", "new", "--old-postgres-image", `postgres:17.9@sha256:${"1".repeat(64)}`, "--new-postgres-image", `postgres:17.11@sha256:${"2".repeat(64)}`];

test("upgrade harness requires explicit distinct artifacts and bounded isolated ports before Docker", () => {
  const help = run(["--help"]);
  assert.equal(help.status, 0);
  assert.match(help.stdout, /FROZEN_0\.6\.0.*BUILT_0\.6\.1/);
  for (const argumentsList of [
    [], ["--old-image"], ["--old-image", "old"],
    ["--old-image", "old", "--new-image", "old"],
    ["--old-image", "old", "--new-image", "new"],
    [...explicitArtifacts, "--port", "18119"],
    [...explicitArtifacts, "--port", "18130"],
    [...explicitArtifacts, "--port", "not-a-port"],
    ["--old-image", "old", "--new-image", "new", "--old-postgres-image", "postgres:17.9", "--new-postgres-image", "postgres:17.11"],
    ["--unknown-option"],
  ]) assert.equal(run(argumentsList).status, 2, JSON.stringify(argumentsList));
  assert.equal(spawnSync("bash", ["-n", scriptPath.pathname]).status, 0);
});

test("upgrade contract pins actual old/new package versions without rebuilding or mutating images", () => {
  assert.match(script, /version_check "\$old_image" 0\.6\.0/);
  assert.match(script, /version_check "\$new_image" 0\.6\.1/);
  assert.match(script, /\["@stablemates\/workhorse","@stablemates\/workhorse-dashboard"\]/);
  assert.match(script, /assert\.equal\(version,process\.argv\[1\],name\)/);
  assert.match(script, /Old and new must be distinct artifacts/);
  assert.match(script, /docker image inspect --format '\{\{\.Id\}\}' "\$old_ref"/);
  assert.doesNotMatch(script, /docker (?:build|pull|tag|push)|docker image rm|docker (?:system|volume) prune|railway |gh |git (?:push|commit)/);
});

test("old native worker genuinely populates checkpoints and quiesced backup precedes installer", () => {
  assert.match(script, /await queue\.enqueue\("recipe\.effect", \{ key: pendingKey, holdMs: 60_000 \}/);
  assert.match(script, /assert\.equal\(\(await admin\.getTask\(pendingTaskId\)\)\.state, "active"\)/);
  assert.match(script, /current_attempt === 1/);
  assert.match(script, /checkpoint\.checkpoint_value\.key === seed\.pendingKey/);
  assert.match(script, /assert\.equal\(current\.effects\.length, 1\)/);
  assert.match(script, /docker kill --signal SIGKILL "\$\{project\}-old-worker"/);
  const oldStop = script.indexOf("stop_app old\n");
  const backup = script.indexOf('pg_dump -U workhorse -d workhorse -Fc > "${temporary}/pre-upgrade.dump"');
  const newInstall = script.indexOf('install "$new_image" "${temporary}/source.env"');
  const newStart = script.indexOf('start_app "$new_image" "${temporary}/source.env" new');
  assert.ok(oldStop > 0 && backup > oldStop && newInstall > backup && newStart > newInstall);
  assert.equal(script.match(/install "\$new_image" "\$\{temporary\}\/source\.env"/g).length, 2);
  assert.match(script, /schema_digest "\$source_db"\)" == "\$first_schema_digest"/);
  assert.match(script, /node app\/install\.mjs/);
  assert.match(script, /node app\/worker\.mjs/);
  assert.match(script, /node app\/dashboard\.mjs/);
});

test("continuity covers original SQL rows/events, exactly-once effects, same database and original auth", () => {
  for (const table of ["workhorse.task", "workhorse.task_runtime", "workhorse.task_outcome", "workhorse.task_event", "workhorse.task_checkpoint", "recipe.effects"]) assert.ok(script.includes(`"${table}"`), table);
  assert.match(script, /assert\.deepEqual\(await snapshot\(seed\), before/);
  assert.match(script, /for \(const original of before\[table\]\)/);
  assert.match(script, /recovered\.currentAttempt >= 2/);
  assert.doesNotMatch(script, /recovered\.attempt/);
  assert.match(script, /effect_key=\$1 AND task_id=\$2/);
  assert.match(script, /await completed\(seed\.completedTaskId, seed\.completedKey\)/);
  assert.match(script, /await completed\(seed\.pendingTaskId, seed\.pendingKey\)/);
  assert.match(script, /const key = `upgrade_new_\$\{randomUUID\(\)\}`/);
  assert.match(script, /source_db"\)" == "\$new_source_db_id"/);
  assert.equal(script.match(/dashboard_password="\$\(openssl rand -hex 24\)"/g).length, 1);
  assert.match(script, /--config "\$\{temporary\}\/dashboard\.curl"/);
  assert.match(script, /upgrade-operator:invalid/);
  assert.match(script, /-p "127\.0\.0\.1:\$\{port\}:3000"/);
});

test("restore uses independently empty storage and cleanup only owns uniquely labelled resources", () => {
  assert.match(script, /source_volume="\$\{project\}-source-data"/);
  assert.match(script, /restore_volume="\$\{project\}-restore-data"/);
  assert.match(script, /count\(\*\) FROM pg_namespace WHERE nspname IN \('workhorse','recipe'\)/);
  assert.match(script, /pg_restore --exit-on-error/);
  assert.match(script, /fresh-restore-before-install\.json/);
  assert.match(script, /fresh-restore-recovery\.json/);
  assert.match(script, /docker network create --label "\$owner_label" "\$project"/);
  for (const query of ["docker ps -aq", "docker volume ls -q", "docker network ls -q"]) assert.ok(script.includes(`${query} --filter "label=\${owner_label}"`));
  assert.match(script, /rm -r -- "\$temporary"/);
  assert.doesNotMatch(script, /docker (?:rm|stop|kill) \$\(docker ps -[aq]+\)/);
  assert.match(script, /noDownMigrationClaim:true,localOnly:true/);
});

test("embedded native upgrade helper has valid ESM syntax independently of an image", () => {
  const embedded = script.match(/<<'UPGRADE_CONTRACT'\n([\s\S]*?)\nUPGRADE_CONTRACT/);
  assert.ok(embedded);
  const checked = spawnSync(process.execPath, ["--input-type=module", "--check"], { input: embedded[1], encoding: "utf8" });
  assert.equal(checked.status, 0, checked.stderr);
});

test("cleanup receipt uses supplied variables rather than null jq input fields", () => {
  const expression = script.match(/'(\{workflowExit:\$workflowExit,[^\n]+\})'/);
  assert.ok(expression);
  const receipt = spawnSync("jq", ["-n", "--argjson", "workflowExit", "1", "--argjson", "cleanupFailure", "0", "--argjson", "containers", "0", "--argjson", "volumes", "0", "--argjson", "networks", "0", "--argjson", "temporaryRemoved", "true", expression[1]], { encoding: "utf8" });
  assert.equal(receipt.status, 0, receipt.stderr);
  assert.deepEqual(JSON.parse(receipt.stdout), { workflowExit: 1, cleanupFailure: 0, containers: 0, volumes: 0, networks: 0, secretsAndDumpsRetained: false });
  assert.match(script, /project:\$project,oldImage:\$oldImage,newImage:\$newImage/);
});

test("combined PostgreSQL patch transition preserves cluster/volume/roles while replacing the container", () => {
  assert.match(script, /postgres_version_check "\$old_postgres_image" 17\.9/);
  assert.match(script, /postgres_version_check "\$new_postgres_image" 17\.11/);
  assert.match(script, /--network none --read-only/);
  assert.match(script, /system_identifier::text FROM pg_control_system\(\)/);
  assert.match(script, /to_jsonb\(role\) - 'rolpassword'/);
  assert.match(script, /pg_auth_members/);
  assert.match(script, /cmp "\$\{evidence\}\/source-cluster-before\.json" "\$\{evidence\}\/source-cluster-after\.json"/);
  assert.match(script, /new_source_db_id" != "\$old_source_db_id"/);
  assert.match(script, /restore_system_identifier" != "\$source_system_identifier"/);
  assert.match(script, /start_database "\$restore_db" "\$restore_volume" "\$new_postgres_image"/);
  const backup = script.indexOf('pg_dump -U workhorse -d workhorse -Fc > "${temporary}/pre-upgrade.dump"');
  const stop = script.indexOf('docker stop --time 60 "$source_db"');
  const replacement = script.indexOf('start_database "$source_db" "$source_volume" "$new_postgres_image"');
  const install = script.indexOf('install "$new_image" "${temporary}/source.env"');
  assert.ok(backup > 0 && stop > backup && replacement > stop && install > replacement);
  assert.match(script, /false 0 false/);
  assert.match(script, /database system is shut down/);
  assert.match(script, /postgresStoppedGracefully:true,rolesPreserved:true/);
});
