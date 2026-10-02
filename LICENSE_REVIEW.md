# License review

## Original recipe code

On October 2, 2026 the owner explicitly approved MIT for newly authored template, wrapper and application-recipe code. `LICENSE` covers that original code only; upstream products, dependencies, container files, fonts, sounds, plugins and enterprise components retain their own licenses and notices. This approval does not relicense or grant rights to any upstream artifact.

Reviewed primary upstream material on October 2, 2026.

Workhorse core and dashboard packages are Apache-2.0; PostgreSQL uses the PostgreSQL License. Keep Workhorse LICENSE/NOTICE and transitive UI notices when redistributing images or a standalone distribution. The wrapper does not change those obligations. No commercial Workhorse component is assumed. This is an engineering license review, not legal advice.

## Primary evidence

- [Runtime, beta boundary, licensing](https://github.com/stablemates/workhorse/tree/v0.6.0)
- [Schema and worker lifecycle](https://workhorse.run/docs/quickstart)
- [Dashboard authorization](https://workhorse.run/docs/dashboard)
- [Crash lifecycle and probe semantics](https://github.com/stablemates/workhorse/blob/v0.6.0/docs/worker-processes.md)
- [License](https://github.com/stablemates/workhorse/blob/v0.6.0/LICENSE)

## Publication gate

The owner approved MIT only for original recipe code. The locked production npm inventory and retained upstream/browser notices are documented in THIRD_PARTY_NOTICES.md. Dependencies are installed without stripping their license files, and unmodified Node/Debian/PostgreSQL base layers retain their separate notices. No upstream component is relabeled MIT. This source qualification does not imply an image vulnerability certification, a trademark grant or production support.
