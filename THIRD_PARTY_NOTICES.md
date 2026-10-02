# Third-party notices

`LICENSE` applies only to original recipe code. It does not replace upstream licenses or notices.

- Workhorse core, dashboard, dashboard server and dashboard contract **0.6.1** are Apache-2.0. Their exact integrity-locked npm artifacts retain `LICENSE` and `NOTICE`; the dashboard server also retains `dist/app/THIRD_PARTY_NOTICES.txt`, including original legal texts for its 52 bundled browser components. The Docker build installs the locked upstream distributions without deleting those files, their README grants or British-spelled LICENCE files.
- The locked production npm tree contains 117 package entries: MIT (92), Apache-2.0 (6), ISC (13), BSD-3-Clause (3), 0BSD (1), MIT OR CC0-1.0 (1), and MIT AND ISC (1). Package metadata is an inventory, not a substitute for the full bundled notices.
- PostgreSQL and its client components have their own PostgreSQL License. Node's `/usr/local/LICENSE` includes its native-component notices; Debian package copyright files remain in the flattened runtime filesystem. Removed npm/Yarn tools retain top-level license copies in `/usr/local/share/licenses/build-tools/`. This recipe neither republishes those products under MIT nor claims ownership of their trademarks.

## Exact production grant coverage

The October 2, 2026 inventory verifies all **117** production tarballs against their locked SHA512 integrity and preserves **143** original notice/grant files. `pg-types@2.2.0` and `pgpass@1.0.5` include their full MIT grants in README.md; `decimal.js-light@2.5.1` uses LICENCE.md. `react-remove-scroll-bar@2.3.8` omits a separate license file from its npm artifact, but its full original MIT copyright, permission and disclaimer are already retained in the dashboard server's `THIRD_PARTY_NOTICES.txt`, under its exact name/version. Do not drop that bundled notice file or the README grants when slimming the runtime.

Bundled-browser inventory is separate from the installed npm tree: 52 components, comprising MIT (39), ISC (10), BSD-3-Clause (1), 0BSD (1), and MIT AND ISC (1). Do not substitute current installed dependency versions for the versions embedded in the upstream browser bundle.

Publication distributes authored recipe source, pin/build instructions and notices, **not an assembled container image or a GHCR artifact**. These upstream grants permit the reviewed source-build recipe with retained notices; they do not relicense third-party code. If assembled images are later redistributed, evaluate the exact GPL/LGPL OS source/relinking requirements and other binary-distribution obligations for that separate act. The full [License review](https://github.com/tech-progress/workhorse-postgres-queue/blob/release-v1/LICENSE_REVIEW.md) and [Artifact review](https://github.com/tech-progress/workhorse-postgres-queue/blob/release-v1/ARTIFACT_REVIEW.md) are source documents, not required runtime files. Those major-channel links are navigation pointers; consult the matching immutable source tag for the precise deployed revision.

Origins: [Workhorse](https://workhorse.run/), [Workhorse source](https://github.com/stablemates/workhorse/tree/v0.6.0), [PostgreSQL](https://www.postgresql.org/), [Node.js](https://nodejs.org/).
