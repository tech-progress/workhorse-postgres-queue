FROM node:24.14.0-bookworm-slim@sha256:d8e448a56fc63242f70026718378bd4b00f8c82e78d20eefb199224a4d8e33d8
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY app ./app
COPY scripts/smoke.mjs ./scripts/smoke.mjs
USER node
ENV PORT=3000 NODE_ENV=production
EXPOSE 3000
CMD ["node", "app/worker.mjs"]
