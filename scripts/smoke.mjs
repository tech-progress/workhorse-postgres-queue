import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { Admin, Queue } from "@stablemates/workhorse";
import { connect } from "../app/database.mjs";

const pool = connect();
const queue = new Queue(pool);
const admin = new Admin(pool);
const action = process.argv[2] || "normal";
const key = process.argv[3] || randomUUID();
async function until(operation) {
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    const value = await operation();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("Timed out waiting for durable task state");
}
try {
  if (action === "enqueue-crash") {
    const taskId = await queue.enqueue("recipe.effect", { key, holdMs: 60_000 }, { maxAttempts: 4 });
    await until(async () => (await admin.listCheckpoints(taskId)).some((item) => item.name === "prepared"));
    console.log(taskId);
  } else if (action === "check") {
    const task = await until(async () => { const value = await admin.getTask(key); return value?.state === "succeeded" && value; });
    const effects = await pool.query("SELECT count(*)::int AS count FROM recipe.effects WHERE effect_key=$1", [task.payload.key]);
    assert.equal(effects.rows[0].count, 1);
    assert.ok((await admin.listCheckpoints(key)).some((item) => item.name === "prepared"));
    console.log("Lease recovery, checkpoint continuity and exactly one database effect passed");
  } else {
    const taskId = await queue.enqueue("recipe.effect", { key, failOnce: true, delayMs: 1500 }, { maxAttempts: 4, retryPolicy: { type: "fixed", delayMs: 500 } });
    const task = await until(async () => { const value = await admin.getTask(taskId); return value?.state === "succeeded" && value; });
    assert.deepEqual(task.result, { key, completed: true });
    assert.equal((await pool.query("SELECT count(*)::int AS count FROM recipe.effects WHERE effect_key=$1", [key])).rows[0].count, 1);
    assert.equal((await admin.listCheckpoints(taskId)).length, 2);
    console.log("Fail-once retry, durable delay and idempotent effect passed");
  }
} finally { await pool.end(); }
