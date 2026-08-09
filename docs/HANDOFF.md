# 哈喽卧得 / Gratia 交接文档

最后更新：2026-08-07　｜　分支：`appstore/1.0`

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
| 生产 API | **`https://api.hanselzhang.com`**（自定义域名，国内可达） |
| 旧地址 | `https://haluowode-mvp.hanselzzh.workers.dev` 仍指向同一 Worker，保留备查 |
| 数据库迁移 | `0000`–`0012` 全部已应用 |
| 运营台 | `https://hanselzzh-wow.github.io/ops/`（有待审内容会自动发邮件提醒） |
| 法务页面 | `/legal/privacy/`、`/legal/terms/` 已公开 |
| Apple 令牌撤销 | 已端到端验证通过 |
| TestFlight | 构建 10 在 Beta 审核队列中；11–16 已上传未提交（不打断 10 的审核）。公开链接 `https://testflight.apple.com/join/ftyuGZ8n`（审核通过后生效，上限 100 人） |
| 推送通知 | **已启用**（2026-08-07）。密钥 `3AA48B42H3`，Sandbox & Production；已对 Apple 真实端点验证 |
| 后端测试 | 50/50 |
| iOS 测试 | 49/49 |

### 构建号：下一个可用是 17

构建 1–16 已被 App Store Connect 占用，构建号不能复用。`ios/project.yml` 的 `CURRENT_PROJECT_VERSION` 已置为 17；`scripts/ios-release.mjs` 会在归档前先核对有没有撞号。**上传成功后要立刻加一。**

> **同一时间只能有一个构建在 Beta 审核中。** 已提交的审核**无法通过 API 撤销**（`betaAppReviewSubmissions` 只允许 CREATE/GET），要换构建送审只能先在 App Store Connect 网页上停掉当前那个，否则提交会被 422「Another build in the same train is already in beta review」挡回。

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
| 生成网站产物 | `npm run build:github-pages -- https://api.hanselzhang.com` |
| 生成法务页面 | `node scripts/build-legal-pages.mjs` |
| 查已占用的构建号 | `node scripts/asc-builds.mjs` |
| 打并上传 iOS 构建 | `node scripts/ios-release.mjs --upload`（见第九节） |
| 修签名（归档报 errSec 时） | `node scripts/ios-signing-setup.mjs` |
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
| iOS 分发证书与私钥 | `~/Developer/gratia-signing/`（仓库外，权限 700） | 打包签名，见第九节 |
| 待审提醒邮件 | Worker secret `RESEND_API_KEY` | 运营台待审提醒，见第七节 |

**关键标识**（这些不是机密）：

```
Team ID            HH9LKGK7DA
Bundle ID          com.hanselzzh.gratia
App Store App ID   6798480891
ASC Key ID         ${ASC_KEY_ID}
ASC Issuer ID      ${ASC_ISSUER_ID}
D1 数据库          haluowode-mvp-db
Worker             haluowode-mvp
API 域名           api.hanselzhang.com（Cloudflare Custom Domain）
域名注册商         DNSPod（腾讯），NS 已托管到 Cloudflare
```

> **API 域名不能改回 `*.workers.dev`。** 那是 Cloudflare 共享测试子域，在中国大陆被整体污染，国内直连时**全部** API 都连不上——不只是登录，浏览、发布、私聊一起失效。2026-08-07 迁到 `api.hanselzhang.com` 后国内实测可用。注意它只解决「连不上」，不解决「慢」：Cloudflare 免费版在国内没有节点，走国际线路。要快只能 ICP 备案 + 境内服务器（该域名**尚未备案**）。

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

### 为什么不能把「发布心愿」改成免审

App Review Guideline 1.2 要求 UGC App 具备四件事：**事前过滤不当内容**、举报机制、屏蔽滥用用户、公开联系方式；原文点名「以线下实物或服务交付告终的服务」，本 App 正属此类。

举报（`reportAbuse`）与屏蔽（`blockCounterpart`）都已实现，但代码里**没有任何关键词或自动过滤**——人工审核是「事前过滤」这一项的唯一实现，取消即缺项，正式提审很可能栽在 1.2 上。而且心愿正文会把一个陌生人引到一个具体的线下地点，内容风险比纯线上高。

要减轻运营负担，正确的做法不是取消审核，而是把它从「全人工」改成「自动过滤命中才进人工队列 + 事后抽查」——Apple 认的是有没有过滤手段，自动过滤同样算。

### 昵称：唯一、可封禁，与头像分开审核

**昵称唯一性按规范化形式判定**（`normalizeDisplayName`，`server/wishes-repository.ts`）：NFKC 归一全角，去掉**全部**空白而不只是首尾，删掉零宽字符与双向控制符。「晚风电台」「晚风 电台」「晚风<零宽>电台」「ＲＡＤＩＯ」在别人眼里是同一个名字，只比原文等于给冒名顶替留了一道门。规则在应用层、库里只存 `display_name_key`，所以改规则不必动索引。查询与写入之间的竞态由部分唯一索引兜底，撞了返回 409。

**封禁昵称**存在 `banned_display_names`，以规范化 key 为主键。运营在退回昵称时勾选才封禁——重名或格式问题被退不该永久锁死那个名字。运营台另有面板可直接增删。

**昵称与头像各走一条审核线**（`display_name_status` / `avatar_status`）。合审的问题在退回一侧：为了退回一张不合适的头像，用户改好的昵称会被一起打回，他得重填两样，其中一样本来是合格的。审核接口的 `target` 参数取 `displayName` / `avatar` / `both`，不传按整份处理。

### ⚠️ 预设头像免审：改图必须同步改哈希清单

新用户必须设头像，但不是每个人手边都有合适的照片。12 张预设图（`ios/Gratia/PresetAvatars/`）是兜底，且**免人工审核**——否则用户按引导选了头像，别人看到的依然是灰色人像，等于没做。

服务端按内容的 SHA-256 白名单（`server/preset-avatars.ts`）放行，不听客户端自称。两处容易踩：

1. **改动 `scripts/generate-preset-avatars.py` 会改变哈希**，必须同步更新那份清单（脚本会打印新的）。不同步不会报错，只是那些图安静地退回走人工审核。
2. **`PresetAvatars` 在 `ios/project.yml` 里必须是 folder reference**。普通 sources 会让 Xcode 用 pngcrush 重新编码这些 PNG，字节一变哈希就对不上，整条免审链路失效——同样不报错。改动工程配置后请重新校验构建产物：

```bash
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Gratia-*/Build/Products/Debug-iphonesimulator/Gratia.app | head -1)
for i in $(seq 1 12); do
  diff -q "$APP/PresetAvatars/preset-$i.png" ios/Gratia/PresetAvatars/preset-$i.png || echo "preset-$i 被改动了"
done
```

### 待审提醒邮件

有待审内容时会自动发邮件，不必一直盯着运营台。实现在 `server/ops-notifier.ts`，由 Cron（`*/15 * * * *`）触发。

- **定时汇总而非逐条推送**：发心愿的人不该为发信等待，且有人连发几条会淹掉邮箱。
- **只在待审集合变化时发信**：用四类待审的数量指纹去重。不去重的话每 15 分钟就会为同一批内容重复提醒一次，提醒多了等于没有提醒。队列清空时重置指纹，所以审完之后再来新的仍会提醒。
- 邮件正文只有各类数量与运营台链接，**不带出用户正文**。
- 发信失败不抛出、也不写指纹：既不让 Cron 反复重试耗光额度，也保证该批内容下次仍会被提醒。

需要两个配置，缺任一则静默跳过（不报错、不影响任何主流程）：

| 名称 | 类型 | 说明 |
| --- | --- | --- |
| `RESEND_API_KEY` | Secret | [resend.com](https://resend.com) 的 API key，免费额度 3000 封/月 |
| `OPS_NOTIFY_EMAIL` | var | 收件地址，已写进 `wrangler.jsonc` |

> ⚠️ `OPS_NOTIFY_EMAIL` 必须写在 `wrangler.jsonc` 的 `vars` 里。**只在 Cloudflare 后台加是不够的**——部署时 `vars` 会被配置文件整个替换，后台加的会被抹掉。secret 不受影响（部署输出里显示为 inherited）。

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

- **中英双语已就绪**，见下方「本地化」一节。仍缺：`DemoContent` 与 `StoryFeed` 的演示数据未译（只在 `#if DEBUG` 下显示），运营台是纯中文（内部工具，刻意不译）。
- **推送通知：代码已完整，等一把 APNs 密钥才真正生效**。服务端六个触发点、iOS 端权限申请与令牌上报、「我的 → 通知」入口都已就位，没配密钥时全链路静默跳过，不报错也不阻断任何业务流程。要让它真的发出去，见下方「启用推送」。
- **心愿场景与交付形式仍是中国语境**：「生日祝福/口播视频/手写卡片」等选项写死在客户端。
- **中国区上架另有门槛**：ICP 备案要求域名指向境内服务器，而后端在 Cloudflare；社交/UGC 类应用还涉及实名制要求。**TestFlight 不受影响**，仅正式上架含中国大陆时相关。这块需要专业合规意见，不要只依赖仓库里的记述。

---

## 八·五、推送

**已于 2026-08-07 启用并验证。** 下面是换密钥时的重做步骤。

> 验证方式（不需要真机、不打扰任何用户）：本地用 `.p8` 签一把 APNs JWT，拿一个格式合法但不存在的设备令牌（64 个 `a`）去打 Apple 真实端点。回 `BadDeviceToken` 说明**密钥有效**——Apple 认了签名，只是设备是假的；回 `InvalidProviderToken` 才是密钥、Key ID、Team ID 三者对不上；回 `TopicDisallowed` 是 Key Restriction 的 topic 填错了。这套区分法和验证 Apple 令牌撤销时用的是同一个思路。
>
> ⚠️ 本地验证要用 **HTTP/2**：APNs 不接受 HTTP/1.1，而 Node 的 `fetch` 只走 1.1，会抛一个看不出所以然的 `HTTPParserError`。用 `curl --http2`。生产环境在 Cloudflare Workers 上没有这个限制。

**APNs 认证密钥无法通过 App Store Connect API 创建，必须在网页上手动建。**

1. 到 [developer.apple.com/account/resources/authkeys/add](https://developer.apple.com/account/resources/authkeys/add) 新建 Key，勾选 **Apple Push Notifications service (APNs)**，下载 `.p8`——**只能下载一次**，丢了只能作废重建。
2. 把它和其他签名材料放一起（`~/Developer/gratia-signing/`，仓库外、700 权限），不要进仓库、不要放 `/tmp`。
3. 写两个 secret（这两条要自己跑，密钥不该经过第三方之手）：

```bash
# 配置文件不在仓库根目录，必须用 -c 指出来，否则 wrangler 报「Required Worker name missing」
npx wrangler secret put APNS_KEY_ID -c deploy/cloudflare/wrangler.jsonc
npx wrangler secret put APNS_PRIVATE_KEY -c deploy/cloudflare/wrangler.jsonc \
  < ~/Developer/gratia-signing/AuthKey_XXXXXXXXXX.p8
```

另外两项不用配：`APPLE_TEAM_ID` 早在配 Apple 令牌撤销时就已是 secret；`APPLE_BUNDLE_ID` 在 `worker/index.ts:242` 有默认值 `com.hanselzzh.gratia`。**它们都不在 `wrangler.jsonc` 的 vars 里**——那里只有 `PUBLIC_APP_ORIGIN` 和 `OPS_NOTIFY_EMAIL`。

创建密钥时的两个选项：**Environment 必须选 `Sandbox & Production`**（只选 Sandbox 的话，TestFlight 与 App Store 的包一律推不出去，且错误表现为 `BadDeviceToken`，看不出是密钥环境问题）；Key Restriction 建议 `Topic Specific` 填 `com.hanselzzh.gratia`——密钥要放进 Worker secret，限定 topic 可以把泄露的影响面收在这一个 App 内，而推送请求本来就带着 `apns-topic`，不需要额外适配。

### 验证它真的通了

装 TestFlight 构建 → 「我的 → 通知」点开启 → 系统弹框允许 → 用另一个账号给你发一条私聊消息。收不到时按这个顺序查：

| 现象 | 多半是 |
| --- | --- |
| 服务端日志 `[push] 跳过：未配置 APNs 密钥` | secret 没写成功 |
| 日志 `跳过：该用户没有已注册的设备` | 客户端没上报成功，多半是没授权，或 `aps-environment` 不在包里 |
| APNs 回 `BadDeviceToken` | 环境错配：Xcode 直接装的包是 sandbox，TestFlight/App Store 是 production，两套令牌空间互不相认 |
| APNs 回 `TooManyProviderTokenUpdates` | 鉴权 JWT 刷太勤。已按实例缓存 50 分钟，正常不该出现 |

模拟器收不到真推送，只能用真机验。

---

## 八·六、本地化

iOS 端 `ios/Gratia/en.lproj/Localizable.strings`（400 条），服务端 `server/i18n.ts`（89 条 + 一条模板规则）。**key 一律用中文原文**：SwiftUI 拿字面量当 `LocalizedStringKey` 查表、查不到就原样显示，所以中文那侧不需要任何文件，漏翻一条最多是那句仍是中文。

### ⚠️ 三类中文绝对不能翻译

| 类别 | 在哪 | 翻了会怎样 |
| --- | --- | --- |
| 地址解析关键词 | `PlaceSearch.swift` 的「省」「自治区」「市」… | 那是解析中文地址的规则，不是文案，翻译直接让地点识别失效 |
| 心愿场景的存储值 | `BusinessVocabulary.occasions` | `occasion` 原样存库。英文环境要是传 `"Birthday wishes"` 上去，库里两套写法并存，筛选与历史数据全对不上，而且进了生产库很难回收 |
| 交付形式的存储值 | `BusinessVocabulary.deliveryTypes` | 同上 |

后两类的做法是**存中文、显示时翻译**，映射在 `ios/Gratia/BusinessVocabulary.swift`。服务端同理：`server/i18n.ts` 只翻 `error` 与 `fields`，其余字段（心愿正文、城市、昵称、occasion）一律不碰，测试里对这几项都有断言。

### 三个不实际跑一遍就发现不了的坑

1. **视图辅助函数的参数类型**。`stepHeader(title: String)` 这类，`Text(String)` 根本不查表，翻译写得再全也不生效，且没有任何警告。接收文案的参数必须声明成 `LocalizedStringKey`；接收动态内容（错误消息、编号）的才保持 `String`。
2. **`GratiaCore` 是独立 SwiftPM 包**。`NSLocalizedString` 默认在包自己的 bundle 里找表，那里是空的，于是永远回落成中文。必须显式 `bundle: .main`（见 `APIError.swift`）。
3. **`project.yml` 的 `knownRegions`**。不声明的话 `en.lproj` 压根不进包，英文设备照样显示中文，构建同样不报错。

### 带插值的字符串

`Text("第 \(step) 步，共 3 步")` 生成的 key 是 `"第 %lld 步，共 3 步"`——整数是 `%lld`、字符串是 `%@`，**key 必须逐字符对上**才查得到。写错了不报错，只是不生效。

### 怎么验证

```bash
xcrun simctl launch booted com.hanselzzh.gratia -AppleLanguages "(en)"
xcrun simctl launch booted com.hanselzzh.gratia -AppleLanguages "(zh-Hans)"
```

两种语言都要逐屏看过——尤其发布页（业务词汇）与「我的」（辅助函数最多）。服务端：

```bash
curl -s -X POST -H "accept-language: en-US" -H "content-type: application/json" \
  -d '{"displayName":"x"}' https://api.hanselzhang.com/api/account/profile
```

语言判定从宽：`zh`、`zh-CN`、`zh-Hans`、`zh-TW` 都算中文，中文是默认。

---

## 九、发布流程

### 打新构建

```bash
node scripts/ios-release.mjs --upload
```

它按顺序做：核对构建号没被占用 → 重新生成工程 → 归档 → **校验归档产物** → 导出 → 验证 → 上传。不加 `--upload` 就停在验证，只产出 IPA。

上传成功后**立刻**把 `ios/project.yml` 的 `CURRENT_PROJECT_VERSION` 加一。构建号一经上传即被占用，撞号要等到上传那一刻才报错。

签名参数写在 `ios/project.yml` 的 **Release** 配置里（Manual + `Apple Distribution` + 描述文件 `Gratia App Store`），命令行不要再覆盖。

#### 签名材料在哪

**分发证书不在登录钥匙串里**（登录钥匙串只有 Apple Development），而在一个专用的临时钥匙串中，这样签名不会弹登录钥匙串的密码框。全部材料在 **`~/Developer/gratia-signing/`**（仓库外，权限 700）：

| 文件 | 是什么 |
| --- | --- |
| `.kcpw` | p12 密码，同时用作该钥匙串的密码 |
| `dist.p12` | 分发证书 + 私钥 |
| `dist.key` / `dist.pem` / `dist.cer` | 明文私钥与证书（p12 的来源） |
| `wwdr.pem` | Apple 中间证书 |
| `Gratia_AppStore.mobileprovision` | 描述文件 |

⚠️ **这是真实的分发私钥，丢了要重新申请证书**（个人账号证书数量有限）。它一度只存在于某个会话的 `/private/tmp` 临时目录里——随时会被清理——2026-08-07 才迁到这里。不要放回 `/tmp`，也不要提交进仓库。

#### ⚠️ 归档报 `errSecInternalComponent` 时

```bash
node scripts/ios-signing-setup.mjs
```

这个错误**看不出**跟钥匙串有任何关系，但它十有八九就是：那个临时钥匙串自动锁上了，codesign 拿不到私钥。找不到 "Apple Distribution" 签名身份也是同一个原因。跑一次上面的脚本重建并解锁钥匙串，再打包即可。脚本会把自动锁定放宽到 6 小时并设好 partition list（少了它，codesign 每次都要弹系统授权框）。

平时不需要跑它。

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
