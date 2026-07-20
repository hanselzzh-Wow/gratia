import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { fileURLToPath } from "node:url";

test("ESLint explicitly ignores nested isolated worktrees", async () => {
  const configPath = fileURLToPath(new URL("../eslint.config.mjs", import.meta.url));
  const config = await readFile(configPath, "utf8");

  assert.match(config, /"worktrees\/\*\*"/);
});
