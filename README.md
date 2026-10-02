# Workhorse PostgreSQL queue

Upstream products: [Workhorse](https://workhorse.run/) · [PostgreSQL](https://www.postgresql.org/).

The current template release is `v1.0.0`. This is an **unpublished recipe** pending live Railway qualification. Original recipe code is MIT; upstream Workhorse and PostgreSQL keep their own licenses and notices.

## What deploys

Three independently deployed services: PostgreSQL 17.9, a Node.js 24 worker with Workhorse SDK 0.6.0, and the matching read-only dashboard. No Redis, broker, shared service disk, Docker socket, or public database. Workhorse is public beta; this is an evaluation/small-team queue recipe, not an exactly-once or HA guarantee.

The worker's pre-deploy command installs Workhorse's ordered schema plus the recipe effect table. Runtime worker/dashboard processes only assert schema compatibility. Dashboard startup waits for the schema gate. Run the pre-deploy installer once per release, not from each worker replica; migrations require the database to already be available.

The task `recipe.effect` validates bounded input, deliberately fails once, saves a named preparation checkpoint, performs a lease-releasing durable wait, and writes one uniquely keyed database effect. A checkpoint callback can execute again after a crash between its effect and checkpoint write: SQL's unique key makes this fixture safe. External providers still need stable idempotency keys.

## Railway setup

1. Deploy PostgreSQL first, then Worker with `node app/install.mjs` as its pre-deploy command. The image starts `node app/worker.mjs`.
2. Deploy Dashboard with `node app/dashboard.mjs`; publish HTTP target port 3000 and set its HTTPS public origin. Worker port 3000 is probe-only; leave it private.
3. Open `https://YOUR_DOMAIN/workhorse/` using the generated operator credentials. The embedded upstream dashboard is read-only and uses HTTP Basic authentication on all dashboard assets and RPCs; readiness alone is unauthenticated and payload-free. Only use Basic over Railway HTTPS. The template supports a precomputed upstream-compatible `WORKHORSE_DASHBOARD_PASSWORD_HASH` instead of the raw secret; the hash takes precedence. Changing either credential requires a deployment. The wrapper caps failed Basic attempts globally at 20 per minute and includes the upstream-recommended CSP; use an identity-aware proxy/embedded authorization integration for SSO, roles, distributed throttling or multi-user access.
4. Submit through a private application or Railway SSH, not a public enqueue API. For example, use `Queue.enqueue("recipe.effect", { key: "order-42", failOnce: true, delayMs: 1500 }, { maxAttempts: 4, retryPolicy: { type: "fixed", delayMs: 500 } })` from the installed SDK.
5. The `holdMs` fixture is for crash testing only (bounded to 60 seconds); worker lease 8 seconds, heartbeat 2 seconds, maintenance 1 second. Do not treat these test-oriented timings as capacity tuning.

## Source prerequisites

The public distribution source is `tech-progress/workhorse-postgres-queue`, with compatibility channel `release-v1`, immutable release tag `v1.0.0`, and root directory `/`. `.railway/railway.ts` uses that source by default. Marketplace users should retain the upstream release source; fork maintainers must change `SOURCE_REPO` to their repository, create a slash-free release channel and authorize the Railway GitHub App. These are authoring settings, not runtime secrets. The graph deliberately retains platform secret expressions; do not apply it literally to a running source project. Disposable source probes must generate cryptographically random credentials once and preserve them.

## Runtime variables

Every default below is documented; descriptions in template-descriptions.json match exactly. Database references use private DNS and generated alphanumeric passwords, avoiding URL-encoding ambiguity. Custom DSN credentials must be URL-encoded. Do not paste resolved secrets into metadata or commit local .env files.

| Service | Variable | Default kind/value | Meaning |
| --- | --- | --- | --- |
| Postgres | `PORT` | `5432` | Internal listener/probe target port; do not expose private services. |
| Postgres | `POSTGRES_DB` | `workhorse` | Durable queue database name. |
| Postgres | `POSTGRES_USER` | `workhorse` | Database owner for schema installation; isolate from other applications. |
| Postgres | `POSTGRES_PASSWORD` | Generated secret | Generated alphanumeric database credential, referenced by applications. |
| Postgres | `PGDATA` | `/var/lib/postgresql/data/pgdata` | PostgreSQL cluster subdirectory on its exclusive volume. |
| Worker | `PORT` | `3000` | Internal listener/probe target port; do not expose private services. |
| Worker | `DATABASE_URL` | Service reference | Direct private PostgreSQL connection using service references; no public database endpoint. |
| Worker | `WORKER_CONCURRENCY` | `2` | Bounded process concurrency, integer 1-4; default 2 with an eight-connection pool. |
| Dashboard | `PORT` | `3000` | Internal listener/probe target port; do not expose private services. |
| Dashboard | `DATABASE_URL` | Service reference | Direct private PostgreSQL connection using service references; no public database endpoint. |
| Dashboard | `WORKHORSE_DASHBOARD_USERNAME` | `operator` | Single read-only operator username. |
| Dashboard | `WORKHORSE_DASHBOARD_PASSWORD` | Generated secret | Generated administrator password (minimum 16 characters); hashed in memory before authentication. |
| Dashboard | `DASHBOARD_PUBLIC_ORIGIN` | Service reference | HTTPS public dashboard origin for upstream host/origin protection. |

`.env.example` documents local-only DASHBOARD_PORT (18100), worker concurrency and the HTTPS origin. Optional WORKHORSE_DASHBOARD_PASSWORD_HASH overrides the raw password using upstream scrypt-v1 format; set it only as a secret, never in metadata. Unknown optional upstream variables are outside this recipe's tested contract.

## Local build and smoke

Run inside this directory. Never use global Docker cleanup. Compose publishes only loopback ports in the 18100–18119 allocation.

```bash
export POSTGRES_PASSWORD="$(openssl rand -hex 16)"
export WORKHORSE_DASHBOARD_PASSWORD="$(openssl rand -hex 16)"
docker compose -p my-workhorse up --build -d
COMPOSE_PROJECT_NAME=my-workhorse bash scripts/smoke.sh
# Local HTTP is loopback-only; the configured HTTPS origin is production-shaped.
# Open http://localhost:18100/workhorse/ for local Basic-auth testing.
# Remove only this stack when done:
docker compose -p my-workhorse down -v
```

Install authoring dependencies with `npm ci --ignore-scripts`, then run `bash scripts/verify.sh`. Hatchet also uses `uv sync --frozen`; no global tool installation is performed. `scripts/local-smoke.sh` owns a unique Compose project and removes only its containers/volumes in an EXIT trap. `scripts/smoke.sh` tests an already-running stack without deleting it.

## State, backups and restore

The exclusive Postgres volume holds tasks, attempts, checkpoints, durable waits, retention policies, worker registration, and `recipe.effects`. Dashboard and Worker are stateless. Back up PostgreSQL with `pg_dump -Fc` plus securely recorded application variables. Stop workers during a consistency-sensitive restore. Restore into a fresh compatible cluster using `pg_restore --no-owner`, point both application services at it, assert schema compatibility, and enqueue/recover a previously pending task before resuming traffic. Retain idempotency rows at least as long as task replay can occur. Do not copy a live PGDATA directory.

`scripts/local-smoke.sh` creates only its own isolated stack and performs real fail-once/delay, SIGKILL lease recovery, and a dump/restore into a second database with a pending checkpointed task. This is logical single-node restore qualification, not PITR/HA qualification.

## Security and support boundary

If readiness waits, check PostgreSQL and the pre-deploy schema job; do not add runtime auto-migrations. If the dashboard returns 401, check the configured operator/hash and redeploy after rotation; 404 at / is expected, use /workhorse/. If tasks do not move, confirm the registered worker, matching task type, paused state and concurrency. Recovering a killed worker takes at least a lease expiry plus maintenance. Inspect dead letters before redrive. Never paste DATABASE_URL, task payloads, credentials or dumps into support issues.

No HA, production capacity, arbitrary untrusted workloads, exactly-once external delivery or indefinite retention claim is made. Keep internal databases, workers, health ports and gRPC private. Use Railway TLS for all public authenticated endpoints. See SUPPORT.md and UPGRADE.md.
