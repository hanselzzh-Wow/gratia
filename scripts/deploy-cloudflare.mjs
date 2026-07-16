import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import process from "node:process";

const root = resolve(import.meta.dirname, "..");
const wrangler = resolve(root, "node_modules/.bin/wrangler");
const config = resolve(root, "deploy/cloudflare/wrangler.jsonc");
const secretsFile = resolve(root, ".cloudflare.secrets");
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

function readSecretNames(path) {
  return new Set(
    readFileSync(path, "utf8")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#") && line.includes("="))
      .map((line) => line.slice(0, line.indexOf("=")).trim()),
  );
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

if (!existsSync(secretsFile)) {
  console.error("缺少 .cloudflare.secrets。请复制 .cloudflare.secrets.example，并替换两个示例值。");
  process.exit(1);
}

const secretNames = readSecretNames(secretsFile);
for (const name of ["ADMIN_API_KEY", "RATE_LIMIT_SALT"]) {
  if (!secretNames.has(name)) {
    console.error(`.cloudflare.secrets 缺少 ${name}`);
    process.exit(1);
  }
}

run(wrangler, ["whoami"]);
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
