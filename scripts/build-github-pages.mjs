import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

const root = resolve(import.meta.dirname, "..");
const next = resolve(root, "node_modules/.bin/next");
const outputDirectory = resolve(root, "out");
const textExtensions = new Set([".css", ".html", ".js", ".json", ".txt"]);

export function normalizeApiBase(input) {
  if (!input?.trim()) throw new Error("缺少完整后端的 workers.dev 地址");
  let url;
  try {
    url = new URL(input.trim());
  } catch {
    throw new Error("后端地址不是有效 URL");
  }
  if (url.protocol !== "https:") throw new Error("后端地址必须使用 HTTPS");
  if (url.hostname.endsWith(".chatgpt.site")) {
    throw new Error("拒绝把稳定前端重新连接到会被拦截的 chatgpt.site 地址");
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new Error("后端地址不能包含账号、密码、查询参数或锚点");
  }
  if (url.pathname !== "/" && url.pathname !== "") {
    throw new Error("后端地址应使用域名根路径");
  }
  return url.origin;
}

function collectTextFiles(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectTextFiles(path));
    else if (textExtensions.has(entry.name.slice(entry.name.lastIndexOf(".")))) files.push(path);
  }
  return files;
}

export function verifyGithubPagesExport(directory, apiBase) {
  const requiredFiles = [
    resolve(directory, "index.html"),
    resolve(directory, "ops/index.html"),
  ];
  for (const file of requiredFiles) {
    if (!existsSync(file)) throw new Error(`静态导出缺少 ${file}`);
  }

  const content = collectTextFiles(directory)
    .map((file) => readFileSync(file, "utf8"))
    .join("\n");
  if (!content.includes(apiBase)) {
    throw new Error("静态产物没有写入指定的完整后端地址");
  }
  if (/https?:\/\/[^"'\s]*chatgpt\.site/i.test(content)) {
    throw new Error("静态产物仍包含 chatgpt.site 地址");
  }
  if (!readFileSync(requiredFiles[0], "utf8").includes("哈喽卧得")) {
    throw new Error("首页静态产物不是哈喽卧得");
  }
}

function runBuild(apiBase) {
  const result = spawnSync(next, ["build"], {
    cwd: root,
    stdio: "inherit",
    env: {
      ...process.env,
      GITHUB_PAGES: "true",
      NEXT_PUBLIC_API_BASE_URL: apiBase,
    },
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

function main() {
  try {
    const apiArgument = process.argv.slice(2).find((argument) => !argument.startsWith("--"));
    const apiBase = normalizeApiBase(
      apiArgument ??
        process.env.HALUOWODE_API_BASE_URL ??
        process.env.NEXT_PUBLIC_API_BASE_URL,
    );
    runBuild(apiBase);
    verifyGithubPagesExport(outputDirectory, apiBase);
    writeFileSync(resolve(outputDirectory, ".nojekyll"), "", "utf8");
    console.log(`GitHub Pages 静态产物已就绪：${outputDirectory}`);
    console.log(`完整后端：${apiBase}`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

const invokedUrl = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : "";
if (invokedUrl === import.meta.url) main();
