import Foundation
import GratiaCore

/// 本机缓存的个人资料。
///
/// 为什么需要它：`profile` 原本只是 `@State`，冷启动恒为 nil，于是每次打开
/// 「我的」都会先渲染一次默认值——「哈喽卧得用户」加一个灰色人像——等网络
/// 回来才替换成真实昵称与头像。用户每次进来都要看自己的名字闪一下变回默认，
/// 这不是加载慢的问题，是**先显示了错的东西**。
///
/// 有缓存之后：冷启动直接渲染上次的昵称与头像地址，网络回来再静默更新。
/// 只有真正的新用户才会看到默认值，而那时它是对的。
///
/// 存 UserDefaults 而不是钥匙串：昵称和头像地址本来就是要公开展示的内容，
/// 不是凭据。退出登录时必须清掉，否则换账号会看到上一个人的名字。
enum ProfileCache {
    private static let key = "cached.profile.v1"

    static func load() -> UserProfileDTO? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfileDTO.self, from: data)
    }

    static func save(_ profile: UserProfileDTO?) {
        guard let profile, let data = try? JSONEncoder().encode(profile) else {
            clear()
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
