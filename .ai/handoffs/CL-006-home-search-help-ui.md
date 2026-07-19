# CL-006 交接：用户认可风格的 SwiftUI 首页与导航落地

- 负责人：Claude（角色例外授权，见任务卡）
- 工作区：`worktrees/claude-cl-006-home-search-help-ui`｜分支：`codex/cl-006-home-search-help-ui`
- 代码 commit：`8021bff`（本交接文件与截图在其后的 docs commit）
- 状态：已完成允许范围内实现与验证，等待 Codex 独立验收。**未合入 main，未推送，未改签名。**

## 1. 交付概览

顶层结构改为四页 + 中央全局发布动作：`首页｜搜索｜发布(中央)｜帮助｜我的`。一级“进度”移除，进度查询收进“我的”。全部页面采用产品负责人认可的玫红方向：大面积纯白，主题色 `#9A536D`、深色 `#7F4058`、柔粉 `#E4C6D0`、浅粉底 `#FAF4F6`、主文字 `#191719`。

## 2. 精确改动路径（均在任务卡允许范围内）

| 文件 | 改动 |
| --- | --- |
| `ios/Haluowode/ContentView.swift` | 重写：`AppTab`（4 页）、`DockLayout`（固定视觉顺序）、自定义 `DockBar`、键盘出现时隐藏 Dock、中央发布以 `fullScreenCover` 打开真实 `PublishView` |
| `ios/Haluowode/DesignSystem.swift` | 新增玫红 token（`rose/roseDeep/roseSoft/roseCanvas/roseHairline/inkPrimary/inkMuted`）、`RosePrimary/RoseSecondaryButtonStyle`、`whiteCanvas()`/`roseCard()`、原创两手相握图标 `HandsClaspedIcon/Glyph`。**v3 `accent` 及旧样式原值保留**，AG-007 页面视觉不受影响 |
| `ios/Haluowode/HomeView.swift` | 重写：白底媒体优先信息流；运行态无公开故事源时渲染诚实空态；“许个愿”为右上角克制次入口；互动仅图标、无数字；`StoryCard` 带可见“虚构示例”徽章 |
| `ios/Haluowode/SearchView.swift`（新建） | 公开字段搜索：关键词（标题/摘要/公共地标）+ 城市/主题/形式筛选；已选条件形成可单独清除的标签；运行态诚实空态；纯逻辑 `StoryFilter` 可测试 |
| `ios/Haluowode/HomePreviewFixtures.swift`（新建） | 仅 Preview/测试使用的虚构故事 fixture（首页恰好 2 条，搜索演示 4 条）；全部标记 `isFictionalSample`，文案自带“虚构示例”声明；无真人、无商标、无联系方式、位置最多到公共地标 |
| `ios/Haluowode/NearbyView.swift` | 语义改为“帮助”（标题“需要帮助的心愿”）+ 玫红 token 重着色。**列表加载/空/错误/刷新、详情、`WishResponseViewModel` 提交/取消/失败/成功逻辑一行未动** |
| `ios/Haluowode/ProfileView.swift` | 新增“我的心愿”区：“我发布的”“我帮助的”两个入口，均导航到现有真实 `ProgressView(apiClient:)` 查询页；无本地历史聚合、无伪造账户；补 `import HaluowodeCore`；玫红重着色 |
| `ios/Haluowode/PublishView.swift` | 仅入口/导航适配：`selectedTab` Binding 改为 `onClose/onViewProgress/onGoHome` 闭包（取消=关闭 Sheet；成功后“去「我的」查询进度”/“返回首页”）；玫红 token。**表单校验、状态机、API、编号语义未动** |
| `ios/HaluowodeTests/AppNavigationAndSearchTests.swift`（新建） | 13 条：Dock 顺序/中央动作/VoiceOver 名、fixture 诚实性（恰 2 条且标记虚构、地标粒度）、`StoryFilter` 全维度筛选与标签清除 |
| `ios/HaluowodeTests/CL006PresentationTests.swift`（新建） | 8 条截图取证测试（沿用 main 上 AG-007 `ProgressPresentationTests` 的 UIHostingController 附件截图方式）；心愿列表用测试内 fixture DTO，不触生产 API |
| `ios/Haluowode.xcodeproj/project.pbxproj` | 仅由任务卡验收命令 `xcodegen generate` 重新生成（纳入新增源文件），未手工编辑 |
| `.ai/handoffs/CL-006-assets/`（新建） | 9 张截图证据，见 §5。任务卡允许列表未显式含此目录，沿用 CL-001～CL-005 的 `CL-00X-assets` 惯例存放，请 Codex 确认 |

未触碰：`ProgressView.swift`、`TrackWishViewModel.swift`、`DeliveryPreviewView.swift`、全部 ViewModel 业务语义、`ios/Packages/HaluowodeCore`、后端、`project.yml`、签名/Bundle ID、依赖、主分支、任务板、冻结文件、项目日志。

## 3. 交付项对照任务卡

1. **Dock**：视觉顺序固定 首页、搜索、中央发布、帮助、我的（`DockLayout` 常量 + 测试锁定）。页面图标黑 `#191719`/深灰 `#6D666A`，仅中央发布玫红。无汉字；每项有准确 VoiceOver 名（首页/搜索/发布心愿/帮助/我的）、`.isSelected` 选中态（填充图标+加粗+底部圆点）、`minHeight 48` ≥44pt 命中区。帮助为 `HandsClaspedIcon` 原创 Shape（两臂相握+小心形），非 SF Symbol、非定位针/爱心。
2. **中央发布**：全局动作，`fullScreenCover` 打开现有真实 `PublishView` 三步流程；API、校验、取消、错误、公开编号语义未变（仅关闭/跳转闭包替换 tab 切换）。不是第五个持久页面（`AppTab.allCases.count == 4` 有测试）。
3. **首页**：白底媒体信息流，删除全部大段 App 介绍/步骤/城市选择；“许个愿”为右上角描边小胶囊次入口。正常样式仅 Preview/截图测试展示 2 条明示虚构故事；运行 App 无公开故事源，渲染诚实空态（截图 01/09）。互动行仅心形/气泡图标，无任何数字，VoiceOver 读“互动功能即将开放”。
4. **搜索**：关键词 + 城市/主题/形式筛选，结果沿用 `StoryCard` 媒体视觉；已选条件为可单独清除标签 + 全部清除。只搜索 fixture 的公开字段；位置粒度城市/公共地标（有测试断言）；运行态诚实说明暂无公开内容（截图 04）。
5. **帮助**：复用真实 `PublicWishDTO` 列表与响应流程，仅语义与配色调整；行为逻辑零改动，现有 4 个 ViewModel 测试套件全绿未改。
6. **我的**：“我发布的”“我帮助的”两入口 → 内部导航到现有真实进度查询；文案明确说明需公开编号+联系方式，不聚合本地历史。
7. **Dock 工程质量**：`safeAreaInset(edge: .bottom)` 保持安全区与内容不遮挡；键盘出现时 Dock 隐藏（对齐系统行为）；纯白不透明表面，Reduce Transparency 天然诚实；图标尺寸用 `@ScaledMetric` 随 Dynamic Type 缩放；无固定截图式布局；deploymentTarget 16.0 编译通过。
8. **证据**：见 §4/§5，全部为真实执行结果。

## 4. 实际验证结果（本 worktree 真实执行）

```
xcodegen generate --spec ios/project.yml                          → 成功
swift test（HaluowodeCore, swift-testing）                         → 17/17 通过，1 suite，0 failure
xcodebuild test（iPhone 17 Pro, id 742A9D34…, iOS 27 Simulator）    → 44/44 通过，0 failure/skip
  = 既有 23（Publish 6 / Track 8 / WishList 3 / Response 6）
  + 新增 AppNavigationAndSearchTests 13
  + 新增 CL006PresentationTests 8（截图取证）
swiftc -frontend -parse ios/Haluowode/*.swift                     → 通过
rg -i 'admin|x-admin-key|api[_-]?key|cloudflare.*token|Wish\.mockWishes|LinearGradient'
                                                                  → 0 命中
git diff --check                                                  → 干净
simctl install + launch（真实运行）                                → 启动成功，首页诚实空态+完整 Dock（截图 09）
```

Warning 情况：本任务源码 0 编译 warning。构建日志仅存在两类**预存工具链 warning**（非本改动引入）：XCTest dylib 面向 iOS 17 链接到 16.0 目标的 ld warning；`appintentsmetadataprocessor` 无 AppIntents 依赖提示。

## 5. 截图索引（`.ai/handoffs/CL-006-assets/`，393×852 @1x）

| 文件 | 内容 |
| --- | --- |
| `CL-006-01-home-runtime-empty.png` | 首页运行态诚实空态 |
| `CL-006-02-home-fixture-feed.png` | 首页 fixture 信息流（2 条，含“虚构示例”徽章） |
| `CL-006-03-search-fixture-feed.png` | 搜索 fixture 结果流与筛选菜单 |
| `CL-006-04-search-runtime-empty.png` | 搜索运行态诚实空态 |
| `CL-006-05-help-list.png` | 帮助页真实列表流（测试 fixture DTO 数据） |
| `CL-006-06-profile-entries.png` | 我的：我发布的/我帮助的入口 |
| `CL-006-07-dock.png` | Dock 特写（选中态、中央玫红、帮助图标） |
| `CL-006-08-publish-entry-step1.png` | 中央发布打开的真实发布流程第 1 步 |
| `CL-006-09-live-launch-home.png` | 真实 simctl 安装启动后的运行态截图（1206×2622） |

01–08 由 `CL006PresentationTests` 在 iPhone 17 Pro Simulator 内渲染并作为 XCTAttachment 导出（与已验收的 AG-007 取证方式一致）；09 为真实安装启动截屏。

## 6. 素材来源与授权边界

- 所有图标：SF Symbols（系统授权内使用）+ 自绘 `HandsClaspedIcon` 原创贝塞尔路径，无第三方素材。
- 未新增任何位图/照片资产；媒体位为纯 Shape 组合占位（`Assets.xcassets/PreviewMedia` 因此未创建）。
- fixture 文案全部原创虚构（“阿蓝”“小茉”“老周”“小禾”均为虚构称呼），无可识别真人、商标、联系方式、订单或交付链接；位置仅公共地标。
- 无 PIN、密钥、生产凭据进入代码、测试或截图；未访问生产 API（列表页测试用本地 fixture API）。

## 7. 未验证项（如实声明）

- 真机安装与运行（仍受签名/设备信任阻塞，同 main 现状）。
- iOS 16–26 各版本运行时行为：仅保证 deploymentTarget 16.0 编译通过与 iOS 27 Simulator 运行；旧系统未实测。
- 横屏、极端 Dynamic Type（AX5）、VoiceOver 实机走查、Reduce Transparency 实测：按规范实现但未逐项人工验证。
- 键盘隐藏 Dock 的动画表现仅在逻辑层验证，未在真实键盘弹出场景截图。
- 发布全流程真实提交未在本任务重跑（业务代码未动，既有 6 条 Publish 测试全绿）。

## 8. 需 Codex 裁决的事项

1. **遗留缺陷上报（未修）**：`PublishView.swift` 进度指示文案 `"第 (currentStep) 步，共 3 步"` 缺少 `\` 插值，运行时字面显示 `(currentStep)`（见截图 08，主分支同样存在）。属显示缺陷但不在本卡“入口/token/导航”授权内，未擅自修改；建议验收时授权一并修复（单字符改动）。
2. 截图目录 `.ai/handoffs/CL-006-assets/` 沿用 CL 系列惯例，任务卡允许列表未显式列出，请确认。
3. `PublishView` 成功页主按钮文案由“查看心愿进度”改为“去「我的」查询进度”以匹配新信息架构（进度已无一级入口），属导航适配，如认为超范围可退回。

## 9. 回滚与停止状态

- 全部改动隔离在本 worktree 分支 `codex/cl-006-home-search-help-ui`（代码 `8021bff` + 本交接 docs commit），revert 两个 commit 即完全回滚。
- Claude 已停止：不合入、不推送、不部署、不领取下一任务，等待 Codex 独立验收。

## 10. 复工会话补充（2026-07-19，commit `651886b`）

环境修复后的复工会话对上述交付做了独立复验与证据补强：

- **独立复验（真实执行，与 §4 交叉印证）**：`swiftc -parse` 通过；`xcodegen generate` 结果与已提交 pbxproj 一致；Core `swift test` 17/17；`xcodebuild test`（iPhone 17 Pro，742A9D34…）两次运行均 44/44、0 failure；`rg` 隐私/禁项扫描 0 命中；`git diff --check` 干净；构建源码 0 warning（仅预存 `appintentsmetadataprocessor` 工具链提示）。
- **新增真实运行态逐页截图**（`01-home-empty.png`～`05-publish-entry.png`）：每张均为 `simctl install + launch` 后的实机截屏，补强 §5 中 01–08 为测试渲染的证据链；其中 `05-publish-entry.png` 实证了 §8.1 上报的 `(currentStep)` 遗留显示缺陷。
- **`#if DEBUG` 截图钩子**：本机为 headless Simulator runtime（无 Simulator.app、无触摸注入工具），为产出上述真实运行截图，在 `ContentView.init` 增加仅 DEBUG 构建存在的启动参数钩子（`-cl006-initial-tab`／`-cl006-show-publish`），只选择初始页面/发布层，不注入任何数据、不伪造任何状态，Release 构建不包含。若 Codex 认为其超出授权，单独 revert `651886b` 即可，不影响主交付 `8021bff`。
- **过程更正记录**：复工会话曾于群聊 `CHAT-20260719-114500-CLAUDE-020` 将当时未提交的 worktree 改动如实审计为“未验证草稿”；随后确认原会话在并行上下文中完成了提交（`8021bff`/`9b02627`）与 STATUS。两会话产出已在本节收敛，无冲突改动。
