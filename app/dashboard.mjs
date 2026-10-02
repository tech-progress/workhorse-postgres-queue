import { createServer } from "node:http";
import { createDashboardHost, dashboardNodeMiddleware } from "@stablemates/workhorse-dashboard/server";
import { connect, ready } from "./database.mjs";
import { hashPassword, verifyPassword } from "./auth.mjs";

const pool = connect();
await ready(pool);
const username = process.env.WORKHORSE_DASHBOARD_USERNAME;
const password = process.env.WORKHORSE_DASHBOARD_PASSWORD;
if (!username || (!password && !process.env.WORKHORSE_DASHBOARD_PASSWORD_HASH)) throw new Error("Dashboard credentials are required");
if (password && password.length < 16) throw new Error("Dashboard password must have at least 16 characters");
const passwordHash = process.env.WORKHORSE_DASHBOARD_PASSWORD_HASH || hashPassword(password);
verifyPassword("startup-validation", passwordHash);
const publicOrigin = process.env.DASHBOARD_PUBLIC_ORIGIN;
if (!publicOrigin || new URL(publicOrigin).protocol !== "https:") throw new Error("DASHBOARD_PUBLIC_ORIGIN must be HTTPS");
let failedLogins = 0;
let loginWindow = Date.now();
const host = createDashboardHost({
  path: "/workhorse",
  database: pool,
  environment: "production",
  authorize: (request) => {
    if (Date.now() - loginWindow > 60_000) {
      failedLogins = 0;
      loginWindow = Date.now();
    }
    if (failedLogins >= 20) return new Response("Authentication throttled", { status: 429, headers: { "Retry-After": "60" } });
    const header = request.headers.get("authorization") || "";
    if (header.startsWith("Basic ")) {
      const decoded = Buffer.from(header.slice(6), "base64").toString();
      const separator = decoded.indexOf(":");
      if (decoded.slice(0, separator) === username && verifyPassword(decoded.slice(separator + 1), passwordHash)) return { actor: username };
      failedLogins += 1;
    }
    return new Response("Authentication required", { status: 401, headers: { "WWW-Authenticate": 'Basic realm="Workhorse operators", charset="UTF-8"' } });
  },
});
const middleware = dashboardNodeMiddleware(host, { publicOrigin });
const server = createServer(async (request, response) => {
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("X-Frame-Options", "DENY");
  response.setHeader("Referrer-Policy", "no-referrer");
  response.setHeader("X-Robots-Tag", "noindex, nofollow");
  response.setHeader("Content-Security-Policy", "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'");
  if (request.url === "/readyz") {
    try { await pool.query("SELECT 1"); response.writeHead(200); } catch { response.writeHead(503); }
    response.end();
    return;
  }
  middleware(request, response, () => { response.writeHead(404); response.end(); });
});
server.listen(Number(process.env.PORT || 3000), "::");
for (const signal of ["SIGTERM", "SIGINT"]) process.on(signal, () => server.close(() => pool.end().then(() => process.exit(0))));
