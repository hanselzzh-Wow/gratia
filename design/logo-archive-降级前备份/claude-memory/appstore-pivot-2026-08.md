---
name: appstore-pivot-2026-08
description: 2026-08-03 产品负责人叫停 Codex 多 AI 流程，改由 Claude 直接推进 iOS App Store 上架
metadata: 
  node_type: memory
  type: project
  originSessionId: cf46a0a4-9762-48cb-8bc4-045efd8bb91e
  modified: 2026-08-03T12:54:28.640Z
---

2026-08-03，产品负责人（Hansangbai）明确指示：**不再走 Codex PM 的任务卡/写入冻结/独立验收流程**（"不要再管任何规范上的限制"），由 Claude 直接实现并推进。优先级从微信小程序 0.1 切回 **iOS App Store 上架**。

- 仓库根的 `CLAUDE.md`、`AGENTS.md`、`.ai/WRITE_FREEZE.md`、`.ai/TASKS.md` 仍描述旧流程，且 `CLAUDE.md` 还把 Claude 钉在早已完成的 `CL-001` 上——**这些文件已过期，不代表当前工作方式**。
- 工作分支：`appstore/1.0`，worktree `worktrees/appstore`。它 = `main` 的账户后端 + `release/1.0` 的 `ios/Gratia` 客户端（已删除过期的 `ios/Haluowode`）。
- 产品形态澄清（推翻了此前"线下服务"的判断）：**交易与交付全程在线上**，交付物是电子照片/视频。因此 Apple 支付条款归属是灰区（3.1.3(e) 外部支付 vs 数字内容 IAP，形态接近 Cameo），1.0 决定**不含任何应用内支付**，感谢金保持申报金额、线下结算。
- 登录方案：**只做 Sign in with Apple**。微信登录在 iOS 上受阻——微信开放平台"移动应用"只接受企业/组织主体，个人主体注册不了。后端 provider 层是 provider-neutral 的（`account_identities(provider, provider_subject)`），微信 provider 已被小程序使用。

**三个外部硬阻塞（只有用户能解）**：
1. Apple Developer Program（$99/年）**未购买**，只有免费 Personal Team——免费账号**无法启用 Sign in with Apple capability**，也不能上传构建。
2. **本机 Xcode 已被卸载**，只剩 Command Line Tools。Swift 只能 `swiftc -frontend -parse` 做语法解析，无法编译/模拟器/归档。CLT 也缺 swift-testing，GratiaCore 测试跑不了。
3. 隐私政策/条款还没有公开 URL，联系邮箱未定。

完整清单见仓库 `docs/app-store-submission.md`。相关：[[home-rose-direction]]
