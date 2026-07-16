import { randomBytes } from "node:crypto";
import { chmodSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

export const requiredCloudflareSecrets = ["ADMIN_API_KEY", "RATE_LIMIT_SALT"];
export const defaultCloudflareSecretsPath = resolve(
  import.meta.dirname,
  "../.cloudflare.secrets",
);

export function parseCloudflareSecrets(text) {
  const values = new Map();
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const separator = line.indexOf("=");
    const name = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }
    values.set(name, value);
  }
  return values;
}

export function validateCloudflareSecrets(values) {
  const errors = [];
  for (const name of requiredCloudflareSecrets) {
    const value = values.get(name) ?? "";
    if (!value) errors.push(`缺少 ${name}`);
    else if (value.length < 24) errors.push(`${name} 至少需要 24 个字符`);
    else if (/replace-with|change-me|example|placeholder/i.test(value)) {
      errors.push(`${name} 仍是示例值`);
    }
  }
  if (
    values.get("ADMIN_API_KEY") &&
    values.get("ADMIN_API_KEY") === values.get("RATE_LIMIT_SALT")
  ) {
    errors.push("ADMIN_API_KEY 和 RATE_LIMIT_SALT 必须使用不同的值");
  }
  if (errors.length > 0) throw new Error(errors.join("；"));
  return values;
}

export function initializeCloudflareSecrets(path = defaultCloudflareSecretsPath) {
  let created = false;
  if (!existsSync(path)) {
    const adminKey = randomBytes(24).toString("base64url");
    const rateLimitSalt = randomBytes(32).toString("base64url");
    writeFileSync(
      path,
      `ADMIN_API_KEY=${adminKey}\nRATE_LIMIT_SALT=${rateLimitSalt}\n`,
      { encoding: "utf8", flag: "wx", mode: 0o600 },
    );
    created = true;
  }

  const values = validateCloudflareSecrets(parseCloudflareSecrets(readFileSync(path, "utf8")));
  chmodSync(path, 0o600);
  return { created, values };
}

function main() {
  try {
    const result = initializeCloudflareSecrets();
    console.log(
      result.created
        ? "已创建 .cloudflare.secrets，并设置为仅当前用户可读写。运营 PIN 保存在该文件中。"
        : ".cloudflare.secrets 已存在，格式和强度检查通过。",
    );
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

const invokedUrl = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : "";
if (invokedUrl === import.meta.url) main();
