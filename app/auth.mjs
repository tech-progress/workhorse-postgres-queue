import { scryptSync, timingSafeEqual, randomBytes } from "node:crypto";

export function hashPassword(password) {
  const salt = randomBytes(16);
  const digest = scryptSync(password, salt, 32, { N: 16384, r: 8, p: 1, maxmem: 32 * 1024 * 1024 });
  return `scrypt-v1$${salt.toString("base64url")}$${digest.toString("base64url")}`;
}

export function verifyPassword(password, hash) {
  const [scheme, saltText, digestText, extra] = hash.split("$");
  const salt = Buffer.from(saltText || "", "base64url");
  const expected = Buffer.from(digestText || "", "base64url");
  if (scheme !== "scrypt-v1" || extra !== undefined || salt.length < 16 || expected.length !== 32) throw new Error("Invalid scrypt-v1 dashboard hash");
  const actual = scryptSync(password, salt, 32, { N: 16384, r: 8, p: 1, maxmem: 32 * 1024 * 1024 });
  return timingSafeEqual(actual, expected);
}
