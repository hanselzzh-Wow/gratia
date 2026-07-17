# 哈喽卧得 MVP

一个“替远方的人去现场完成小心愿”的全栈 MVP。公开页面支持真实心愿发布、同城响应者报名和发布者进度查询；运营台支持人工审核、种子供应者管理、手工派单、交付上传、订单完结与内部数据导出。

## 线上环境

- 用户端：[https://hanselzzh-wow.github.io/](https://hanselzzh-wow.github.io/)
- 运营台：[https://hanselzzh-wow.github.io/ops/](https://hanselzzh-wow.github.io/ops/)
- 生产 API：[https://haluowode-mvp.hanselzzh.workers.dev](https://haluowode-mvp.hanselzzh.workers.dev)

GitHub Pages 提供稳定前端，Cloudflare Worker 提供 API，D1 保存业务数据，R2 保存交付文件。运营台 PIN 保存在本机被 Git 忽略的 `.cloudflare.secrets` 中，不要写入网页、截图或公开仓库。

## 环境要求

- Node.js `>=22.13.0`

## 本地运行

```bash
npm install
cp .dev.vars.example .dev.vars
npm run dev
```

先替换 `.dev.vars` 中的示例值。本地开发环境会模拟 D1 与 R2；运营台地址为 `/ops`，需要通过 `ADMIN_API_KEY` 对应的运营 PIN 进入。不要提交真实的 `.dev.vars`。

## 产品闭环

- 心愿：发布、隐私隔离、人工审核、公开待匹配、状态追踪。
- 供应：公开报名、种子供应者名册、同城筛选、暂停或恢复接单。
- 履约：人工派单、接单确认、照片或视频上传、HTTPS 链接交付、发布者确认完成。
- 运营：PIN 保护、操作限流、内部 CSV 导出、订单与供应者状态管理。
- 存储：D1 保存业务记录，R2 保存交付文件，访问链接带随机能力令牌。

试运营前请阅读 [试运营手册](docs/pilot-runbook.md)。

## 常用命令

- `npm run dev`：启动本地开发环境。
- `npm run build`：生成 Cloudflare Worker 兼容的部署产物。
- `npm test`：执行构建和完整业务闭环测试。
- `npm run lint`：检查代码质量。
- `npm run db:generate`：数据结构变化后生成 Drizzle 迁移。

## 部署

`.openai/hosting.json` 声明 Sites 项目与 D1、R2 绑定。数据结构变化后，需要将 `drizzle/` 下的新迁移随同部署产物一起发布。公开生产部署前，先完成试运营手册中的测试单和隐私检查。

当前生产环境已按[独立 Cloudflare 部署说明](docs/cloudflare-direct-deployment.md)发布到项目所有者自己的 `workers.dev` 地址，并由稳定的 GitHub Pages 前端调用；不再依赖可能被平台安全层拦截的 `chatgpt.site` 地址。
