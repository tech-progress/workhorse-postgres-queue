# Upgrade and rollback

Template VERSION (currently 1.0.0) is separate from upstream runtime versions. Major template changes break the deployment contract; minor versions add compatible behavior; patch versions fix packaging/security. Future publication should maintain release-v1 and immutable vX.Y.Z tags.

Pin the SDK and dashboard to the same exact version; the current upstream main documentation mentions 0.6.1 while npm supplied 0.6.0 during qualification. Do not silently follow main. Stop claims, back up the database, read the upstream compatibility and migration notes, update both pins and the lock, run the installer once, and rerun fail-once/delay/crash/restore tests before reopening. Workhorse's 0.x minor changes can change behavior. Pre-0.5 schema migration 0025 has special offline requirements. Rolling back binaries does not roll back schema: use a tested compatible version or restore the backup.

Before changing a compatibility branch: stop new work, retain a restorable backup, test the intended runtime/image pins locally, record required operator actions and measure the disposable Railway deployment. Never delete volumes as an upgrade step or run global Docker cleanup. Check credentials, private DNS and healthcheck target ports independently of deployment status.
