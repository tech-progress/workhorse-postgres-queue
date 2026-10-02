# Support boundary

This is an unpublished, self-contained low-volume evaluation recipe. The primary upstream projects are [Workhorse](https://workhorse.run/) · [PostgreSQL](https://www.postgresql.org/). It does not provide managed-service support, multi-node availability, performance sizing, or an exactly-once guarantee.

If readiness waits, check PostgreSQL and the pre-deploy schema job; do not add runtime auto-migrations. If the dashboard returns 401, check the configured operator/hash and redeploy after rotation; 404 at / is expected, use /workhorse/. If tasks do not move, confirm the registered worker, matching task type, paused state and concurrency. Recovering a killed worker takes at least a lease expiry plus maintenance. Inspect dead letters before redrive. Never paste DATABASE_URL, task payloads, credentials or dumps into support issues.

Provide template VERSION, exact upstream pins, failing command/HTTP status and redacted logs. Do not provide token output, auth databases, /config contents, full DSNs, passwords, customer payloads or raw database dumps. Reproduce with scripts/verify.sh and an isolated scripts/local-smoke.sh first. Escalate product bugs upstream only after separating wrapper configuration from upstream behavior.
