# iPhone 物理设备安装与 MVP 验收清单

状态：`PLANNED / 等待 P0 业务闭环与物理 iPhone 接入`
用途：把产品负责人必须参与的 Apple 签名步骤，和 Codex 可自动执行的构建/验收步骤分开记录。

## 开始条件

- `docs/ios-mvp-acceptance.md` 的 P0-A 至 P0-D 已在 Simulator 验收。
- 当前代码已由 Codex 合入主分支，工作区干净，Debug 构建可复现。
- 已有一部可用 iPhone、数据线或已启用无线调试；测试使用非真实隐私信息。
- App 当前 bundle ID 为 `com.hanselzzh.haluowode`，最低系统目标为 iOS 16。若该 ID 已被其他开发者占用，再由产品负责人决定一个新的、本人可注册的 ID；不要在测试现场猜测或反复改 ID。

## 产品负责人一次性操作

1. 用数据线连接 iPhone，在手机上选择“信任此电脑”；必要时保持解锁。
2. 在 Xcode 打开 `ios/Haluowode.xcodeproj`，选中 **Haluowode** target 的 Signing & Capabilities。
3. 选择产品负责人的 Apple Account 对应 **Personal Team**，保持 Automatically manage signing；若 Xcode 要求登录、许可、信任或新建开发证书，由产品负责人亲自完成。
4. 在 Scheme 设备选择器中选择真实 iPhone，而不是 iPhone Simulator；点击 Run 安装一次。
5. 如手机首次阻止开发者 App，按 iOS 的系统提示在设置中信任该开发者；不要关闭系统安全机制或使用未知签名工具绕过提示。

这些动作会影响 Apple 账号、设备信任或签名，只由产品负责人确认和操作。Codex 不需要、也不会记录 Apple 密码、证书私钥、UDID 或任何验证信息。

## Codex 验收步骤

在产品负责人完成上述步骤后，Codex 依次：

1. 读取 `devicectl` 确认设备已连接，记录**型号、iOS 版本、构建号和安装方式**（不记录 UDID）。
2. 对真实设备执行 Debug build/install；从主屏 App 图标冷启动，确认不依赖电脑本地服务器。
3. 在 Wi-Fi 下验证 P0-A 至 P0-D；再在关闭 Wi-Fi 的移动网络条件下至少复验公开读取与进度查询。
4. 使用“测试”命名、非真实联系方式和专用测试文件，执行一次受控真实发布→运营审核/派单→响应/追踪→交付查看闭环。
5. 记录测试单号、结果、失败路径、已知不阻塞问题到 `PROJECT_LOG.md`；不记录联系方式、交付能力 URL 或任何令牌。

## 真机通过条件

- 从主屏冷启动，五栏导航与安全区正常，键盘不遮挡提交。
- 生产兼容 Worker 请求成功；断网、字段错误、限流和链接失效均有明确且不泄密的提示。
- 发布、响应、追踪、媒体交付均为真实 API 行为，未调用 Mock 或假延时成功路径。
- Dynamic Type 的较大字号下核心文字不重叠；所有关键图标/按钮至少约 44 × 44 pt。
- 日志中已存在可复现的构建、设备和测试单证据。

## 失败分流

| 现象 | 先做什么 | 不做什么 |
| --- | --- | --- |
| Xcode 看不到设备 | 解锁、信任、重插线或检查无线调试 | 不删除证书、不重置设备 |
| Signing failed | 由产品负责人确认 Team、bundle ID 和 Xcode 提示 | 不粘贴账号凭据给 AI |
| 安装后立即闪退 | 导出设备日志、复现并创建代码修复任务 | 不把 Simulator 成功当作真机通过 |
| API 请求失败 | 记录 HTTP 类别和安全错误文案，检查网络/Worker 健康 | 不把管理密钥加入 App |
| 交付不可打开 | 记录安全失败状态，检查运营步骤和能力链接生命周期 | 不打印或公开链接 token |
