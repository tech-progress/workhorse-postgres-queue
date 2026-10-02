import { installSchema } from "@stablemates/workhorse";
import { connect } from "./database.mjs";

const pool = connect();
try {
  await installSchema(pool);
  await pool.query(`CREATE SCHEMA IF NOT EXISTS recipe;
    CREATE TABLE IF NOT EXISTS recipe.effects (
      effect_key text PRIMARY KEY,
      task_id uuid NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
  console.log("Workhorse schema and idempotent fixture installed");
} finally {
  await pool.end();
}
