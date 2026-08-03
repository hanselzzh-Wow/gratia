# Gratia iOS 1.0 上架 App Store 交接

更新：2026-08-03　｜　分支：`appstore/1.0`　｜　基线：`release/1.0` 的 `ios/Gratia` + `main` 的账户后端

本文是提交 App Store 前的完整清单。**带「必须由产品负责人完成」标记的条目无法由代码解决**，它们依赖 Apple 账户、真实主体或外部服务。

---

## 一、当前阻塞项（按顺序解决）

| # | 阻塞项 | 影响 | 谁来做 |
| --- | --- | --- | --- |
| B1 | **未购买 Apple Developer Program（$99/年）** | 无法创建 App Store Connect 记录、无法启用 Sign in with Apple capability、无法上传构建、无法 TestFlight。免费 Personal Team **不能**启用 Sign in with Apple。 | 必须由产品负责人完成 |
| B2 | **本机未安装 Xcode** | 无法编译 iOS、无法跑模拟器、无法归档上传。当前只有 Command Line Tools，Swift 仅能做语法解析。 | 必须由产品负责人完成（App Store 下载 Xcode） |
| B3 | **隐私政策与服务条款尚无公开 URL** | App Store Connect 的隐私政策 URL 为必填。 | 需托管，见第五节 |
| B4 | **Worker 未部署账户层** | 生产 Worker 目前没有 `/api/auth/apple`、`/api/me`，App 登录会 404。 | 需部署，见第六节 |
| B5 | **联系邮箱未确定** | 隐私政策、服务条款、App Store Connect 的 App 支持 URL 与审核联系人都需要真实可联系渠道。 | 必须由产品负责人完成 |

B1 和 B2 可以并行开始，两者都需要较长等待时间。

---

## 二、Apple Developer Program 开通与配置

### 2.1 开通

1. 访问 <https://developer.apple.com/programs/enroll/>，用你的 Apple ID 报名个人（Individual）会员，$99/年。
2. 个人会员的 App Store 显示名会是你的**真实姓名**。若希望显示公司名，需要以企业身份报名，并额外提供邓白氏编码（D-U-N-S），周期显著更长。**这一步选哪种要先想清楚，后期更换很麻烦。**
3. 报名审核通常 1–2 个工作日，也可能更久。

### 2.2 开通后需要拿到的三个值

在 <https://developer.apple.com/account> 里获取，然后告诉我，我会写进配置：

| 值 | 在哪找 | 用途 |
| --- | --- | --- |
| **Team ID** | Membership details 页 | Xcode 签名、Apple 令牌撤销 |
| **Key ID** | Certificates, Identifiers & Profiles → Keys → 新建一个勾选 **Sign in with Apple** 的密钥 | Apple 令牌撤销 |
| **`.p8` 私钥文件** | 创建密钥时下载（**只能下载一次，务必保存好**） | Apple 令牌撤销 |

### 2.3 开启 capability

1. Identifiers → 找到或新建 App ID `com.hanselzzh.gratia`。
2. 勾选 **Sign in with Apple**，保存。
3. 代码侧已就绪：`ios/Gratia/Gratia.entitlements` 已声明 `com.apple.developer.applesignin`，`project.yml` 已配置 `CODE_SIGN_ENTITLEMENTS`。

> **注意**：`.p8` 私钥只用于"用户注销时撤销 Apple 登录令牌"。**没有它登录照样能用**——身份令牌验证只需要 Apple 的公开密钥。但 Apple 要求应用在删除账户时撤销令牌，所以正式提交前应配置好。

---

## 三、App Store Connect 建 App 记录

在 <https://appstoreconnect.apple.com> → My Apps → +：

| 字段 | 填什么 | 说明 |
| --- | --- | --- |
| 平台 | iOS | |
| 名称 | 哈喽卧得 | App Store 显示名，全球唯一，先去搜一下有没有被占用 |
| 主要语言 | 简体中文 | |
| Bundle ID | `com.hanselzzh.gratia` | 必须与 2.3 建的 App ID 一致 |
| SKU | `gratia-ios-1` | 内部编号，随便填但不可改 |

### 3.1 版本信息

- **版本号**：1.0.0（已写进 `Info.plist` 的 `CFBundleShortVersionString`）
- **构建号**：1（`CFBundleVersion`）
- **分类**：建议主分类"生活"（Lifestyle），副分类"社交"
- **年龄分级**：见第四节
- **App 支持 URL**：必填，需要一个能联系到你的公开页面
- **隐私政策 URL**：必填，见第五节

### 3.2 需要准备的素材

| 素材 | 规格 | 状态 |
| --- | --- | --- |
| App 图标 | 1024×1024 PNG，无透明通道、无圆角 | 已有（玫红钥匙图标，在 `Assets.xcassets/AppIcon.appiconset`），**需确认 1024 版本无 alpha 通道** |
| 6.9" 截图 | 1320×2868，至少 1 张，最多 10 张 | **待生成**（需要 Xcode + 模拟器） |
| 6.5" 截图 | 1242×2688 | **待生成** |
| 宣传文本 | ≤170 字符 | 待写 |
| 描述 | ≤4000 字符 | 待写 |
| 关键词 | ≤100 字符，逗号分隔 | 待写 |

截图必须来自真实运行的 App，不能是设计稿。这一项被 B2（没有 Xcode）阻塞。

---

## 四、年龄分级与导出合规

### 4.1 年龄分级问卷

按当前功能，建议答案：

| 问题 | 答案 | 理由 |
| --- | --- | --- |
| 卡通或幻想暴力 | 无 | |
| 现实暴力 | 无 | |
| 色情内容或裸露 | 无 | |
| 亵渎或粗俗幽默 | 无 | |
| 酒精、烟草或毒品 | 无 | |
| 赌博 | 无 | |
| 医疗/治疗信息 | 无 | |
| **不受限制的网页访问** | **无** | App 内没有内置浏览器；外部交付链接用系统 `Link` 在 Safari 打开 |
| **用户生成内容** | **有** | 心愿正文、响应说明、交付内容都是用户产出 |

**关键**：勾选"用户生成内容"后，Apple 会要求你说明内容审核机制（指南 1.2）。我们的答案是：**所有发布内容先进入 `pending_review`，由运营人工审核通过后才公开**；这已经在代码里实现，也写进了服务条款。这是本 App 通过 1.2 条款的核心论据，审核备注里必须写清楚。

预期分级：**17+ 或 12+**（取决于 Apple 对 UGC 的判定）。

### 4.2 导出合规

`Info.plist` 已加入 `ITSAppUsesNonExemptEncryption = false`——App 只使用 HTTPS 标准加密，属于豁免范围。加了这一项后，每次上传构建不会再重复弹出加密问卷。

---

## 五、App 隐私问卷（App Privacy）逐项答案

在 App Store Connect → App 隐私 中按此填写。这些答案与 `ios/Gratia/PrivacyInfo.xcprivacy` 和《隐私政策》**必须完全一致**，不一致是常见的退回原因。

| 数据类型 | 是否收集 | 是否关联到用户 | 是否用于追踪 | 用途 |
| --- | --- | --- | --- | --- |
| **用户 ID** | 是 | 是 | 否 | App 功能（Apple 匿名 `sub`，用于识别账户） |
| **姓名** | 是 | 是 | 否 | App 功能（发布/响应时填写的称呼） |
| **其他联系信息** | 是 | 是 | 否 | App 功能（履约联系方式） |
| **其他用户内容** | 是 | 是 | 否 | App 功能（心愿正文、响应说明、交付照片/视频） |
| **粗略位置** | 是 | 是 | 否 | App 功能（用户手填的城市与地标，非设备定位） |
| 精确位置 | 否 | — | — | 不使用系统定位 |
| 邮箱地址 | **否** | — | — | 明确不接收 Apple 提供的邮箱 |
| 支付信息 | 否 | — | — | App 内不收款 |
| 联系人 | 否 | — | — | |
| 标识符（设备 ID / 广告 ID） | 否 | — | — | 无广告 SDK |
| 使用数据 / 诊断 | 否 | — | — | 无第三方分析 SDK |

**追踪（App Tracking Transparency）**：全部为"否"。App 不含任何跨应用追踪，因此**不需要** ATT 弹窗、不需要 `NSUserTrackingUsageDescription`。

### 5.1 隐私政策与条款托管

已写好正文：

- `docs/legal/privacy-policy.md`
- `docs/legal/terms-of-service.md`

项目已有 GitHub Pages 站点（`https://hanselzzh-wow.github.io/`），最省事的做法是把这两份渲染成页面挂上去，得到两个稳定 URL。**上架前必须先把两份文档里的"联系邮箱"占位替换成真实地址。**

---

## 六、后端部署

生产 Worker（`https://haluowode-mvp.hanselzzh.workers.dev`）目前**还没有**账户层。上架前需要：

1. 部署本分支的 Worker，使其提供 `/api/auth/apple`、`GET /api/me`、`DELETE /api/me`、`/api/account/**`。
2. 执行 D1 迁移 `drizzle/0005_wechat_account_identity.sql` 与 `drizzle/0006_apple_identity_refresh_token.sql`。运行时 `ensureWishSchema` 也会自动补列，但受控迁移更稳妥。
3. 在 Worker 的**私密环境变量**中配置（绝不写进代码或 Git）：

```
APPLE_BUNDLE_ID   = com.hanselzzh.gratia
APPLE_TEAM_ID     = （2.2 拿到的 Team ID）
APPLE_KEY_ID      = （2.2 拿到的 Key ID）
APPLE_PRIVATE_KEY = （.p8 文件的完整内容，含 BEGIN/END 行）
```

只配 `APPLE_BUNDLE_ID` 时登录可用，但注销时不会撤销 Apple 令牌。四个都配齐才完全符合 Apple 要求。

---

## 七、审核备注（App Review Notes）

提交时把下面这段填进"备注"，能显著降低来回次数：

> **产品说明**
> 哈喽卧得（Gratia）是心愿委托与互助信息撮合平台。用户 A 发布一个希望远方的人代为完成的小心愿（例如"替我去这座桥上拍一张日落"），平台运营人工审核后匹配当地的用户 B，B 完成后通过 App 向 A 交付照片或视频。
>
> **关于用户生成内容（指南 1.2）**
> 所有用户发布的心愿在提交后进入 `pending_review` 状态，**必须经过运营人工审核通过后才会公开展示**，未审核内容不会出现在任何公开列表中。App 内提供"帮助与安全中心"，用户可举报骚扰、违法或不安全内容；运营可拒绝、暂停或取消任何订单。服务条款中已明确列出禁止发布的内容类型。
>
> **关于账户与登录（指南 5.1.1）**
> 浏览公开内容**不需要登录**。仅在发布心愿或响应帮助时需要账户。登录方式为 Sign in with Apple，我们只接收 Apple 提供的匿名用户标识，**不请求姓名与邮箱**。
> 删除账户入口：**我的 → 账户 → 删除我的账户**，可在 App 内直接完成，无需联系客服。删除时服务端会调用 Apple 的 `/auth/revoke` 接口撤销登录令牌。
>
> **关于支付（指南 3.1）**
> 本 App **不包含任何应用内支付**，也不使用 App 内购买。心愿中的"感谢金"仅为用户申报的金额，用于表达心意程度，不构成 App 代收的款项；实际结算由运营在履约完成后与双方线下另行确认。App 不收集任何支付信息。
>
> **关于权限**
> 本版本只在用户主动点击"保存到相册"时申请相册的**仅添加（add-only）**权限。不申请定位、通讯录、相机或麦克风。
>
> **测试账号**
> 无需测试账号，请使用审核人员自己的 Apple ID 通过 Sign in with Apple 登录即可。若需要查看已完成的交付内容，请联系我们提供演示订单编号。

---

## 八、代码侧已完成的内容

| 项目 | 位置 | 验证 |
| --- | --- | --- |
| Apple 身份令牌服务端验签（JWKS、iss/aud/exp/nonce） | `server/apple-identity.ts` | 7/7 测试通过 |
| `POST /api/auth/apple` | `worker/index.ts` | 同上 |
| provider-neutral 会话签发（微信 + Apple 共用账户表） | `server/accounts-repository.ts` | 同上 |
| 注销时撤销 Apple 令牌（失败不阻断注销） | `worker/index.ts` + `server/apple-identity.ts` | 同上 |
| `account_identities.refresh_token` 迁移 | `drizzle/0006_*.sql`、`db/runtime.ts` | 同上 |
| iOS Sign in with Apple（含 nonce） | `ios/Gratia/AccountViewModel.swift`、`AccountSectionView.swift` | 语法解析通过，**未编译** |
| 会话存 Keychain（ThisDeviceOnly，不进 iCloud） | `ios/Gratia/SessionStore.swift` | 同上 |
| 应用内删除账户 + 二次确认 + 后果说明 | `ios/Gratia/AccountSectionView.swift` | 同上 |
| 保存交付照片到相册（仅添加权限） | `ios/Gratia/DeliverySaver.swift` | 同上 |
| 权限用途说明、导出合规 | `ios/Gratia/Info.plist` | — |
| Sign in with Apple entitlement | `ios/Gratia/Gratia.entitlements`、`project.yml` | — |
| 隐私清单 | `ios/Gratia/PrivacyInfo.xcprivacy` | — |
| 修复"消息通知设置"死行 | `ios/Gratia/ProfileView.swift` | 同上 |
| 发布/响应改走 `/api/account/**` 带 Bearer，未登录不发请求 | `PublishWishViewModel.swift`、`WishResponseViewModel.swift` | 同上（新增 6 个 XCTest 用例待跑） |
| "我发布的 / 我帮助的"展示真实账户记录 | `AccountActivityViewModel.swift`、`ProfileView.swift` | 同上 |
| 发布者"确认已完成" | `ProfileView.swift` → `/api/account/wishes/{id}/complete` | 同上 |

**未验证**：所有 iOS 代码只做了 Swift 语法解析，**没有编译、没有运行、没有模拟器或真机验证**，因为本机没有 Xcode。装好 Xcode 后必须完整跑一遍构建与测试。

---

## 九、尚未完成的功能项

| 项目 | 说明 | 是否阻塞上架 |
| --- | --- | --- |
| 推送通知 | 需要 APNs 配置与后端推送服务 | 不阻塞，1.1 再做 |
| 应用内支付 | 需要企业主体 + 商户号；且需先与 Apple 确认按 3.1.3(e) 走外部支付还是按数字内容走 IAP | 不阻塞 1.0（1.0 无支付） |
| 微信登录（iOS） | 微信开放平台"移动应用"只接受企业/组织主体，个人主体无法注册 | 不阻塞，后端 provider 已就绪 |

---

## 十、建议的推进顺序

1. **今天**：开始下载 Xcode（B2）；决定个人还是企业会员并报名 Developer Program（B1）；确定联系邮箱（B5）。
2. Developer Program 通过后：拿 Team ID、建 Sign in with Apple 密钥、下载 `.p8`，交给我配置。
3. Xcode 装好后：我生成工程、编译、跑测试、出模拟器截图。
4. 把隐私政策与条款挂上 GitHub Pages，拿到两个 URL（B3）。
5. 部署 Worker 账户层并配好 Apple 私密变量（B4）。
6. 建 App Store Connect 记录、填 App 隐私问卷、年龄分级、审核备注。
7. 真机试用完整闭环 → 归档上传 → TestFlight 自测 → 提交审核。
