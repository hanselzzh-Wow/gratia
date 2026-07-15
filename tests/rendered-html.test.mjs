import assert from "node:assert/strict";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Haluowode MVP", async () => {
  const response = await render("/");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>哈喽卧得｜让想说的话抵达远方<\/title>/i);
  assert.match(html, /许下一个心愿/);
  assert.match(html, /愿望池/);
  assert.match(html, /我恰好在这里/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|Codex is working/i);
});

test("server-renders the PIN-gated operations workspace", async () => {
  const response = await render("/ops");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /心愿运营台/);
  assert.match(html, /运营 PIN/);
  assert.match(html, /刷新后需要重新输入/);
  assert.doesNotMatch(html, /联系方式<\/dt>/);
});
