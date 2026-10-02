import { readFileSync } from "node:fs";
import { defineRailway, github, group, project, service, volume } from "railway/iac";

const repository = process.env.SOURCE_REPO || "tech-progress/workhorse-postgres-queue";
if (!repository || repository.split("/").length !== 2 || !repository.split("/").every((part) => /^[A-Za-z0-9_.-]+$/.test(part))) throw new Error("Set SOURCE_REPO to an existing owner/repository before compiling");
const branch = process.env.SOURCE_BRANCH || "release-v1";
if (branch.includes("/")) throw new Error("Use a slash-free publication branch, such as release-v1");
const SOURCE = github(repository, { branch, rootDirectory: process.env.SOURCE_ROOT_DIRECTORY || "/" });
const BUILD = { builder: "DOCKERFILE" as const, dockerfilePath: "Dockerfile" };
const POSTGRES_IMAGE = "postgres:17.11-bookworm@sha256:639ab7ceb90e13123085b741fb31ef493fba25463002f6da665352e7b534b652";
const defaults = JSON.parse(readFileSync("template-defaults.json", "utf8"));

export default defineRailway(() => {
  const postgresData = volume("Postgres Data", { sizeMB: 5000 });
  const postgres = service("Postgres", { source: { image: POSTGRES_IMAGE }, env: defaults.Postgres, volumeMounts: { "/var/lib/postgresql/data": postgresData } });
  const worker = service("Worker", { source: SOURCE, build: BUILD, start: "node app/worker.mjs", preDeploy: "node app/install.mjs", healthcheck: "/readyz", healthcheckTimeout: 180, env: defaults.Worker });
  const dashboard = service("Dashboard", { source: SOURCE, build: BUILD, start: "node app/dashboard.mjs", healthcheck: "/readyz", healthcheckTimeout: 180, env: defaults.Dashboard, networking: { serviceDomains: { "<hasDomain>": { port: 3000 } } } });
  return project("workhorse-postgres-queue", { resources: [group("Queue", [worker, dashboard]), group("Storage", [postgres, postgresData])] });
});
