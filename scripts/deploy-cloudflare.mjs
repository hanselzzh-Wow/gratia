import { chmodSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
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
const runtimeConfig = resolve(outputDirectory, "wrangler.runtime.jsonc");
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

function runCapture(command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
    env: {
      ...process.env,
      WRANGLER_HIDE_BANNER: "true",
      WRANGLER_LOG_PATH: wranglerLog,
      WRANGLER_SEND_METRICS: "false",
    },
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
  return result.stdout;
}

function createRuntimeMigrationConfig() {
  const cloudflareConfig = JSON.parse(readFileSync(config, "utf8"));
  const databaseBinding = cloudflareConfig.d1_databases?.[0];
  if (!databaseBinding?.binding) {
    throw new Error("Cloudflare 配置缺少 D1 绑定。");
  }

  const expectedName =
    databaseBinding.database_name ??
    `${cloudflareConfig.name}-${databaseBinding.binding.toLowerCase()}`;
  const databases = JSON.parse(runCapture(wrangler, ["d1", "list", "--json"]));
  const database = databases.find((candidate) => candidate.name === expectedName);
  if (!database?.uuid) {
    throw new Error(`未找到自动配置的 D1 数据库：${expectedName}`);
  }

  cloudflareConfig.d1_databases = [
    {
      ...databaseBinding,
      database_name: expectedName,
      database_id: database.uuid,
    },
  ];
  cloudflareConfig.r2_buckets = [];
  writeFileSync(runtimeConfig, `${JSON.stringify(cloudflareConfig, null, 2)}\n`, {
    mode: 0o600,
  });
  chmodSync(runtimeConfig, 0o600);
  return databaseBinding.binding;
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
  "deploy",
  "--config",
  config,
  "--secrets-file",
  secretsFile,
  "--experimental-provision",
]);

let databaseBinding;
try {
  databaseBinding = createRuntimeMigrationConfig();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
run(wrangler, [
  "d1",
  "migrations",
  "apply",
  databaseBinding,
  "--remote",
  "--config",
  runtimeConfig,
]);
run(wrangler, [
  "deploy",
  "--config",
  config,
  "--secrets-file",
  secretsFile,
  "--experimental-provision",
]);
