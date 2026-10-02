import { createWorkhorseAdapter, runWorkerProcess } from "@stablemates/workhorse";
import { connect, ready } from "./database.mjs";
import { fixture } from "./fixture.mjs";

const pool = connect();
await ready(pool);
const concurrency = Number(process.env.WORKER_CONCURRENCY || 2);
if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 4) throw new Error("WORKER_CONCURRENCY must be 1-4");
await runWorkerProcess({
  adapter: () => createWorkhorseAdapter({ database: pool, adaptTransaction: (transaction) => transaction, close: () => pool.end() }),
  workers: [{
    options: { concurrency, leaseMs: 8000, heartbeatMs: 2000, pollMs: 250, maintenanceIntervalMs: 1000 },
    configure: (worker) => worker.handle("recipe.effect", fixture(pool)),
  }],
  probes: { hostname: "::", port: Number(process.env.PORT || 3000) },
  shutdownTimeoutMs: 20_000,
});
