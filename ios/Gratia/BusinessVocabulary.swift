import Foundation

/// 业务词汇的「存储值 → 显示值」映射。
///
/// 这些中文串**不是文案，是数据**：心愿场景（`occasion`）原样存进数据库，
/// 交付形式在客户端映射成 `spoken_video` 之类再上传。所以它们绝不能被
/// 直接本地化——一旦英文环境把「生日祝福」变成 "Birthday wishes" 传上去，
/// 库里就会同时存在两套写法，筛选、统计、老数据全部对不上，
/// 而且这种错误一旦写进生产数据就很难回收。
///
/// 正确的做法是这里做的：**存储值永远是中文，只在显示的那一刻翻译**。
/// 服务端返回的 `occasion` 同样是中文原值，展示前也要过一遍这里。
enum BusinessVocabulary {
    /// 心愿场景。顺序即发布页的展示顺序。
    static let occasions = ["生日祝福", "加油鼓励", "毕业祝福", "浪漫表白", "节日问候", "其他小心愿"]

    /// 交付形式。客户端另有一套中文 → spoken_video 的映射用于上传。
    static let deliveryTypes = ["口播视频", "景色配音", "手写卡片"]

    /// 显示用。查不到就原样返回——服务端可能有客户端还不认识的新值，
    /// 那时显示原文也好过显示一个空白。
    static func display(_ storedValue: String) -> String {
        let key = storedValue.trimmingCharacters(in: .whitespaces)
        guard let table = Self.table[key] else { return storedValue }
        return table
    }

    /// key 是存储值，value 走 Localizable.strings。
    /// 这里不用 `String(localized:)` 的默认值机制，是因为中文环境下要拿回
    /// 中文原文——而原文就是 key 本身，查不到自然回落，正合适。
    private static let table: [String: String] = {
        var result: [String: String] = [:]
        for value in occasions + deliveryTypes + extraDisplayOnly {
            result[value] = NSLocalizedString(value, comment: "业务词汇")
        }
        return result
    }()

    /// 服务端会返回、但客户端不作为选项提供的取值。
    private static let extraDisplayOnly = ["其他", "全部"]
}
