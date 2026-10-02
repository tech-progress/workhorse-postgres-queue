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

Preserve all upstream license/notice material already shipped in dependencies/images. Before standalone publication, inventory transitive distributions/assets and confirm the owner's intended license for the original recipe wrapper; do not assume that upstream licensing licenses new wrapper code. No blanket new license header or copied commercial license has been added.
