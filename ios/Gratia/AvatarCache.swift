import SwiftUI

/// 头像图片的磁盘缓存。
///
/// 为什么不用 `AsyncImage`：它每次都从网络开始，即便命中 URLCache 也要先经过
/// 一次异步查找，冷启动那一瞬间必然先渲染 placeholder。而且它内部使用自己的
/// URLSession，在 `App.init` 里替换 `URLCache.shared` 未必管得到它——头像因此
/// 每次冷启动都重新下载一遍。
///
/// 这里改成：**先同步读磁盘，读到就直接画出来**，一帧都不闪；同时后台请求一次
/// 网络，内容变了再更新。用户看到的永远是上次那张，而不是一个灰色人像。
enum AvatarCache {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("avatars", isDirectory: true)
        // 每次都确保目录在：`clear()` 会把整个目录删掉（退出登录时），
        // 如果这里是只求值一次的 static let，退出后再登录就永远写不进缓存了，
        // 而且不会有任何报错——头像会安静地退回「每次都重新下载」。
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 用地址的哈希做文件名：头像地址里带随机 key，本身就不可枚举，
    /// 但直接拿它当文件名会有非法字符。
    private static func file(for url: URL) -> URL {
        directory.appendingPathComponent(String(url.absoluteString.hashValue, radix: 16, uppercase: false))
    }

    static func image(for url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: file(for: url)) else { return nil }
        return UIImage(data: data)
    }

    static func store(_ data: Data, for url: URL) {
        try? data.write(to: file(for: url), options: .atomic)
    }

    /// 退出登录时清掉，避免下一个账号短暂看到上一个人的头像。
    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// 带磁盘缓存的头像。缓存命中时**同步**给出图片，不经过任何 placeholder 状态。
struct CachedAvatar: View {
    let url: URL?
    var size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                // 按尺寸缩放，而不是写死一个字号：这个组件从 28pt 的私聊小头像
                // 一直用到 96pt 的资料编辑大头像，固定 title3 在大圆里会缩成
                // 中间一个小点。下限 16pt 保证小尺寸上不会反而看不清。
                Image(systemName: "person")
                    .font(.system(size: max(size * 0.4, 16), weight: .medium))
                    .foregroundStyle(DesignSystem.Rose.deep)
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(DesignSystem.Rose.soft))
        .clipShape(Circle())
        // 同步取缓存：放在 body 求值时机之前，冷启动第一帧就有图。
        .task(id: url) { await load() }
        .onAppear {
            if image == nil, let url { image = AvatarCache.image(for: url) }
        }
    }

    private func load() async {
        guard let url else { image = nil; return }
        if image == nil { image = AvatarCache.image(for: url) }   // 先给出旧图
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let fresh = UIImage(data: data) else { return }
        AvatarCache.store(data, for: url)
        image = fresh
    }
}
