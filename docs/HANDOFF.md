# 哈喽卧得 / Gratia 交接文档

最后更新：2026-08-06　｜　分支：`appstore/1.0`

> 接手前请依次读：本文件 → [`docs/iteration-log.md`](iteration-log.md)（为什么变成现在这样）→ [`AGENTS.md`](../AGENTS.md)（协作与记录规则）。
> `PROJECT_LOG.md` 是只追加的验收证据，需要追溯具体结论时再查。

---

## 一、这是什么

**替远方的人，去现场完成一个小心愿。** 发布者写下城市、地标和想说的话；当地愿意帮忙的人响应；双方在应用内私聊确认细节；帮助者到现场完成后提交照片或视频；发布者确认完成，并可单独决定是否公开到首页。

App 内**不涉及任何金额**，**不收集任何联系方式**。

---

## 二、当前状态

| | 状态 |
| --- | --- |
| 分支 | `appstore/1.0`（`main` 停在 2026-07-20，不再是实现来源） |
| 生产 API | `https://haluowode-mvp.hanselzzh.workers.dev` 运行中 |
| 数据库迁移 | `0000`–`0010` 全部已应用 |
| 运营台 | `https://hanselzzh-wow.github.io/ops/` |
| 法务页面 | `/legal/privacy/`、`/legal/terms/` 已公开 |
| Apple 令牌撤销 | **已端到端验证通过**（2026-08-06） |
| TestFlight | 构建 7 已上传并 VALID（含地点搜索改动） |
| 后端测试 | 30/30 |
| iOS 测试 | 41/41 |

### 下一个构建号是 7

构建 1–6 已被 App Store Connect 占用，构建号不能复用。`ios/project.yml` 的 `CURRENT_PROJECT_VERSION` 已置为 7，打包前不必再改；**上传成功后要立刻加一**。

核实当前已占用的构建号（`xcrun altool` 在 Xcode 26 已没有列出构建的子命令，故直接调 API）：

```bash
node scripts/asc-builds.mjs
```

### 发布页地点已改为 MapKit 搜索（已验证，已提交）

原先的五个写死城市（杭州/上海/北京/深圳/广州）已移除，改为 `MKLocalSearchCompleter` 补全 + 允许手输，`city` 不再默认「杭州」。见 `ios/Gratia/PlaceSearch.swift` 与 `docs/iteration-log.md` 的 2026-08-06 条。

**改这块之前必须知道**：界面上只有一个地点输入框，**没有城市输入框**，而服务端对 `city` 有 2–24 字校验。所以拆分逻辑一旦让 `city` 超长或留空，用户在界面上无从修复，只能卡住。`PlaceSearch.swift` 里所有拆分路径最后都会经过 `Suggestion.clamped(_:)`，`GratiaTests/PlaceSearchTests.swift` 逐条断言结果落在这个窗口内——**改动拆分逻辑时请保持这条断言**。

未在真机上人工核对过补全结果的真实形态，境外地点尤其如此（详见迭代记录的「未验证项」）。

---

## 三、环境准备

```bash
# Node（项目要求 >=22.13.0）
brew install node@22
export PATH="/opt/homebrew/opt/node@22/bin:$PATH"

cd ~/Developer/gratia
npm install
```

Xcode 工程由 XcodeGen 生成，**不要手工编辑 `.xcodeproj`**：

```bash
cd ios && ../.tools/xcodegen/xcodegen/bin/xcodegen generate --spec project.yml
```

---

## 四、日常命令

| 目的 | 命令 |
| --- | --- |
| 后端测试 | `npm test`（**会先 build**，见下方陷阱） |
| 后端 lint | `npm run lint` |
| 部署（含迁移） | `npm run deploy:cloudflare` |
| 部署预演 | `npm run deploy:cloudflare:dry-run`（不接触 Cloudflare） |
| 生成网站产物 | `npm run build:github-pages -- https://haluowode-mvp.hanselzzh.workers.dev` |
| 生成法务页面 | `node scripts/build-legal-pages.mjs` |
| 查已占用的构建号 | `node scripts/asc-builds.mjs` |
| 打并上传 iOS 构建 | `node scripts/ios-release.mjs --upload`（见第九节） |
| iOS 测试 | `cd ios && xcodebuild -project Gratia.xcodeproj -scheme Gratia -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -configuration Debug CODE_SIGNING_ALLOWED=NO test` |

### ⚠️ 陷阱：测试跑的是构建产物

`tests/*.test.mjs` 加载的是 `dist/server/index.js`，**不是源码**。直接跑 `node --test` 会测到上一次构建的旧代码，源码改动看起来「没有效果」。必须用 `npm test`（它会先 `npm run build`）。

这个坑真实浪费过一小时排查时间，详见 `docs/iteration-log.md`。

---

## 五、凭据在哪

**所有密钥都不在代码库里。**

| 凭据 | 位置 | 用途 |
| --- | --- | --- |
| 运营台 PIN | `.cloudflare.secrets` 的 `ADMIN_API_KEY`（本机，已 gitignore） | 登录运营台 |
| 限流盐值 | 同上 `RATE_LIMIT_SALT` | 请求指纹 |
| App Store Connect API | `~/Documents/哈喽卧得-降级前备份/AuthKey_${ASC_KEY_ID}.p8` | 构建上传、TestFlight 管理 |
| Cloudflare | `wrangler login` 的 OAuth 令牌（本机 keyring） | 部署 |
| GitHub | `gh auth login`（本机 keyring） | 发布运营台与法务页面 |

**关键标识**（这些不是机密）：

```
Team ID            HH9LKGK7DA
Bundle ID          com.hanselzzh.gratia
App Store App ID   6798480891
ASC Key ID         ${ASC_KEY_ID}
ASC Issuer ID      ${ASC_ISSUER_ID}
D1 数据库          haluowode-mvp-db
Worker             haluowode-mvp
```

> **生产资源名保留 `haluowode-` 前缀是刻意的。** `scripts/deploy-cloudflare.mjs:61` 会用 Worker 名推导 D1 库名（`${name}-db`），改名等于一次数据迁移。品牌名与基础设施标识是两件事。

### 数据库备份

部署前务必先导出：

```bash
npx wrangler d1 export haluowode-mvp-db --remote \
  --output=~/Developer/gratia-backups/d1-$(date +%Y%m%d-%H%M%S).sql
```

备份**必须放在仓库外**——里面有真实用户数据。已有备份在 `~/Developer/gratia-backups/`。

---

## 六、架构

```
iOS (SwiftUI, iOS 18+)          运营台 (Next/vinext → GitHub Pages)
        │                                    │
        └──────────► Cloudflare Worker ◄─────┘
                            │
                    ┌───────┴───────┐
                   D1              R2
              (业务数据)      (交付文件/头像)
```

- **账号层是 provider-neutral 的**：`account_identities` 表按 `(provider, provider_subject)` 唯一。现有 `apple` 与 `wechat` 两个 provider，加 Google 只是加一行。这是 2026-07 微信小程序转向时的产物，回到 App Store 时几乎原样复用。
- **交付文件用随机能力令牌访问**，不可枚举。
- **iOS 端不含任何运营密钥。**

### 五个标签页

| # | 页面 | 说明 |
| --- | --- | --- |
| 0 | 首页 | 公开故事流；右上角进搜索 |
| 1 | 帮助 | 待帮助的心愿列表 |
| 2 | 发布 | **不是页面**，是中央动作，弹出发布流程 |
| 3 | 私聊 | 会话列表，带未读角标 |
| 4 | 我的 | 个人资料、我发布的/我帮助的、支持、账户 |

---

## 七、四类人工审核

| 审核对象 | 触发 | 未通过时 |
| --- | --- | --- |
| 心愿正文 | 发布后 | 不进任何公开列表 |
| 昵称与头像 | 提交修改后 | 他人看上一版通过的 |
| 公开到首页 | 发布者申请公开 | 不进首页故事流 |
| 举报 | 用户提交后 | —— |

私聊消息与一对一交付**不做事前审核**，靠举报与屏蔽兜底。运营读取被举报会话**必须由一条具体举报触发**，不能凭空翻阅用户对话。

运营台四个面板都已接通，PIN 校验用常量时间比较（`worker/index.ts:170`），限流 10 分钟 80 次。

---

## 八、还没做完的

### ~~提审前必须验证~~ 已于 2026-08-06 验证通过

**Apple 令牌撤销已端到端跑通。** `APPLE_TEAM_ID`、`APPLE_KEY_ID`（`YB5V2N9R2W`）、`APPLE_PRIVATE_KEY` 均已写入，线上六个密钥齐全。

Apple 要求使用 Sign in with Apple 且支持账户删除的 App **必须在删除时撤销令牌**，审核会实测。

验证过程与证据：

1. 用与 `server/apple-identity.ts:144` 完全相同的方式构造 client_secret 打 Apple 真实端点，返回 `invalid_grant` 而**不是** `invalid_client`——Team ID、Key ID、私钥、bundle 四项匹配；
2. 在设备上重新登录后，生产库 `account_identities.refresh_token` 由 NULL 变为非空。**这一条本身就证明生产 Worker 成功调用了 Apple 真实端点**：要存下这个值，必须读到密钥、正确解析 PEM、签出 Apple 认可的 ES256 client_secret、且 Apple 返回 200，任何一环失败都只会存 NULL（`server/apple-identity.ts:190`）；
3. 删除账户后，`refresh_token` 清空、`provider_subject` 抹为 `deleted:`、全部会话 `revoked_at` 非空；
4. Apple ID 设置 →「使用您 Apple ID 的 App」里 Gratia 已消失——**这一步才是 Apple 侧真的撤销了的证据**。

第 4 步不可省。撤销失败时删除照样进行（`worker/index.ts:326`：「撤销失败不回滚删除」），所以第 3 步那组数据库状态在「撤销成功」和「撤销失败但账户删了」两种情况下**完全一样**。

再次验证时按同样顺序走，并注意下面这个陷阱。

#### ⚠️ 直接删旧账户会得到假绿灯

`refresh_token` 是**登录时**用 `authorizationCode` 换来的（`worker/index.ts:305`）。密钥配置之前登录的账户，这一列是 NULL。而删除时的查询只取 `refresh_token IS NOT NULL` 的 identity（`server/accounts-repository.ts:130`），`appleTokensRevoked` 又初始化为 `true`（`worker/index.ts:328`）——于是循环一次都不进，响应照样是 `appleTokensRevoked: true`，**但一次 Apple 调用都没发生**。

这不是 bug（没有令牌就没有要撤销的东西），但拿它当验收证据必然误判。2026-08-06 时生产库里那唯一一个 apple identity 正是这种状态。

正确的验收顺序：

1. **重新登录一次**（配好密钥之后的登录才会换到并存下 refresh token）；
2. 确认真的存下了：
   ```bash
   npx wrangler d1 execute haluowode-mvp-db --remote --command "SELECT provider, COUNT(*) AS n, SUM(CASE WHEN refresh_token IS NOT NULL THEN 1 ELSE 0 END) AS with_token FROM account_identities WHERE deleted_at IS NULL GROUP BY provider"
   ```
   `with_token` 必须 ≥ 1，否则后面测的还是空转；
3. 在 App 内删除该账户，响应里的 `appleTokensRevoked` 必须为 `true`；
4. 到 Apple ID 设置 →「使用您 Apple ID 的 App」里确认 Gratia 已消失。第 4 步才是真正的证据,第 3 步只说明 Worker 认为自己成功了。

> 换新密钥时：在 [developer.apple.com/account/resources/authkeys/add](https://developer.apple.com/account/resources/authkeys/add) 新建，勾选 Sign in with Apple，关联 `com.hanselzzh.gratia`，下载 `.p8`（**只能下一次**），然后把上面三个 secret 重新 `npx wrangler secret put` 一遍。`APPLE_PRIVATE_KEY` 可以把 `.p8` 整份管道进去，PEM 头尾与换行都会被剥掉（`server/apple-identity.ts:126`）；另两个要用 `echo -n`，尾部换行会一起存进去。

### 不阻塞但已知

- **界面没有多语言**：iOS 端 381 条、服务端 139 条中文硬编码。`InfoPlist.strings` 已有中英两版（桌面名跟随系统语言），但界面内容永远是中文。做全球市场时需要抽 `Localizable.strings`。
- **推送通知未实现**：无 APNs 配置、无权限申请。「消息通知设置」入口已移除，实现推送时需连同权限申请一起加回。
- **心愿场景与交付形式仍是中国语境**：「生日祝福/口播视频/手写卡片」等选项写死在客户端。
- **中国区上架另有门槛**：ICP 备案要求域名指向境内服务器，而后端在 Cloudflare；社交/UGC 类应用还涉及实名制要求。**TestFlight 不受影响**，仅正式上架含中国大陆时相关。这块需要专业合规意见，不要只依赖仓库里的记述。

---

## 九、发布流程

### 打新构建

```bash
node scripts/ios-release.mjs --upload
```

它按顺序做：核对构建号没被占用 → 重新生成工程 → 归档 → **校验归档产物** → 导出 → 验证 → 上传。不加 `--upload` 就停在验证，只产出 IPA。

上传成功后**立刻**把 `ios/project.yml` 的 `CURRENT_PROJECT_VERSION` 加一。构建号一经上传即被占用，撞号要等到上传那一刻才报错。

签名参数写在 `ios/project.yml` 的 **Release** 配置里（Manual + `Apple Distribution` + 描述文件 `Gratia App Store`），命令行不要再覆盖。分发证书在登录钥匙串，描述文件通过 App Store Connect API 创建，都不依赖 Xcode 图形界面登录。

#### ⚠️ 这条链上有两个会安静给出「成功」的坑

**一、XcodeGen 默认把签名锁死在 development。** 它会写 `CODE_SIGN_IDENTITY = "iPhone Developer"`，自动签名于是只找 development 描述文件；而个人团队没有注册设备，Apple 直接拒绝签发，报的是「Your team has no devices from which to generate a provisioning profile」。**这个错误具有误导性**——真正的问题不是没有设备，而是它根本不该去要 development 描述文件。已在 `project.yml` 的 Release 配置里覆盖掉。

**二、`CODE_SIGN_IDENTITY=""` 会产出一个没签名的归档，而 archive 照报 `ARCHIVE SUCCEEDED`。** 产物里没有 `embedded.mobileprovision`、没有任何 entitlements——意味着 **Sign in with Apple 直接失效**，而整个登录与账户删除链条都建立在它上面。不打开产物看是发现不了的，`xcodebuild` 全程不会提醒。

`scripts/ios-release.mjs` 归档后会强制校验产物：Apple Distribution 签名、Team ID、`com.apple.developer.applesignin` entitlement、构建号一致，缺一项就中断。**不要为了图快跳过这一步。**

### 发布运营台与法务页面

⚠️ **当前流程有隐患**：`scripts` 里没有封装，实际操作是「清空 pages 仓库 → 拷入新产物 → 提交推送」。**如果构建失败而清空已执行，会留下空仓库**（真实发生过一次，已用 `git reset --hard` 还原）。

建议改成「构建成功后再替换」。在改之前，务必先确认 `npm run build:github-pages` 成功再动 pages 仓库。

---

## 十、协作与记录规则

**完成一个有意义的迭代后，必须在 [`docs/iteration-log.md`](iteration-log.md) 追加一条**：处境 → 决策与理由 → 结果 → 未验证项。判定标准是改变了产品形态、技术选型、平台策略或对外承诺。

这与 `PROJECT_LOG.md` 分工不同：后者是只追加的验收证据，前者是决策与权衡的叙述。两者都要写。完整规则见 `AGENTS.md`。

---

## 十一、两条经验教训

**测试跑的是构建产物，不是源码。** 见第四节。

**权限被拒不等于东西不存在。** macOS 对 iCloud Drive 等目录有 TCC 保护，`ls` 只回一句 `Operation not permitted`。曾据此误判「文件下载失败」，实际文件一直都在。碰到这类目录先验证读权限再下结论。
