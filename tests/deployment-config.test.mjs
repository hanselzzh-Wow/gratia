import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

test("keeps the direct Cloudflare deployment isolated from the stable demo", async () => {
  const config = JSON.parse(
    await readFile(new URL("deploy/cloudflare/wrangler.jsonc", root), "utf8"),
  );
  const gitignore = await readFile(new URL(".gitignore", root), "utf8");
  const secretsExample = await readFile(new URL(".cloudflare.secrets.example", root), "utf8");

  assert.equal(config.name, "haluowode-mvp");
  assert.equal(config.main, "../../dist/server/index.js");
  assert.equal(config.workers_dev, true);
  assert.equal(config.no_bundle, true);
  assert.deepEqual(config.assets.run_worker_first, ["/api/*"]);
  assert.equal(config.assets.binding, "ASSETS");
  assert.equal(config.d1_databases[0].binding, "DB");
  assert.equal(config.r2_buckets[0].binding, "UPLOADS");
  assert.equal(config.vars.PUBLIC_APP_ORIGIN, "https://hanselzzh-wow.github.io");
  assert.deepEqual(config.secrets.required.sort(), ["ADMIN_API_KEY", "RATE_LIMIT_SALT"]);

  assert.equal("database_id" in config.d1_databases[0], false);
  assert.equal("bucket_name" in config.r2_buckets[0], false);
  assert.match(gitignore, /^\/\.cloudflare\.secrets$/m);
  assert.match(secretsExample, /^ADMIN_API_KEY=replace-/m);
  assert.match(secretsExample, /^RATE_LIMIT_SALT=replace-/m);
  assert.equal(JSON.stringify(config).includes("replace-with-"), false);
});
