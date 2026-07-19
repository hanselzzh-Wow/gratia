import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

const root = new URL("../miniprogram/", import.meta.url);

async function text(relativePath) {
  return readFile(new URL(relativePath, root), "utf8");
}

test("ships an importable five-destination WeChat mini program", async () => {
  const project = JSON.parse(await readFile(new URL("../project.config.json", import.meta.url), "utf8"));
  const app = JSON.parse(await text("app.json"));
  assert.equal(project.miniprogramRoot, "miniprogram/");
  assert.equal(project.compileType, "miniprogram");
  assert.deepEqual(app.pages, [
    "pages/home/index", "pages/search/index", "pages/publish/index", "pages/help/index", "pages/profile/index", "pages/delivery/index",
  ]);
  for (const page of app.pages) {
    for (const extension of [".js", ".json", ".wxml", ".wxss"]) {
      await text(`${page}${extension}`);
    }
  }
});

test("keeps WeChat and operations secrets out of the mini program", async () => {
  const files = ["config.js", "utils/api.js", "pages/profile/index.js", "pages/publish/index.js", "pages/help/index.js"];
  const source = (await Promise.all(files.map(text))).join("\n");
  assert.match(source, /\/api\/auth\/wechat/);
  assert.doesNotMatch(source, /x-admin-key/i);
  assert.doesNotMatch(source, /WECHAT_MINI_PROGRAM_APP_SECRET/);
  assert.doesNotMatch(source, /session_key/i);
  assert.doesNotMatch(source, /access_token/i);
});

test("uses the declared Lucide navigation asset set", async () => {
  const icons = await readdir(new URL("assets/lucide/", root));
  for (const icon of ["home.svg", "search.svg", "plus.svg", "heart-handshake.svg", "user-round.svg", "check.svg"]) {
    assert.ok(icons.includes(icon), `${icon} must be present`);
  }
  const nav = await text("components/bottom-nav/index.wxml");
  assert.doesNotMatch(nav, /⌂|⌕|♡|◯/);
  assert.match(nav, /assets\/lucide\/heart-handshake\.svg/);
});

test("wires every page interaction to a declared mini-program method and asset", async () => {
  const app = JSON.parse(await text("app.json"));
  for (const page of app.pages) {
    const [script, markup] = await Promise.all([text(`${page}.js`), text(`${page}.wxml`)]);
    const handlers = [...markup.matchAll(/bind(?:tap|input|change|confirm)="([A-Za-z][A-Za-z0-9_]*)"/g)].map((match) => match[1]);
    for (const handler of handlers) {
      assert.match(script, new RegExp(`\\b${handler}\\s*\\(`), `${page} must define ${handler}`);
    }
    for (const match of markup.matchAll(/src="\/(assets\/[^\"]+)"/g)) {
      await text(match[1]);
    }
  }
});
