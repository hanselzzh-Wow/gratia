import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  normalizeApiBase,
  resetGithubPagesOutput,
  verifyGithubPagesExport,
} from "../scripts/build-github-pages.mjs";

test("accepts only a root HTTPS API outside chatgpt.site", () => {
  assert.equal(
    normalizeApiBase("https://gratia-mvp.example.workers.dev/"),
    "https://gratia-mvp.example.workers.dev",
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
  const directory = await mkdtemp(join(tmpdir(), "gratia-pages-"));
  await mkdir(join(directory, "ops"), { recursive: true });
  await mkdir(join(directory, "_next"), { recursive: true });
  await writeFile(join(directory, "index.html"), "<title>哈喽卧得</title>");
  await writeFile(join(directory, "ops/index.html"), "<title>心愿运营台</title>");
  await writeFile(
    join(directory, "_next/app.js"),
    'const api = "https://gratia.example.workers.dev";',
  );

  assert.doesNotThrow(() =>
    verifyGithubPagesExport(
      directory,
      "https://gratia.example.workers.dev",
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
        "https://gratia.example.workers.dev",
      ),
    /chatgpt\.site/,
  );
});

test("removes stale files before creating a new GitHub Pages export", async () => {
  const directory = await mkdtemp(join(tmpdir(), "gratia-pages-stale-"));
  const staleFile = join(directory, "index 3.html");
  await writeFile(staleFile, "stale build");

  resetGithubPagesOutput(directory);

  await assert.rejects(
    readFile(staleFile, "utf8"),
    (error) => error.code === "ENOENT",
  );
});
