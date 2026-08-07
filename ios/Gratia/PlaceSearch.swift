import Foundation
import MapKit
import SwiftUI

/// 地点自动补全。用 MapKit 自带的 `MKLocalSearchCompleter`：
/// 不需要 API Key、不产生费用、全球覆盖，且**不需要定位权限**——
/// 它只做文本检索，不读取设备位置，与我们「不申请定位」的声明一致。
@MainActor
final class PlaceSearchModel: NSObject, ObservableObject {
    struct Suggestion: Identifiable, Equatable {
        /// 地点名，如「西湖断桥」「Eiffel Tower」
        let title: String
        /// 所在地区，如「中国浙江省杭州市西湖区」「Paris, France」
        let subtitle: String
        var id: String { "\(title)|\(subtitle)" }

        /// 服务端要求 city 与 landmark 分开，而补全结果只给「名称 + 地区」，
        /// 这里做一次合理拆分。
        ///
        /// 结果**保证落在服务端的 2–24 字校验窗口内**（见
        /// `PublishWishViewModel.validate()`）：拆不出合用的城市时退回地点名，
        /// 而不是留空或返回超长串——那两种情况用户在界面上都无从修复，
        /// 因为 city 是隐藏字段，只有地点输入框可编辑。
        var city: String {
            let candidate = Self.extractCity(from: subtitle) ?? title
            return Self.clamped(candidate)
        }

        /// 服务端 city 上限 24 字。
        static func clamped(_ value: String) -> String {
            String(value.trimmingCharacters(in: .whitespaces).prefix(24))
        }

        private static func extractCity(from subtitle: String) -> String? {
            let trimmed = subtitle.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            if trimmed.range(of: "\\p{Han}", options: .regularExpression) != nil {
                return chineseCity(from: trimmed)
            }
            return latinCity(from: trimmed)
        }

        /// 中文地址由大到小，且常常**不带分隔符**：「中国浙江省杭州市西湖区」。
        /// 先切掉国名与省级前缀，再取到地级后缀为止。
        private static func chineseCity(from address: String) -> String? {
            var rest = address
            for prefix in ["特别行政区", "自治区", "省"] {
                if let range = rest.range(of: prefix) {
                    rest = String(rest[range.upperBound...])
                    break
                }
            }
            rest = rest.trimmingCharacters(in: separators)
            if rest.hasPrefix("中国") { rest = String(rest.dropFirst(2)) }

            // 「市」优先：它是最常见的一级，且必须取**第一个**「市」为止，
            // 否则「丽江市玉龙纳西族自治县」会被后面的「自治县」抢走。
            if let cityRange = rest.range(of: "市") {
                var segment = String(rest[..<cityRange.upperBound])
                // 「西双版纳傣族自治州景洪市」这类地级州套县级市，取后面的市。
                // 但「杭州市」的「州」是市名的一部分，剥掉就只剩一个「市」字，
                // 所以只在剥完仍有两个字以上的名字时才认。
                for marker in ["自治州", "州", "盟"] {
                    guard let range = segment.range(of: marker) else { continue }
                    let tail = String(segment[range.upperBound...])
                    if tail.count >= 3 { segment = tail }
                    break
                }
                if segment.count >= 2 { return segment }
            }

            for suffix in ["自治州", "自治县", "州", "县", "盟"] {
                if let range = rest.range(of: suffix) {
                    let city = String(rest[..<range.upperBound])
                    if city.count >= 2 { return city }
                }
            }
            // 「香港特别行政区」这类切完就没了，退回可用的部分交给上层截断。
            let fallback = rest.isEmpty ? address : rest
            return fallback.count >= 2 ? fallback : nil
        }

        private static let separators = CharacterSet(charactersIn: ",，、 ").union(.whitespaces)

        /// 拉丁字母地址由小到大：「Paris, France」「Mountain View, CA, United
        /// States」，取第一段。不试图在多段地址里认出「哪一段才是城市」——
        /// 各国格式差异太大，猜错比取第一段更糟；取第一段至少永远是一个
        /// 人能看懂的地点。只去掉前置邮编，「75007 Paris」→「Paris」。
        private static func latinCity(from address: String) -> String? {
            let parts = address
                .components(separatedBy: CharacterSet(charactersIn: ",，、"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard let candidate = parts.first else { return nil }

            let withoutPostcode = candidate
                .replacingOccurrences(
                    of: "^[0-9][0-9A-Za-z ]{0,7}\\s+",
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespaces)
            let city = withoutPostcode.count >= 2 ? withoutPostcode : candidate
            return city.count >= 2 ? city : nil
        }
    }

    @Published private(set) var suggestions: [Suggestion] = []
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        // 只要具体地点与地址，排除默认会带上的 .query（「附近的加油站」
        // 这类检索词建议）——那不是一个能送达的地方。
        completer.resultTypes = [.pointOfInterest, .address]
        completer.delegate = self
    }

    func clear() {
        query = ""
        suggestions = []
    }
}

extension PlaceSearchModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.prefix(8).map {
            Suggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in self.suggestions = Array(results) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // 补全失败不打断填写：用户仍可直接手动输入地点。
        Task { @MainActor in self.suggestions = [] }
    }
}

/// 地点输入 + 自动补全建议。允许直接手输，不强制从建议里选——
/// 有些地方（老家巷口的那棵树）本来就不在任何地图数据库里。
struct PlaceField: View {
    @Binding var city: String
    @Binding var landmark: String
    var error: String?

    @StateObject private var model = PlaceSearchModel()
    @FocusState private var focused: Bool
    @State private var picked = false
    /// 从建议中选定时会以程序方式改写输入框文本，此时不应再当作手输处理，
    /// 否则会把已拆分好的城市覆盖掉。
    @State private var applyingSuggestion = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("地点")
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.ink700)

            TextField("搜索或直接输入，例如：西湖断桥", text: $model.query)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink)
                .focused($focused)
                .padding(DesignSystem.spacing12)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                        .fill(DesignSystem.canvasSunk)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .stroke(error == nil ? DesignSystem.hairline : DesignSystem.danger, lineWidth: 1)
                        )
                )
                .onChange(of: model.query) { _, value in
                    guard !applyingSuggestion else { applyingSuggestion = false; return }
                    picked = false
                    landmark = value
                    // 手输时无法区分城市与地标，用同一文本保证可提交。
                    // 注意必须每次同步：只在 city 为空时写回会让城市停留在
                    // 用户输入的第一个字，导致校验永远不过。
                    // 截断到 24 字是必需的：landmark 上限 40 而 city 上限 24，
                    // 原样镜像会让 25–40 字的地点卡在「城市名称必须为2-24个
                    // 字符」上，而界面上并没有城市输入框可以改。
                    city = PlaceSearchModel.Suggestion.clamped(value)
                }

            if let error {
                Text(error).font(DesignSystem.captionFont).foregroundStyle(DesignSystem.danger)
            }

            if !picked, focused, !model.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(model.suggestions) { suggestion in
                        Button {
                            applyingSuggestion = true
                            model.query = suggestion.title
                            landmark = suggestion.title
                            city = suggestion.city
                            picked = true
                            focused = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(DesignSystem.bodyFont)
                                    .foregroundStyle(DesignSystem.ink900)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(DesignSystem.captionFont)
                                        .foregroundStyle(DesignSystem.ink700)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignSystem.spacing12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, DesignSystem.spacing12)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                        .fill(DesignSystem.canvas)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .stroke(DesignSystem.hairline, lineWidth: 1)
                        )
                )
                .motionTransition(.opacity.combined(with: .move(edge: .top)))
            }

            if picked, !city.isEmpty {
                Label("\(city) · \(landmark)", systemImage: "mappin.and.ellipse")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.accent)
            }
        }
        .motion(DesignSystem.Motion.content, value: model.suggestions)
        .onAppear {
            guard model.query.isEmpty, !landmark.isEmpty else { return }
            // 回到这一步时（如提交失败后返回改写）要把草稿填回输入框，但
            // 这不是手输：不加 applyingSuggestion 的话，下面的 onChange 会
            // 把已经拆好的城市覆盖成地标，「杭州」悄悄变成「西湖断桥」。
            applyingSuggestion = true
            model.query = landmark
            picked = !city.isEmpty && city != landmark
        }
    }
}
