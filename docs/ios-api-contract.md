# iOS MVP 公开 API 契约

状态：`FROZEN v1`
冻结日期：2026-07-18（Asia/Shanghai）
生产 Base URL：`https://haluowode-mvp.hanselzzh.workers.dev`

本文件是 Swift 客户端实现的权威契约。它由 Codex 对照 `lib/wishes-contract.ts`、`lib/wishes-validation.ts`、`server/wishes-repository.ts` 和 `worker/index.ts` 核验，并吸收了 `AG-002` 的有效部分。若本文件与候选 Swift Mock、设计稿示例数据或交接报告冲突，以后端源码和本文件为准。

## 通用约定

- JSON 请求使用 `Content-Type: application/json`。
- JSON 响应使用 `cache-control: no-store`。
- 时间均为 Unix 毫秒时间戳，Swift 使用 `Int64` 保存。
- 金额均为人民币分，Swift 使用 `Int` 保存；只在展示层格式化为元。
- 原生 App 通常不发送浏览器 `Origin`，因此浏览器 CORS 白名单不会阻止 iOS `URLSession`。
- 结构化错误为 `{ "error": String, "fields"?: [String: String] }`。
- 限流错误为 HTTP 429，并带 `Retry-After` 秒数。
- 客户端不得发送、保存或记录运营 PIN、管理员 Key、Cloudflare Token、D1/R2 凭据。
- App 日志不得包含联系方式、完整请求正文或交付能力 URL。

## 枚举

### `WishStatus`

`pending_review | matching | assigned | in_progress | delivered | completed | rejected | cancelled`

中文展示依次为：待审核、待匹配、已派单、进行中、待确认、已完成、未通过、已取消。

Swift 解码必须保留未知值 fallback，避免后端增加状态后整个响应解码失败。

### `DeliveryType`

`spoken_video | scenery_voiceover | handwritten_card`

中文展示依次为：口播视频、景色配音、手写卡片。交付资源的 `kind` 还允许 `link`。

### `AssignmentStatus`

`offered | accepted | arrived | delivered | declined | cancelled`

### `WishResponseStatus`

`pending | selected | declined`

## 公共响应类型

### `PublicWish`

| 字段 | Swift 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | 当前由 UUID 生成，但客户端不依赖 UUID 解码 |
| `publicCode` | `String` | 面向用户的心愿编号 |
| `city` | `String` | 城市 |
| `landmark` | `String` | 地标 |
| `occasion` | `String` | 心愿场景 |
| `message` | `String` | 心愿正文 |
| `deliveryType` | `DeliveryType` | 交付方式 |
| `deadlineText` | `String` | 用户输入的期望时间文本 |
| `rewardFen` | `Int` | 感谢金，分 |
| `status` | `WishStatus` | 状态 |
| `createdAt` | `Int64` | Unix 毫秒 |

`PublicWish` 绝不包含发布者称呼、联系方式、审核备注、响应者联系方式或内部运营字段。

### `TrackedWish`

包含全部 `PublicWish` 字段，另加：

- `updatedAt: Int64`
- `assignment: { providerName: String, status: AssignmentStatus }?`
- `deliverable: { id: String, kind: DeliveryKind, url: URL, note: String?, createdAt: Int64 }?`
- `events: [{ eventType: String, fromStatus: WishStatus?, toStatus: WishStatus?, createdAt: Int64 }]`

`deliverable.url` 是带随机能力令牌的私有访问链接。只用于当前用户查看，不持久化、不打印、不上传分析服务。

## 端点

### `GET /api/wishes`

Query：`city` 可选，执行精确城市筛选。

成功 200：`{ "wishes": [PublicWish] }`。

重要行为：后端最多返回 40 条，且**只返回 `matching` 状态**。候选报告中“还返回 assigned/in_progress/delivered/completed”的描述不正确。

可能错误：403（浏览器 Origin 不允许）、500。

### `POST /api/wishes`

请求：

| 字段 | 类型 | 校验 |
| --- | --- | --- |
| `requesterName` | `String` | 1–30 字符 |
| `contact` | `String` | 3–80 字符 |
| `city` | `String` | 2–24 字符 |
| `landmark` | `String` | 2–40 字符 |
| `occasion` | `String` | 2–24 字符 |
| `message` | `String` | 5–120 字符 |
| `deliveryType` | `DeliveryType` | 必须为已知值 |
| `deadlineText` | `String` | 2–40 字符 |
| `rewardFen` | `Int` | 0–100000 |
| `contactConsent` | `Bool` | 必须为 `true` |
| `website` | `String?` | 蜜罐字段；原生 App 应省略 |

成功：`{ "wish": PublicWish, "created": Bool }`。

- 新建：201，`created = true`。
- 60 秒内同联系方式、同正文重复提交：200，`created = false`，返回已有心愿。

可能错误：400 + 字段错误、415 非 JSON、429（每 IP 指纹每小时 8 次）、500。

### `POST /api/wishes/{id}/responses`

路径 `id` 使用 `PublicWish.id`，不是 `publicCode`。

请求：

- `responderName: String`，1–30 字符
- `responderContact: String`，3–80 字符
- `note: String?`，清洗后最多 160 字符
- `contactConsent: Bool`，必须为 `true`
- `website: String?`，蜜罐字段；原生 App 应省略

成功：`{ "response": WishResponse, "created": Bool }`。`WishResponse` 含 `id`、`responderName`、`responderContact`、`note?`、`status`、`createdAt`、`updatedAt`。

- 新建：201，`created = true`。
- 同心愿、同响应者联系方式重复提交：200，`created = false`。

可能错误：400、404 未找到心愿、409 心愿不再接受响应、429（每 IP 指纹每小时 20 次）、500。

### `POST /api/wishes/track`

请求：

- `publicCode: String`，8–24 字符；后端转大写
- `contact: String`，3–80 字符；必须与发布时完全匹配

成功 200：`{ "wish": TrackedWish }`。

可能错误：400 输入校验、404 `没有找到匹配的心愿，请检查编号和联系方式`、429（每 IP 指纹每 10 分钟 30 次）、500。

追踪接口不返回发布者姓名或联系方式本身。联系方式只用于服务端匹配。

### `GET /api/deliverables/{id}?token=...`

成功 200：图片/视频二进制流。响应带 `cache-control: private, no-store`、`content-disposition: inline`、`referrer-policy: no-referrer`，媒体类型来自 R2 元数据。

客户端只能使用 `TrackedWish.deliverable.url` 原样访问，不自行拼接或推导 Token。

可能错误：

- 401：缺少 token。
- 404：token 错误、记录不存在、链接失效或 R2 对象不存在。
- 429：每 IP 指纹每 10 分钟 120 次。
- 503：文件存储未配置。

## Swift 类型命名

- `PublicWishDTO`
- `TrackedWishDTO`
- `CreateWishRequest` / `CreateWishResult`
- `CreateWishResponseRequest` / `CreateWishResponseResult`
- `TrackWishRequest` / `TrackWishEnvelope`
- `WishResponseDTO`
- `WishAssignmentDTO`
- `WishDeliverableDTO`
- `WishEventDTO`
- `APIErrorPayload`

DTO 的 `id` 使用 `String`，不把后端当前 UUID 实现变成客户端协议承诺。`URL` 解码失败应归类为响应解码错误，不静默丢弃交付链接。

## 实现验收样例

网络层至少覆盖以下 fixture：

1. 公开列表成功与空数组。
2. 未知 `WishStatus` 仍可解码并展示兼容文案。
3. 发布 201 与重复 200。
4. 字段校验 400 保留 `fields`。
5. 报名 409 与重复 200。
6. 追踪 404 不泄露联系方式。
7. 429 解析 `Retry-After`。
8. 非 JSON 错误与损坏 JSON 归类明确。
9. 交付 URL 不出现在错误描述和 debug 日志。
