FROM node:24.20.0-bookworm-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --registry=https://registry.npmjs.org && npm cache clean --force
COPY app ./app
COPY scripts/smoke.mjs scripts/verify-runtime.mjs ./scripts/
COPY LICENSE THIRD_PARTY_NOTICES.md ./

FROM node:24.20.0-bookworm-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e AS runtime-files
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpcre2-8-0=10.42-1+deb12u1 \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/share/licenses/build-tools \
    && cp /usr/local/lib/node_modules/npm/LICENSE /usr/local/share/licenses/build-tools/npm-LICENSE.txt \
    && cp /opt/yarn-v1.22.22/LICENSE /usr/local/share/licenses/build-tools/yarn-LICENSE.txt \
    && rm -rf /usr/local/lib/node_modules /opt/yarn-v* /root/.npm \
       /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/yarn /usr/local/bin/yarnpkg \
       /usr/local/bin/corepack /usr/local/bin/pnpm /usr/local/bin/pnpx

FROM scratch AS runtime
COPY --from=runtime-files / /
COPY --from=dependencies /app /app
WORKDIR /app
USER node
ENV PATH=/usr/local/bin:/usr/bin:/bin PORT=3000 NODE_ENV=production
EXPOSE 3000
CMD ["node", "app/worker.mjs"]
