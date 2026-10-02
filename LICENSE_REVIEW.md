# License review

## Original recipe code

On October 2, 2026 the owner explicitly approved MIT for newly authored template, wrapper and application-recipe code. `LICENSE` covers that original code only; upstream products, dependencies, container files, fonts, sounds, plugins and enterprise components retain their own licenses and notices. This approval does not relicense or grant rights to any upstream artifact.

Reviewed primary upstream material on October 2, 2026.

Workhorse core, dashboard, dashboard server and dashboard contract **0.6.1** are Apache-2.0; PostgreSQL uses the PostgreSQL License. Keep Workhorse LICENSE/NOTICE and transitive UI notices. The wrapper does not change those obligations. No commercial Workhorse component is assumed. This is an engineering license review, not legal advice.

## Primary evidence

- [Exact core 0.6.1 registry artifact metadata](https://registry.npmjs.org/@stablemates/workhorse/0.6.1)
- [Exact dashboard 0.6.1 registry artifact metadata](https://registry.npmjs.org/@stablemates/workhorse-dashboard/0.6.1)
- [Exact server 0.6.1 registry artifact metadata](https://registry.npmjs.org/@stablemates/workhorse-dashboard-server/0.6.1)
- [Exact contract 0.6.1 registry artifact metadata](https://registry.npmjs.org/@stablemates/workhorse-dashboard-contract/0.6.1)
- [Schema and worker lifecycle](https://workhorse.run/docs/quickstart)
- [Dashboard authorization](https://workhorse.run/docs/dashboard)
- [Crash lifecycle and probe semantics](https://github.com/stablemates/workhorse/blob/v0.6.0/docs/worker-processes.md)
- [Exact core archive carrying original LICENSE/NOTICE](https://registry.npmjs.org/@stablemates/workhorse/-/workhorse-0.6.1.tgz)

## Source-only publication decision

The owner approved MIT for the complete authored wrapper/recipe code, not upstream artifacts. This publication offers that source, exact build pins and notices; it does **not** distribute an assembled image to GHCR. All 117 reviewed production npm artifacts declare available permissive grants, and the required original grants/notices are concretely covered below. **No missing third-party permission or required production notice was identified for this source-build-only recipe.** This is a scoped engineering disposition, not legal certification, trademark permission or a claim that every future image-distribution obligation has been satisfied.

## Exact 0.6.1 grant inventory — October 2, 2026

This review covers the exact 0.6.1 production lock, Node24.20.0 input and pinned Debian PCRE2 update. Runtime builds must preserve the original notice bytes inventoried below. Source provenance and original grants are public; operational image/test/scan receipts are not part of the distribution. This review does not grant publication permission on behalf of the hosting platform or waive separate qualification/cleanup requirements.

- All 117 production tarballs were downloaded from their exact locked registry URLs and mechanically SHA512-verified without installation, lifecycle scripts or executing their code. Inventory: MIT (92), Apache-2.0 (6), ISC (13), BSD-3-Clause (3), 0BSD (1), MIT OR CC0-1.0 (1), MIT AND ISC (1). MIT/ISC/BSD copyright, permission and disclaimer conditions are preserved; use the available MIT option for type-fest's disjunction, and retain both sets of texts for victory-vendor's conjunction. Apache packages retain their license and applicable NOTICE material; no upstream implementation was relabeled or modified by the wrapper.
- **143** original notice/grant files cover all 117 production artifacts. This includes LICENCE.md in decimal.js-light and the complete README MIT grants for pg-types and pgpass. The remaining package without a standalone grant file, react-remove-scroll-bar2.3.8, has its full original MIT grant/copyright/disclaimer in the retained server browser notice. A guessed upstream LICENSE URL is not the basis of this grant: the exact integrity-verified distribution contains the complete text.
- All four Workhorse0.6.1 package LICENSE/NOTICE files remain under their installed package roots. Server `dist/app/THIRD_PARTY_NOTICES.txt` preserves the separately compiled browser's 52 component grants: MIT39, ISC10, BSD-3-Clause1, 0BSD1, MIT AND ISC1. Those bundled versions are not inferred from today's dependency tree.
- Node's `/usr/local/LICENSE` hash matches the [official pinned v24.20.0 license](https://raw.githubusercontent.com/nodejs/node/v24.20.0/LICENSE): `5888dbb9a1d2b18f2c3e6c5f6af1b39de658372b402a0577b002777f14c62ace`. This retains Node's own and bundled native-component texts. Debian package copyright files remain in the flattened filesystem; PostgreSQL remains a separately pinned upstream image with its own grant.
- Removed global npm/Yarn tools retain upstream top-level license text at `/usr/local/share/licenses/build-tools/npm-LICENSE.txt` and `yarn-LICENSE.txt`. Tool removal is not a waiver of obligations for build-stage tools or their dependencies. GNU Debian tar remains; it is not the removed npm tar package.
- Public provenance is recorded as artifact-review production-license-inventory.json, browser-notice-inventory.json and primary-source-references.json. Original upstream texts are preserved in artifact-review/notices, under product/version directories rather than dependency-cache directories. This review generated no replacement grant or fabricated waiver. Normal npm installation already retains the required texts, so copying an inventory JSON into the runtime is optional; it is not a substitute for those actual texts.

Source-only publication has no identified remaining missing-permission/notice blocker in this examined scope. Continue preserving these concrete texts and original source pointers in the built runtime; no universal legal audit is imposed as an additional source-recipe gate. If a future task redistributes assembled images, exact Debian GPL/LGPL corresponding-source and, where applicable, relinking obligations must be satisfied for that distribution rather than assumed from an image tag or a notice copy. See [GNU distribution guidance](https://www.gnu.org/licenses/gpl-faq.html#WhatDoesWrittenOfferValid) and installed Debian copyright files. This conditional image-distribution obligation is **not** a claim that current source-only publication lacks permission. Live qualification, cleanup-policy approval and catalog audit remain independent gates; this review does not waive them. Security scope is recorded in [Security review](SECURITY_REVIEW.md).
