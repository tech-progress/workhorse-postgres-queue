# Exact Workhorse 0.6.1 artifact review

Reviewed October 2, 2026. This is a finite source-build recipe assessment, not a legal or vulnerability certification or a retroactive assessment of earlier releases.

## Exact reviewed inputs

- Node input: `node:24.20.0-bookworm-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e`; supported pinned release, not a latest-version claim. Runtime PCRE2: `10.42-1+deb12u1`.
- Exact npm roots: @stablemates/workhorse and workhorse-dashboard0.6.1, with dashboard-contract/server0.6.1. All 117 production artifacts are SHA512-verified against the exact lock; no floating dependency resolution is assumed.
- Final runtime is flattened to exclude deleted package-manager payload, while retaining 143 original application grant/notice files and the complete upstream Node/native and installed Debian notices. Node's LICENSE corresponds to the pinned upstream source, not a newly authored replacement.
- Thirty-one primary native advisory leads are individually assessed; the PCRE2 update fixes three, leaving 28 residual conditions with the recorded default boundaries. This is not an exploit count or a zero-scanner policy. See [Security review](SECURITY_REVIEW.md).

Public provenance comprises artifact-review production-license-inventory.json, browser-notice-inventory.json, primary-source-references.json and original notice files. Exact download URLs, locked integrity, original-text SHA256s and expected installed notice paths are explicit per package. Operational runtime/test/scan collectors and receipts are not distribution artifacts; no private registry, test-resource identifier or authoring path is required to use this recipe.

## Source-only rights disposition

This publication distributes owner-authored MIT wrapper/recipe source, exact instructions/pins and original notices, **not a prebuilt binary image**. Reviewed production grants and concrete notice locations support that act. No missing permission or required production notice remains identified. No enterprise/proprietary Workhorse component is included. Retain the complete upstream npm trees, including README grants and bundled-browser notices; do not replace them with a list of SPDX identifiers.

The built runtime keeps Node/native and Debian copyright/license files, application grants, and removed npm/Yarn top-level texts. It does not relabel those packages MIT. If assembled images are later distributed, evaluate corresponding-source/relinking requirements for the exact GPL/LGPL OS components as a separate distribution task. Those future conditions are not a fabricated rights blocker for today's source recipe. See [License review](LICENSE_REVIEW.md) and [Original third-party notices](THIRD_PARTY_NOTICES.md).

## Build inputs versus final runtime

The dependency stage still contains npm11.19.0 and its tools; final npm/npx/Yarn/Corepack/pnpm removal does not remove build-stage exposure. The installer receives exact registry.npmjs.org artifacts, locked SHA512 integrity, reviewed source and disabled install scripts in a one-use stage. It is not a public archive/glob/URL-processing service. Seven known build-tool advisories are individually scoped in Security review, including the separate applicability of Undici's advisory to Node's bundled7.29.0 WebSocket client.

There is no reviewed application native .node add-on or wrapper invocation of Perl, mount/nsenter, GNU gzip/infocmp, ACL tools or PCRE2. Node dynamically links glibc/libstdc++/libgcc, so those packages are not called universally irrelevant. Their precise primary triggers are assessed individually. Dashboard **does use Node zlib gzip/brotli**; its gzip path uses Node's buffer deflate binding rather than the nonblocking gzwrite/gzprintf stdio path in CVE-2026-85091. Do not advertise absent compression or universal native-component clearance.

## Finite promotion decision

**No concrete source-rights or default-request-reachable native/advisory blocker was identified for this corrected source-build-only recipe under the recorded default boundaries.** This does not require zero scanner matches, invent a vulnerability waiver or endorse arbitrary operator extensions. The detailed residual conditions remain disclosed. Changing defaults to execute untrusted code, external archive/glob/URL input, privileged host operations, native add-ons, Perl or outbound WebSocket clients requires a new assessment.

The following concrete release checks still apply outside this review:

1. Each final runtime build must retain the pinned versions and original grant/notice bytes. A source review is not an attestation of a different assembled image.
2. Qualify that final immutable source through the exact stored Railway graph and real native/recovery/current-replica checks; local acceptance does not replace this gate.
3. Obtain the still-pending owner cleanup-policy answer and pass coordinator publication/catalog gates. No cloud/retention operation, release, upload or waiver is authorized by this review.

No additional open-ended legal-certification or all-software-zero-CVE condition is introduced.
