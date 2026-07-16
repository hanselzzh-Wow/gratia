import assert from "node:assert/strict";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  normalizeApiBase,
  verifyGithubPagesExport,
} from "../scripts/build-github-pages.mjs";

test("accepts only a root HTTPS API outside chatgpt.site", () => {
  assert.equal(
    normalizeApiBase("https://haluowode-mvp.example.workers.dev/"),
    "https://haluowode-mvp.example.workers.dev",
  );
  assert.throws(() => normalizeApiBase("http://example.com"), /HTTPS/);
  assert.throws(
    () => normalizeApiBase("https://blocked.chatgpt.site"),
    /chatgpt\.site/,
  );
  assert.throws(
    () => normalizeApiBase("https://example.workers.dev/api"),
    /根路径/,
  );
});

test("checks the GitHub Pages handoff before publication", async () => {
  const directory = await mkdtemp(join(tmpdir(), "haluowode-pages-"));
  await mkdir(join(directory, "ops"), { recursive: true });
  await mkdir(join(directory, "_next"), { recursive: true });
  await writeFile(join(directory, "index.html"), "<title>哈喽卧得</title>");
  await writeFile(join(directory, "ops/index.html"), "<title>心愿运营台</title>");
  await writeFile(
    join(directory, "_next/app.js"),
    'const api = "https://haluowode.example.workers.dev";',
  );

  assert.doesNotThrow(() =>
    verifyGithubPagesExport(
      directory,
      "https://haluowode.example.workers.dev",
    ),
  );
  await writeFile(
    join(directory, "_next/legacy.js"),
    'const old = "https://blocked.chatgpt.site";',
  );
  assert.throws(
    () =>
      verifyGithubPagesExport(
        directory,
        "https://haluowode.example.workers.dev",
      ),
    /chatgpt\.site/,
  );
});
