# Gratia iOS

本目录是原生 SwiftUI 消费者 App，目标为模拟器、真实 iPhone、TestFlight 和 App Store。

当前根部 Swift 文件来自早期候选界面骨架，审查结论见 `docs/ios-candidate-review.md`。它们尚未通过 Xcode 构建，且 Mock 业务必须被真实 API 纵向切片逐步替换。正式架构见 `docs/ios-architecture.md`，公开接口唯一依据见 `docs/ios-api-contract.md`。

任何实现不得把 React/GitHub Pages 页面嵌入 App，也不得内置运营 PIN、Cloudflare Token、D1/R2 凭据或管理员 Key。

完整 Xcode 可用前可执行：

```bash
swiftc -frontend -parse ios/Gratia/*.swift
```

该命令只验证语法，不代表 iOS SDK 编译、模拟器或真机验收通过。
