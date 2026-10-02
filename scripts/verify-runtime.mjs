import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

assert.equal(process.versions.node, "24.20.0");
assert.equal(execFileSync("dpkg-query", ["-W", "-f=${Version}", "libpcre2-8-0"], { encoding: "utf8" }), "10.42-1+deb12u1");
for (const path of [
  "/usr/local/lib/node_modules",
  "/opt/yarn-v1.22.22",
  "/usr/local/bin/npm",
  "/usr/local/bin/npx",
  "/usr/local/bin/yarn",
  "/usr/local/bin/yarnpkg",
  "/usr/local/bin/corepack",
  "/usr/local/bin/pnpm",
  "/usr/local/bin/pnpx",
]) assert.equal(existsSync(path), false, `Unneeded runtime tool remains: ${path}`);
for (const path of [
  "/usr/local/LICENSE",
  "/usr/local/share/licenses/build-tools/npm-LICENSE.txt",
  "/usr/local/share/licenses/build-tools/yarn-LICENSE.txt",
  "/usr/share/doc/libc6/copyright",
  "/usr/share/doc/libstdc++6/copyright",
  "/app/LICENSE",
  "/app/THIRD_PARTY_NOTICES.md",
]) assert.ok(readFileSync(path).length > 0, `Required notice missing: ${path}`);
for (const name of ["workhorse", "workhorse-dashboard", "workhorse-dashboard-server", "workhorse-dashboard-contract"]) {
  const pkg = JSON.parse(readFileSync(`/app/node_modules/@stablemates/${name}/package.json`));
  assert.equal(pkg.version, "0.6.1");
}
console.log("Workhorse 0.6.1, Node 24.20, PCRE2 patch, removed package-manager payload and retained notices passed");
