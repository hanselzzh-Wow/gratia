# 独立 Cloudflare 部署

旧的 `chatgpt.site` 地址可能在应用代码运行前被平台安全层拦截。这个部署路径把同一套经过测试的 Worker、D1 和 R2 直接发布到项目所有者自己的 Cloudflare 账号，并得到独立的 `workers.dev` 地址。稳定的 GitHub Pages 演示站不会被覆盖。

## 首次部署

1. 在终端运行 `npx wrangler login`，按浏览器提示登录 Cloudflare。
2. 先运行 `npm run deploy:cloudflare:dry-run`，确认部署包可生成。
3. 可运行 `npm run secrets:cloudflare:init` 预先生成运营 PIN 和限流盐值；如果跳过，正式部署时也会自动安全生成。
4. 明确确认要创建公开资源后，运行 `npm run deploy:cloudflare`。

秘密值只保存在被 Git 忽略的 `.cloudflare.secrets` 中，文件权限会收紧为仅当前用户可读写；运营后台需要的 PIN 是其中的 `ADMIN_API_KEY`。脚本会拒绝示例值、过短值或两个相同的值。

正式部署脚本会依次构建应用、确认 Cloudflare 登录、通过一次预配置部署创建或复用 D1/R2、动态读取 D1 标识并生成被忽略的本机迁移配置、应用 `drizzle/` 中的迁移，最后携带秘密变量再次部署稳定版本。账户专属的数据库 UUID 与存储桶名称不会提交到项目配置。R2 首次使用前需要在 Cloudflare 控制台完成订阅启用；启用后脚本会自动创建或复用存储桶。

## 部署后验收

1. 先运行只读检查：`npm run verify:production -- https://<worker>.workers.dev`。
2. 再运行完整闭环：`npm run verify:production -- https://<worker>.workers.dev --full`。
3. 完整闭环会验证健康状态、CORS、未授权拦截、发布、审核、供应者派单、R2 文件交付、追踪、隐私字段、完结和运营导出；测试供应者最后会自动暂停。
4. 验收通过后，运行 `npm run build:github-pages -- https://<worker>.workers.dev` 生成已连接完整后端的 `out/` 静态站。
5. 脚本会先清空旧 `out/`，再拒绝非 HTTPS、带路径或 `chatgpt.site` 地址，并检查首页、运营台、后端地址和 `.nojekyll` 发布要求；确认无误后才把新的 `out/` 发布到 GitHub Pages。

不要在 API 健康检查和完整测试单通过前切换稳定演示站。
