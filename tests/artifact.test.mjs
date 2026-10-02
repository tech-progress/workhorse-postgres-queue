import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

test("artifact pins build/rootfs inputs and flattens the cleaned runtime", () => {
  const dockerfile = readFileSync(new URL("../Dockerfile", import.meta.url), "utf8");
  const pinned = "node:24.20.0-bookworm-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e";
  assert.deepEqual(dockerfile.match(/^FROM .+$/gm), [
    `FROM ${pinned} AS dependencies`,
    `FROM ${pinned} AS runtime-files`,
    "FROM scratch AS runtime",
  ]);
  assert.match(dockerfile, /npm ci --omit=dev --ignore-scripts --registry=https:\/\/registry\.npmjs\.org/);
  assert.match(dockerfile, /COPY --from=runtime-files \/ \//);
  assert.match(dockerfile, /COPY --from=dependencies \/app \/app/);
  assert.match(dockerfile, /COPY LICENSE THIRD_PARTY_NOTICES\.md/);
  assert.match(dockerfile, /apt-get install -y --no-install-recommends libpcre2-8-0=10\.42-1\+deb12u1/);
});

test("SDK, dashboard and their bundled contract/server use the same exact Workhorse release", () => {
  const manifest = JSON.parse(readFileSync(new URL("../package.json", import.meta.url)));
  const lock = JSON.parse(readFileSync(new URL("../package-lock.json", import.meta.url)));
  for (const name of ["workhorse", "workhorse-dashboard", "workhorse-dashboard-server", "workhorse-dashboard-contract"]) {
    const packageName = `@stablemates/${name}`;
    if (name === "workhorse" || name === "workhorse-dashboard") assert.equal(manifest.dependencies[packageName], "0.6.1");
    assert.equal(lock.packages[`node_modules/${packageName}`].version, "0.6.1");
    assert.match(lock.packages[`node_modules/${packageName}`].integrity, /^sha512-/);
  }
});
