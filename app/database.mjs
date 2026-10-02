import { Pool, assertSchemaCompatible } from "@stablemates/workhorse";

export function connect() {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is required");
  return new Pool({ connectionString: process.env.DATABASE_URL, max: 8 });
}

export async function ready(pool) {
  const deadline = Date.now() + 120_000;
  while (true) {
    try {
      await assertSchemaCompatible(pool);
      return;
    } catch (error) {
      if (Date.now() >= deadline) throw error;
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}
