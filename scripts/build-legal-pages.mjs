// 把 docs/legal/*.md 渲染成可公开托管的静态页面。
// App Store Connect 的隐私政策 URL 必须是可访问链接，这些页面随 GitHub Pages 产物一起发布。
// 只支持这两份文档实际使用的 Markdown 子集：标题、段落、表格、有序/无序列表、引用、分隔线、粗体、行内代码。

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import process from "node:process";

const root = resolve(import.meta.dirname, "..");

const pages = [
  {
    source: "docs/legal/privacy-policy.md",
    slug: "privacy",
    title: "隐私政策",
  },
  {
    source: "docs/legal/terms-of-service.md",
    slug: "terms",
    title: "服务条款",
  },
];

function escapeHtml(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}

function splitRow(line) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
}

const isSeparatorRow = (line) => /^\|[\s:|-]+\|?$/.test(line.trim());

export function markdownToHtml(markdown) {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const out = [];
  let index = 0;

  const flushParagraph = (buffer) => {
    if (buffer.length > 0) out.push(`<p>${inline(buffer.join(" "))}</p>`);
    buffer.length = 0;
  };
  const paragraph = [];

  while (index < lines.length) {
    const line = lines[index];

    if (line.trim() === "") {
      flushParagraph(paragraph);
      index += 1;
      continue;
    }

    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      flushParagraph(paragraph);
      const level = heading[1].length;
      out.push(`<h${level}>${inline(heading[2])}</h${level}>`);
      index += 1;
      continue;
    }

    if (/^-{3,}$/.test(line.trim())) {
      flushParagraph(paragraph);
      out.push("<hr />");
      index += 1;
      continue;
    }

    if (line.trimStart().startsWith("|")) {
      flushParagraph(paragraph);
      const header = splitRow(line);
      let cursor = index + 1;
      const body = [];
      if (cursor < lines.length && isSeparatorRow(lines[cursor])) cursor += 1;
      while (cursor < lines.length && lines[cursor].trimStart().startsWith("|")) {
        body.push(splitRow(lines[cursor]));
        cursor += 1;
      }
      const head = header.map((cell) => `<th>${inline(cell)}</th>`).join("");
      const rows = body
        .map((row) => `<tr>${row.map((cell) => `<td>${inline(cell)}</td>`).join("")}</tr>`)
        .join("");
      out.push(`<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${rows}</tbody></table></div>`);
      index = cursor;
      continue;
    }

    if (/^>\s?/.test(line)) {
      flushParagraph(paragraph);
      const quote = [];
      while (index < lines.length && /^>\s?/.test(lines[index])) {
        quote.push(lines[index].replace(/^>\s?/, ""));
        index += 1;
      }
      out.push(`<blockquote><p>${inline(quote.join(" "))}</p></blockquote>`);
      continue;
    }

    if (/^[-*]\s+/.test(line)) {
      flushParagraph(paragraph);
      const items = [];
      while (index < lines.length && /^[-*]\s+/.test(lines[index])) {
        items.push(`<li>${inline(lines[index].replace(/^[-*]\s+/, ""))}</li>`);
        index += 1;
      }
      out.push(`<ul>${items.join("")}</ul>`);
      continue;
    }

    if (/^\d+\.\s+/.test(line)) {
      flushParagraph(paragraph);
      const items = [];
      while (index < lines.length && /^\d+\.\s+/.test(lines[index])) {
        items.push(`<li>${inline(lines[index].replace(/^\d+\.\s+/, ""))}</li>`);
        index += 1;
      }
      out.push(`<ol>${items.join("")}</ol>`);
      continue;
    }

    paragraph.push(line.trim());
    index += 1;
  }

  flushParagraph(paragraph);
  return out.join("\n");
}

const style = `
:root {
  color-scheme: light;
  --rose: #9A536D;
  --rose-deep: #7F4058;
  --tint: #FAF4F6;
  --ink: #191719;
  --ink2: #706A6D;
  --ink3: #A9A2A5;
  --line: #ECE8EA;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 0 20px 80px;
  background: #fff;
  color: var(--ink);
  font: 16px/1.75 -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", Arial, sans-serif;
  -webkit-text-size-adjust: 100%;
}
.wrap { max-width: 720px; margin: 0 auto; }
header { padding: 44px 0 8px; border-bottom: 1px solid var(--line); margin-bottom: 28px; }
.brand { display: inline-flex; align-items: center; gap: 10px; color: var(--rose); font-weight: 600; letter-spacing: .02em; text-decoration: none; }
.brand svg { display: block; }
h1 { font-size: 28px; line-height: 1.35; margin: 26px 0 6px; }
h2 { font-size: 20px; line-height: 1.4; margin: 38px 0 10px; padding-top: 4px; }
h3 { font-size: 17px; margin: 26px 0 8px; }
p { margin: 12px 0; }
strong { color: var(--rose-deep); }
code { background: var(--tint); padding: 2px 6px; border-radius: 5px; font-size: .9em; }
ul, ol { margin: 12px 0; padding-left: 22px; }
li { margin: 6px 0; }
hr { border: 0; border-top: 1px solid var(--line); margin: 34px 0; }
blockquote { margin: 20px 0; padding: 14px 18px; background: var(--tint); border-left: 3px solid var(--rose); border-radius: 0 10px 10px 0; }
blockquote p { margin: 0; }
.table-wrap { overflow-x: auto; margin: 18px 0; }
table { border-collapse: collapse; width: 100%; font-size: 15px; }
th, td { border: 1px solid var(--line); padding: 9px 12px; text-align: left; vertical-align: top; }
th { background: var(--tint); font-weight: 600; }
footer { margin-top: 56px; padding-top: 20px; border-top: 1px solid var(--line); color: var(--ink3); font-size: 14px; }
footer a { color: var(--rose); }
@media (max-width: 520px) { h1 { font-size: 24px; } body { font-size: 15px; } }
`;

const brandSvg = `<svg width="26" height="26" viewBox="0 0 100 100" aria-hidden="true"><path d="M20 44 C 32 66, 68 66, 80 40" fill="none" stroke="#9A536D" stroke-width="9" stroke-linecap="round"/><circle cx="20" cy="44" r="7" fill="#9A536D"/><circle cx="80" cy="40" r="11" fill="#9A536D"/></svg>`;

function wrap({ title, body }) {
  return `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${title}｜哈喽卧得 Gratia</title>
<meta name="description" content="哈喽卧得（Gratia）${title}" />
<style>${style}</style>
</head>
<body>
<div class="wrap">
<header><a class="brand" href="../">${brandSvg}<span>哈喽卧得 Gratia</span></a></header>
${body}
<footer>哈喽卧得（Gratia）· 联系邮箱 <a href="mailto:hansel.zzh@gmail.com">hansel.zzh@gmail.com</a></footer>
</div>
</body>
</html>
`;
}

const indexPage = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>法律条款｜哈喽卧得 Gratia</title>
<style>${style}</style>
</head>
<body>
<div class="wrap">
<header><span class="brand">${brandSvg}<span>哈喽卧得 Gratia</span></span></header>
<h1>法律条款</h1>
<ul>
<li><a href="privacy/">隐私政策</a></li>
<li><a href="terms/">服务条款</a></li>
</ul>
<footer>联系邮箱 <a href="mailto:hansel.zzh@gmail.com">hansel.zzh@gmail.com</a></footer>
</div>
</body>
</html>
`;

export function buildLegalPages(outputDirectory) {
  const legalRoot = resolve(outputDirectory, "legal");
  mkdirSync(legalRoot, { recursive: true });
  writeFileSync(resolve(legalRoot, "index.html"), indexPage, "utf8");

  const written = [];
  for (const page of pages) {
    const markdown = readFileSync(resolve(root, page.source), "utf8");
    const directory = resolve(legalRoot, page.slug);
    mkdirSync(directory, { recursive: true });
    const html = wrap({ title: page.title, body: markdownToHtml(markdown) });
    writeFileSync(resolve(directory, "index.html"), html, "utf8");
    written.push(`legal/${page.slug}/index.html`);
  }
  return written;
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop())) {
  const target = process.argv[2] ? resolve(process.cwd(), process.argv[2]) : resolve(root, "out");
  const written = buildLegalPages(target);
  console.log(`法务页面已生成于 ${target}：`);
  for (const file of written) console.log(`  ${file}`);
}
