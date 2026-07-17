# 哈喽卧得

一个“替远方的人去现场完成小心愿”的产品。最终消费者客户端将使用 SwiftUI 开发为原生 iOS App，并以 TestFlight 和 App Store 上架为目标；当前仓库已有的 React 页面是历史原型和接口验证工具，不是最终消费者产品。

项目当前状态、短期与长期目标、未决问题和逐步工作记录统一维护在 [PROJECT_LOG.md](PROJECT_LOG.md)。任何新加入的 AI 或开发者都应先阅读该文件。

## 线上环境

- 历史网页原型：[https://hanselzzh-wow.github.io/](https://hanselzzh-wow.github.io/)
- 当前 MVP 运营台：[https://hanselzzh-wow.github.io/ops/](https://hanselzzh-wow.github.io/ops/)
- 生产 API：[https://haluowode-mvp.hanselzzh.workers.dev](https://haluowode-mvp.hanselzzh.workers.dev)

GitHub Pages 当前只保留历史原型和 MVP 运营工具；未来 SwiftUI App 将直接调用 Cloudflare Worker API。D1 保存业务数据，R2 保存交付文件。运营台 PIN 保存在本机被 Git 忽略的 `.cloudflare.secrets` 中，不要写入网页、截图或公开仓库。

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
