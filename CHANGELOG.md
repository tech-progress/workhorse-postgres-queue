# Changelog

## [1.0.2] - 2026-10-02

- Pin all four installed Workhorse packages to0.6.1 with registry integrity checks.
- Pin the official PostgreSQL17.11 image by manifest digest, including the upstream17.10/17.11 security fixes within the same database major version.
- Pin Node24.20.0, install PCRE2 security package10.42-1+deb12u1, disable dependency lifecycle scripts and ship a flattened runtime without package-manager tools, retaining notices.
- Add runtime-policy regression checks and distinct fresh-volume checkpoint recovery acceptance. This is a release candidate until artifact, source, live deployment and cleanup checks pass; existing immutable tags are unchanged.

## [1.0.1] - 2026-10-02

- Record the owner-approved original-code MIT scope and the sanitized standalone release source.
- Replace pre-authorization publishing instructions with the qualified stored-graph deployment, recovery, cleanup and marketplace gates; no runtime-contract change.

## [1.0.0] - 2026-10-02

- Initial unpublished evaluation recipe with pinned dependencies, private service boundaries, authenticated workload access, durable state and isolated local smoke tools.
- Offline draft restoration and audit; no Railway/GitHub publication or standalone distribution exists yet.
