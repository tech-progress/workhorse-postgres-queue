# Upgrade and rollback

Template VERSION (currently 1.0.2) is separate from upstream runtime versions. Major template changes break the deployment contract; minor versions add compatible behavior; patch versions fix packaging/security. Publication maintains release-v1 and immutable vX.Y.Z tags; a candidate is not a released tag.

Candidate1.0.2 updates Node to24.20.0, PCRE2 to10.42-1+deb12u1, all four installed Workhorse packages to0.6.1, and PostgreSQL from17.9 to17.11. The previous public1.0.1 used Node24.14.0 and Workhorse0.6.0. PostgreSQL remains on major17 with the same data mount and generated variables. Dependencies install with --ignore-scripts and registry integrity checks; package managers are absent from the final filesystem/layers. Preserve Node, Debian and application notices. Before rollout, complete exact-artifact review, native auth/private worker/checkpoint/SIGKILL/fresh-volume restore acceptance, an immutable source release and fresh stored-graph live qualification. Never move the old release tag to this changed source.

Pin the SDK and dashboard to the same exact version. Both0.6.1 packages were published on October2,2026. The upstream tagged0.6.1 release adds no schema migration relative to0.6.0 (schema52, compatibility floor43). Still stop worker claims, back up PostgreSQL, run the installer and test pending-job/effect continuity before reopening. Do not silently follow main. For later upgrades, read the exact tagged compatibility and migration notes, update both pins and the lock, and rerun fail-once/delay/crash/restore tests. Workhorse's0.x minor changes can change behavior. Pre-0.5 schema migration0025 has special offline requirements. Rolling back binaries does not roll back schema: use a tested compatible version or restore the backup.

The local upgrade harness accepts existing immutable application and PostgreSQL image references and uses isolated ports18120–18129. It seeds real0.6.0 tasks/checkpoints/effects on PostgreSQL17.9, stops the old processes, takes a full backup, and replaces PostgreSQL with17.11 on the same volume before the new installer. It checks the original cluster identity, database rows and credentials, then restores the old backup into an independently empty17.11 volume. The second installer execution is an explicit idempotence test, not a recommendation to migrate every worker replica.

```bash
bash scripts/upgrade-smoke.sh \
  --old-image YOUR_FROZEN_0.6.0_IMAGE \
  --new-image YOUR_BUILT_0.6.1_IMAGE \
  --old-postgres-image YOUR_FROZEN_17.9_IMAGE \
  --new-postgres-image YOUR_PINNED_17.11_IMAGE \
  --port 18120
```

The harness owns and removes only its uniquely labelled containers, volumes, network, temporary credentials and backup. It does not pull/rebuild either image, test a schema downgrade, claim zero-downtime rolling replacement, or qualify a Railway release.

Before changing a compatibility branch: stop new work, retain a restorable backup, test the intended runtime/image pins locally, record required operator actions and measure the disposable Railway deployment. Never delete volumes as an upgrade step or run global Docker cleanup. Check credentials, private DNS and healthcheck target ports independently of deployment status.
