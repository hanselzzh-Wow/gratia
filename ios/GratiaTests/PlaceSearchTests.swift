import XCTest
@testable import Gratia

/// `PlaceSearchModel.Suggestion.city` 是唯一把 MapKit 的「名称 + 地区」拆成
/// 服务端要的 city 的地方。拆错的代价不是显示难看，而是**提交被拒且用户
/// 无从修复**——city 在界面上没有输入框，只能靠这里拆对。
///
/// 因此每个用例都额外断言结果落在服务端的 2–24 字窗口内
/// （见 `PublishWishViewModel.validate()`）。
final class PlaceSearchSuggestionCityTests: XCTestCase {

    private func city(_ title: String, _ subtitle: String) -> String {
        PlaceSearchModel.Suggestion(title: title, subtitle: subtitle).city
    }

    private func assertSubmittable(_ value: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(value.count, 2, "city 短于 2 字会被服务端拒绝", file: file, line: line)
        XCTAssertLessThanOrEqual(value.count, 24, "city 长于 24 字会被服务端拒绝", file: file, line: line)
    }

    // MARK: 中文地址（由大到小，且通常不带分隔符）

    func testChineseProvinceCityDistrict() {
        XCTAssertEqual(city("西湖断桥", "中国浙江省杭州市西湖区"), "杭州市")
    }

    func testChineseMunicipalityHasNoProvince() {
        XCTAssertEqual(city("天安门", "中国北京市东城区"), "北京市")
    }

    func testChineseAutonomousRegion() {
        XCTAssertEqual(city("青秀山", "中国广西壮族自治区南宁市青秀区"), "南宁市")
    }

    func testChineseAutonomousPrefecture() {
        XCTAssertEqual(city("玉龙雪山", "中国云南省丽江市玉龙纳西族自治县"), "丽江市")
    }

    func testChineseSeparatedBySpacesOrCommas() {
        XCTAssertEqual(city("外滩", "浙江省, 杭州市"), "杭州市")
    }

    /// 切完省级前缀就没有剩余的地级词，退回可用的部分而不是留空。
    func testChineseSpecialAdministrativeRegion() {
        let result = city("维多利亚港", "中国香港特别行政区")
        assertSubmittable(result)
        XCTAssertTrue(result.contains("香港"), "应保留「香港」，实际是「\(result)」")
    }

    // MARK: 拉丁字母地址（由小到大）

    func testLatinCityCountry() {
        XCTAssertEqual(city("Eiffel Tower", "Paris, France"), "Paris")
    }

    func testLatinCityStateCountry() {
        XCTAssertEqual(city("Shoreline Amphitheatre", "Mountain View, CA, United States"), "Mountain View")
    }

    func testLatinLeadingPostcodeIsStripped() {
        XCTAssertEqual(city("Musée d'Orsay", "75007 Paris, France"), "Paris")
    }

    // MARK: 退化输入

    /// 补全结果可以没有 subtitle。留空会让提交卡住，故退回地点名。
    func testEmptySubtitleFallsBackToTitle() {
        XCTAssertEqual(city("西湖断桥", ""), "西湖断桥")
    }

    /// 服务端 city 上限 24 字，超长的地区串必须截断而不是原样带过去。
    func testOverlongResultIsClampedToServerLimit() {
        let long = String(repeating: "长", count: 60)
        let result = city("某处", long)
        assertSubmittable(result)
        XCTAssertEqual(result.count, 24)
    }

    func testEveryCaseStaysWithinServerLimits() {
        let cases: [(String, String)] = [
            ("西湖断桥", "中国浙江省杭州市西湖区"),
            ("天安门", "中国北京市东城区"),
            ("青秀山", "中国广西壮族自治区南宁市青秀区"),
            ("Eiffel Tower", "Paris, France"),
            ("Mountain View", "Mountain View, CA, United States"),
            ("Musée d'Orsay", "75007 Paris, France"),
            ("老家巷口的那棵树", ""),
        ]
        for (title, subtitle) in cases {
            assertSubmittable(city(title, subtitle))
        }
    }
}
