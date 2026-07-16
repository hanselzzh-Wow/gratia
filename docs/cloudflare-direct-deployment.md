# 独立 Cloudflare 部署

旧的 `chatgpt.site` 地址可能在应用代码运行前被平台安全层拦截。这个部署路径把同一套经过测试的 Worker、D1 和 R2 直接发布到项目所有者自己的 Cloudflare 账号，并得到独立的 `workers.dev` 地址。稳定的 GitHub Pages 演示站不会被覆盖。

## 首次部署

1. 在终端运行 `npx wrangler login`，按浏览器提示登录 Cloudflare。
2. 复制 `.cloudflare.secrets.example` 为 `.cloudflare.secrets`。
3. 将两个示例值替换为不同的长随机值；不要提交该文件。
4. 先运行 `npm run deploy:cloudflare:dry-run`，确认部署包可生成。
5. 明确确认要创建公开资源后，运行 `npm run deploy:cloudflare`。

脚本会依次构建应用、为 `DB` 自动创建或复用 D1、应用 `drizzle/` 中的迁移、创建或复用 R2，并携带秘密变量部署 Worker。首次执行时，Wrangler 可能要求确认自动创建资源。

## 部署后验收

1. 访问返回地址的 `/api/health`，应看到 `ok: true` 和 `database: "ready"`。
2. 从 GitHub Pages 域名发起一次 CORS 预检，响应应允许 `https://hanselzzh-wow.github.io`。
3. 用测试信息完成发布、审核、种子供应者派单、交付和完结。
4. 确认公开愿望接口不返回发布者或响应者联系方式。
5. 验收通过后，再以 `NEXT_PUBLIC_API_BASE_URL=<workers.dev 地址>` 重新构建 GitHub Pages 前端。

不要在 API 健康检查和完整测试单通过前切换稳定演示站。
