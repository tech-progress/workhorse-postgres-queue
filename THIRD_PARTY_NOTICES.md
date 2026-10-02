# Third-party notices

`LICENSE` applies only to original recipe code. It does not replace upstream licenses or notices.

- Workhorse core, dashboard, dashboard server and dashboard contract 0.6.0 are Apache-2.0. Their npm packages retain `LICENSE` and `NOTICE`; the dashboard server also retains `dist/app/THIRD_PARTY_NOTICES.txt`, including legal texts for bundled browser dependencies. The Docker build installs the locked upstream distributions without deleting those files.
- The locked production npm tree contains 117 package entries: MIT (92), Apache-2.0 (6), ISC (13), BSD-3-Clause (3), 0BSD (1), MIT OR CC0-1.0 (1), and MIT AND ISC (1). Package metadata is an inventory, not a substitute for the full bundled notices.
- PostgreSQL and its client components have their own PostgreSQL License. The immutable official PostgreSQL and Node/Debian images retain their runtime/package notices. This recipe neither republishes those products under MIT nor claims ownership of their trademarks.

Origins: [Workhorse](https://workhorse.run/), [Workhorse source](https://github.com/stablemates/workhorse/tree/v0.6.0), [PostgreSQL](https://www.postgresql.org/), [Node.js](https://nodejs.org/).
