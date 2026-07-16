import assert from "node:assert/strict";
import { mkdtemp, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  initializeCloudflareSecrets,
  parseCloudflareSecrets,
  validateCloudflareSecrets,
} from "../scripts/cloudflare-secrets.mjs";

test("rejects placeholder, short, or reused Cloudflare secrets", () => {
  assert.throws(
    () =>
      validateCloudflareSecrets(
        parseCloudflareSecrets(
          "ADMIN_API_KEY=replace-with-a-long-random-operations-pin\nRATE_LIMIT_SALT=short\n",
        ),
      ),
    /示例值.*至少需要 24 个字符/,
  );
  assert.throws(
    () =>
      validateCloudflareSecrets(
        new Map([
          ["ADMIN_API_KEY", "same-value-with-enough-length"],
          ["RATE_LIMIT_SALT", "same-value-with-enough-length"],
        ]),
      ),
    /必须使用不同的值/,
  );
});

test("generates strong local-only Cloudflare secrets without overwriting them", async () => {
  const directory = await mkdtemp(join(tmpdir(), "haluowode-secrets-"));
  const path = join(directory, ".cloudflare.secrets");
  const first = initializeCloudflareSecrets(path);
  const original = await readFile(path, "utf8");
  const second = initializeCloudflareSecrets(path);

  assert.equal(first.created, true);
  assert.equal(second.created, false);
  assert.equal(await readFile(path, "utf8"), original);
  assert.notEqual(first.values.get("ADMIN_API_KEY"), first.values.get("RATE_LIMIT_SALT"));
  assert.ok((first.values.get("ADMIN_API_KEY") ?? "").length >= 24);
  assert.equal((await stat(path)).mode & 0o777, 0o600);
});
