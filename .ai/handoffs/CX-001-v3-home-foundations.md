# CX-001 · v3 首页基础视觉与 App Icon 交接

- 负责人：`CODEX-PM`
- 分支：`codex/v3-home-foundations`
- 范围：仅 `DesignSystem.swift`、`HomeView.swift`、`AppIcon.appiconset/**` 与本交接/群聊。

## 已完成

1. `DesignSystem` 已按 `docs/ios-design-freeze-v3.md` 接入暖蓝 `#3E6B92`、暖黑/暖灰、暖白 canvas、sunk canvas、两级 hairline、danger/success、8 级间距和 5 级圆角；全局按钮改为 Dynamic Type、44pt 最小高度与 v3 token。兼容名称映射到新 token，旧金色视觉不再出现。
2. 首页已去除 `LinearGradient` 与全部 `.shadow`，改为暖白背景、白色卡片、1pt hairline、原生 Dynamic Type 与 Regular SF Symbols。真实公开列表、加载/空/错/重试/刷新逻辑保持原样；没有伪造心愿数据。
3. 已按冻结要求将真实加载/已加载横卡固定为 140pt、12pt 间距并保留第三张 trailing peek。顶栏城市/通知具有 44pt 点击区；错误含图标和 danger 文本，不依赖颜色单独表达。
4. 从冻结原创源 `.ai/handoffs/CL-003-assets/icon/icon-a-warm-1024.png` 机械导出并接入 iPhone、iPad 与 marketing 全部 App Icon 槽位；未使用网络素材、Emoji、渐变或第三方标记。

## 实际验证

- XcodeGen：`/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml` 成功。
- Core：`swift test ... --enable-swift-testing` 实际 15/15 通过。
- Simulator：iPhone 17 Pro（iOS 27.0）`HaluowodeTests` 结构化结果包 `/private/tmp/haluowode-cx001-final-20260718.xcresult`：15/15、0 failure、0 skip、0 runtime warning。
- 编译与冷启动：Xcode Simulator Debug build 成功，已安装并启动 `com.hanselzzh.haluowode`；实际截图为 `/private/tmp/haluowode-cx001-v3-home.png`。
- 静态：Swift parser、App Icon JSON、首页零 `LinearGradient`/`.shadow` 扫描和 `git diff --check` 通过。
- 构建中的唯一现存 warning 是测试 target 的既有 deployment-target/XCTest linker warning（iOS Simulator 16.0 target 链接新版 XCTest runtime）；本分支在补全 iPad icon 后不再出现 asset catalog App Icon 缺尺寸 warning。

## 未验证 / 后续

- 生产公开列表当前为空，因此截图展示真实 loading skeleton，已加载的 140pt peek 由代码与静态审查确认；未为截图创建生产或本地假心愿。
- 尚未在最大 Dynamic Type、VoiceOver 或真机上进行手工复核。
- 仅首页完成 v3 实施；Nearby、Publish、Progress、Profile 与底部 Tab Bar 仍保持旧候选视觉，必须在独立后续任务中改造。
- 当前只在隔离分支，需 Codex 合并前复查后才进入 main。
