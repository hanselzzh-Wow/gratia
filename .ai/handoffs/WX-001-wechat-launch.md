# WX-001｜微信小程序 0.1 上线候选交接

状态：`READY_FOR_CODEX_ACCEPTANCE`
实现 commit：`13c31c36574ebb568adb727dea22da9c06c75701`
分支：`codex/wx-001-launch`
基线：`3cbbe2a`（WX-001 协调授权）

## 实际交付

- 新建原生微信小程序工程 `miniprogram/` 及根目录 `project.config.json`：固定五栏（首页、搜索、发布、帮助、我的）和交付预览页。首页/搜索严格保留 1.0 的真实公开故事空态；帮助页才显示已审核待匹配的真实心愿。Dock 由 iOS 浮动样式适配为小程序固定底栏，使用随工程分发的 Lucide SVG。
- 发布为三步流：第 1 步只显示城市/地标，不出现右侧“地点”标签；最终提交说明人工审核，并在发送前调用微信登录。帮助响应同样登录后提交。
- 新增 Worker/D1 账户模型：`users`、`account_identities`、哈希 `account_sessions`；首个 identity provider 为 `wechat`，订单/响应写入 `user_id`，保留未来 Apple provider 的空间。
- 新增受保护账户接口：`POST /api/auth/wechat`、`GET/DELETE /api/me`、`GET/POST /api/account/wishes`、`POST /api/account/wishes/:id/responses`、`POST /api/account/wishes/:id/complete`、`GET /api/account/wishes/:id/deliverable`。旧无登录网页/iOS 接口保持不变。
- 交付文件以账户授权的流式端点读取到小程序临时文件；小程序不展示 R2 能力 URL 或交付 token。账户删除撤销会话、删除微信 identity、匿名化称呼/联系方式，保留去标识订单审计状态。
- 新增 `drizzle/0005_wechat_account_identity.sql`、`docs/wechat-mini-program-launch.md` 与试运营手册补充。文档清晰区分已实现与待微信控制台核实项目。

## 实际验证

在该 worktree 执行：

```bash
npm run lint
npm test
git diff --check
```

结果：

- `npm run lint`：通过，0 error / 0 warning。
- `npm test`：通过，16/16；包括既有工作流、Worker 构建、微信身份→发布→人工审核→响应→交付→发布者确认→账户删除、未配置微信服务端凭据拒绝、五目的地工程、密钥静态扫描、Lucide 资源和页面交互/资源链接静态检查。
- `git diff --check`：通过，零输出。
- `npm run build` 被 `npm test` 实际执行并通过；Vinext 仍报告既有“动态 API 使用无法静态分类”的 informational 提示，非失败。

## 安全与兼容核对

- 小程序源码不含 `WECHAT_MINI_PROGRAM_APP_SECRET`、`session_key`、`x-admin-key` 或 R2 `access_token`；静态测试覆盖此项。
- Worker 只在私密环境读取 `WECHAT_MINI_PROGRAM_APP_ID`、`WECHAT_MINI_PROGRAM_APP_SECRET`；未配置时登录返回 503，绝不降级为假账户。
- 公共 `GET /api/wishes` 仍只返回审核通过/待匹配的公开字段；联系方式、运营 PIN、身份标识和交付能力 URL 不会出现在公开列表。

## 平台适配记录

| 1.0 设计 | 小程序候选 |
| --- | --- |
| iOS 原生浮动 Dock | 固定安全区底栏，保留五目的地和中央玫粉发布动作 |
| iOS 系统登录/设置 | `wx.login` + Worker 会话；不请求系统通知设置或不必要权限 |
| 公开故事首页/搜索 | 没有真实故事 API 时维持 1.0 诚实空态；不把帮助列表伪装成故事 |
| 交付预览 | 经账户授权下载至临时文件后用小程序视频/图片控件展示，不显示能力 URL |

## 未验证与不可代办动作

1. 本机未发现微信开发者工具 CLI/App；因此未获得真实工具导入、编译、预览截图或体验版上传证据。`project.config.json` 与原生文件/交互静态测试通过，但不替代工具验证。
2. 没有真实微信 AppID/AppSecret、主体或私密 Worker 环境，故未对微信 `code2Session` 发真实请求，也未设置任何秘密或生产部署。
3. 主体类目、服务域名/备案、隐私指引字段、体验者资格、测试账号、客服/投诉入口与最终审核都必须在实际微信控制台核实；详见 `docs/wechat-mini-program-launch.md`。
4. 未执行真实 D1 迁移或生产只读/部署检查，避免更改线上数据和服务；迁移 SQL 已备妥。

## 停止状态

实现 worktree 已完成并停止写代码。Codex PM 需在独立证据下验收、决定是否合入 `main`，并同步任务板、冻结、接班卡与项目日志；不得将“工具/平台未验证”表述为已上线。
