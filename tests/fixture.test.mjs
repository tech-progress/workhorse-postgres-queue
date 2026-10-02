import test from "node:test";
import assert from "node:assert/strict";
import { validatePayload } from "../app/fixture.mjs";
import { hashPassword, verifyPassword } from "../app/auth.mjs";

test("bounded validated task input", () => {
  assert.deepEqual(validatePayload({ key: "safe-key", delayMs: 10 }), { key: "safe-key", delayMs: 10 });
  for (const payload of [{}, { key: "../../bad" }, { key: "ok", delayMs: 60001 }, { key: "ok", holdMs: -1 }, { key: "ok", failOnce: "yes" }]) assert.throws(() => validatePayload(payload));
});
test("dashboard hashes reject incorrect credentials and malformed hashes", () => {
  const hash = hashPassword("long-fixture-password");
  assert.equal(verifyPassword("long-fixture-password", hash), true);
  assert.equal(verifyPassword("incorrect", hash), false);
  assert.throws(() => verifyPassword("anything", "broken"));
});
