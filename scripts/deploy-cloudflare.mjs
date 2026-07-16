import { mkdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import process from "node:process";
import {
  defaultCloudflareSecretsPath,
  initializeCloudflareSecrets,
} from "./cloudflare-secrets.mjs";

const root = resolve(import.meta.dirname, "..");
const wrangler = resolve(root, "node_modules/.bin/wrangler");
const config = resolve(root, "deploy/cloudflare/wrangler.jsonc");
const secretsFile = defaultCloudflareSecretsPath;
const outputDirectory = resolve(root, ".wrangler/direct-deploy");
const wranglerLog = resolve(outputDirectory, "wrangler.log");
const dryRun = process.argv.includes("--dry-run");

mkdirSync(outputDirectory, { recursive: true });

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: root,
    stdio: "inherit",
    env: {
      ...process.env,
      WRANGLER_HIDE_BANNER: "true",
      WRANGLER_LOG_PATH: wranglerLog,
      WRANGLER_SEND_METRICS: "false",
    },
    ...options,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

run("npm", ["run", "build"]);

if (dryRun) {
  run(wrangler, [
    "deploy",
    "--dry-run",
    "--config",
    config,
    "--outdir",
    outputDirectory,
  ]);
  process.exit(0);
}

run(wrangler, ["whoami"]);
try {
  const result = initializeCloudflareSecrets(secretsFile);
  if (result.created) {
    console.log("已安全生成运营 PIN 和限流盐值，并保存在 .cloudflare.secrets。");
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
run(wrangler, [
  "d1",
  "migrations",
  "apply",
  "DB",
  "--remote",
  "--config",
  config,
  "--experimental-provision",
]);
run(wrangler, [
  "deploy",
  "--config",
  config,
  "--secrets-file",
  secretsFile,
  "--experimental-provision",
]);
