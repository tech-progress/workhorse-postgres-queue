import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

test("distributed docs match the template candidate and upstream pins without private links", () => {
  const root = new URL("../", import.meta.url);
  const version = readFileSync(new URL("VERSION", root), "utf8").trim();
  const manifest = JSON.parse(readFileSync(new URL("package.json", root)));
  const upstreamVersion = manifest.dependencies["@stablemates/workhorse"];
  const databaseImage = readFileSync(new URL("compose.yaml", root), "utf8").match(/^\s+image: (postgres:[^\n]+)$/m)[1];
  const databaseVersion = databaseImage.match(/^postgres:([\d.]+)-/)[1];
  assert.ok(readFileSync(new URL(".railway/railway.ts", root), "utf8").includes(`"${databaseImage}"`));
  const readme = readFileSync(new URL("README.md", root), "utf8");
  const upgrade = readFileSync(new URL("UPGRADE.md", root), "utf8");
  assert.ok(readme.includes(`v${version}`));
  assert.ok(upgrade.includes(`currently ${version}`));
  for (const filename of ["README.md", "MARKETPLACE.md"]) {
    const document = readFileSync(new URL(filename, root), "utf8");
    assert.ok(document.includes(`Workhorse SDK ${upstreamVersion}`));
    assert.ok(document.includes(`PostgreSQL ${databaseVersion}`));
  }
  for (const filename of ["README.md", "PUBLISHING.md", "UPGRADE.md", "SUPPORT.md", "LICENSE_REVIEW.md", "THIRD_PARTY_NOTICES.md"]) {
    const document = readFileSync(new URL(filename, root), "utf8");
    for (const match of document.matchAll(/\]\(([^)]+)\)/g)) {
      const target = match[1].split("#")[0];
      if (!target || /^[a-z]+:/i.test(target)) continue;
      assert.ok(!target.includes("FINDINGS.md") && !target.includes(".verification"), `${filename}: private link ${target}`);
      assert.ok(existsSync(new URL(target, root)), `${filename}: missing document ${target}`);
    }
  }
});
