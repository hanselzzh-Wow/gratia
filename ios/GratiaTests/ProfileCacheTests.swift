import XCTest
import GratiaCore
@testable import Gratia

/// 冷启动先闪一次「哈喽卧得用户」再变成真实昵称，是因为资料只存在内存里。
/// 缓存是用来消除那一闪的，所以这里要钉死的是：**存进去的能原样取回来**，
/// 以及**退出登录必须清干净**（否则换账号会看到上一个人的名字）。
final class ProfileCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ProfileCache.clear()
    }

    override func tearDown() {
        ProfileCache.clear()
        super.tearDown()
    }

    func testRoundTripsAllFields() {
        let profile = UserProfileDTO(
            displayName: "晚风电台",
            avatarUrl: "https://api.hanselzhang.com/api/avatars/avatars%2Fabc",
            pendingReview: true,
            reviewNote: "含违规词"
        )
        ProfileCache.save(profile)

        let restored = ProfileCache.load()
        XCTAssertEqual(restored, profile, "取回来的资料必须和存进去的一模一样")
    }

    func testEmptyWhenNothingSaved() {
        XCTAssertNil(ProfileCache.load(), "没存过时应返回 nil，让界面回落到默认值")
    }

    func testHandlesNilOptionalFields() {
        let profile = UserProfileDTO(
            displayName: "哈喽卧得用户", avatarUrl: nil, pendingReview: false, reviewNote: nil
        )
        ProfileCache.save(profile)
        XCTAssertEqual(ProfileCache.load(), profile, "没有头像的资料也要能缓存")
    }

    /// 退出登录清缓存是硬要求：留着会让下一个登录的人先看到上一个人的昵称。
    func testClearRemovesEverything() {
        ProfileCache.save(UserProfileDTO(
            displayName: "晚风电台", avatarUrl: nil, pendingReview: false, reviewNote: nil
        ))
        XCTAssertNotNil(ProfileCache.load())

        ProfileCache.clear()
        XCTAssertNil(ProfileCache.load(), "退出登录后不能残留上一个账号的资料")
    }

    /// save(nil) 等同于清除——调用方拿到 nil 资料时不该留着旧的。
    func testSavingNilClears() {
        ProfileCache.save(UserProfileDTO(
            displayName: "晚风电台", avatarUrl: nil, pendingReview: false, reviewNote: nil
        ))
        ProfileCache.save(nil)
        XCTAssertNil(ProfileCache.load())
    }
}

/// 头像图片的磁盘缓存。它要保证的是：冷启动时**不经网络**就能拿到上次那张图，
/// 否则每次进「我的」都会先闪一个灰色人像。
final class AvatarCacheTests: XCTestCase {
    private let url = URL(string: "https://api.hanselzhang.com/api/avatars/avatars%2Ftest")!

    override func setUp() { super.setUp(); AvatarCache.clear() }
    override func tearDown() { AvatarCache.clear(); super.tearDown() }

    private func pngData() -> Data {
        // scale = 1：默认会跟随设备（模拟器 @3x），8pt 会生成 24px，
        // 而从 PNG 还原的 UIImage 没有 scale 信息，尺寸对不上。
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }.pngData()!
    }

    func testStoredImageIsReadableWithoutNetwork() {
        XCTAssertNil(AvatarCache.image(for: url), "没缓存过时应为空")
        AvatarCache.store(pngData(), for: url)
        let image = AvatarCache.image(for: url)
        XCTAssertNotNil(image, "存过之后必须能同步读出来，这正是不闪的前提")
        XCTAssertEqual(image?.size, CGSize(width: 8, height: 8))
    }

    func testDifferentUrlsDoNotCollide() {
        let other = URL(string: "https://api.hanselzhang.com/api/avatars/avatars%2Fother")!
        AvatarCache.store(pngData(), for: url)
        XCTAssertNotNil(AvatarCache.image(for: url))
        XCTAssertNil(AvatarCache.image(for: other), "不同地址不能串图")
    }

    /// 退出登录要清干净，否则下一个账号会先看到上一个人的头像。
    func testClearRemovesStoredImages() {
        AvatarCache.store(pngData(), for: url)
        XCTAssertNotNil(AvatarCache.image(for: url))
        AvatarCache.clear()
        XCTAssertNil(AvatarCache.image(for: url))
    }
}
