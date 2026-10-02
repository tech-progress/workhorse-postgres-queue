# Deploy and Host Workhorse PostgreSQL queue on Railway

PostgreSQL durable tasks with crash recovery and protected dashboard.

## About Hosting Workhorse PostgreSQL queue

Three independently deployed services: PostgreSQL 17.9, a Node.js 24 worker with Workhorse SDK 0.6.0, and the matching read-only dashboard. No Redis, broker, shared service disk, Docker socket, or public database. Workhorse is public beta; this is an evaluation/small-team queue recipe, not an exactly-once or HA guarantee.

The worker's pre-deploy command installs Workhorse's ordered schema plus the recipe effect table. Runtime worker/dashboard processes only assert schema compatibility. Dashboard startup waits for the schema gate. Run the pre-deploy installer once per release, not from each worker replica; migrations require the database to already be available.

The task `recipe.effect` validates bounded input, deliberately fails once, saves a named preparation checkpoint, performs a lease-releasing durable wait, and writes one uniquely keyed database effect. A checkpoint callback can execute again after a crash between its effect and checkpoint write: SQL's unique key makes this fixture safe. External providers still need stable idempotency keys.

## Why Deploy Workhorse PostgreSQL queue on Railway

Independent service lifecycles, explicit private networking, generated credentials and exclusive persistent volumes provide a reproducible low-volume evaluation. Authentication protects workload endpoints; this is not an HA production claim.

## Common Use Cases

- Evaluate the upstream product with a real authenticated workflow.
- Exercise persistence, retries/replay and operational recovery before adoption.
- Extend the included bounded fixture without exposing internal backends.

## Dependencies for Workhorse PostgreSQL queue

[Workhorse](https://workhorse.run/) · [PostgreSQL](https://www.postgresql.org/). Exact runtime/image pins live in Dockerfile, compose.yaml and the dependency locks.

### Deployment Dependencies

An existing source repository on a slash-free release-v1 branch, configured source root, Railway private networking and the documented persistent volumes are required. Fill every required secret and complete the bootstrap described in README.md. Hatchet requires a real tenant token minted after initialization, not a generated placeholder. Consult FINDINGS.md: marketplace publication, disposable Railway deployment and resource/soak gates remain pending.
