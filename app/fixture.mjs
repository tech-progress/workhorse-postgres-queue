export function validatePayload(payload) {
  if (!payload || typeof payload.key !== "string" || !/^[a-zA-Z0-9_-]{1,100}$/.test(payload.key)) {
    throw new Error("key must be 1-100 alphanumeric, dash or underscore characters");
  }
  if (payload.delayMs !== undefined && (!Number.isInteger(payload.delayMs) || payload.delayMs < 0 || payload.delayMs > 60_000)) {
    throw new Error("delayMs must be an integer between 0 and 60000");
  }
  if (payload.holdMs !== undefined && (!Number.isInteger(payload.holdMs) || payload.holdMs < 0 || payload.holdMs > 60_000)) {
    throw new Error("holdMs must be an integer between 0 and 60000");
  }
  if (payload.failOnce !== undefined && typeof payload.failOnce !== "boolean") throw new Error("failOnce must be boolean");
  return payload;
}

export function fixture(pool) {
  return async (payload, context) => {
    validatePayload(payload);
    const prepared = await context.checkpoint("prepared", () => ({ key: payload.key }));
    if (payload.failOnce && context.task.attempt === 1) throw new Error("Intentional first-attempt failure");
    if (payload.holdMs && context.task.attempt === 1) {
      await new Promise((resolve) => setTimeout(resolve, payload.holdMs));
    }
    if (payload.delayMs) await context.sleep("delay", payload.delayMs);
    await context.checkpoint("effect", async () => {
      await pool.query("INSERT INTO recipe.effects(effect_key, task_id) VALUES ($1, $2) ON CONFLICT (effect_key) DO NOTHING", [prepared.key, context.task.id]);
      return { key: prepared.key };
    });
    return { key: prepared.key, completed: true };
  };
}
