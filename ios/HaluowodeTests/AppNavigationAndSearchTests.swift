import XCTest
@testable import Haluowode

/// CL-006: dock structure, preview fixtures and search filter logic.
/// Pure navigation/presentation checks only; no business assertions touched.
final class AppNavigationAndSearchTests: XCTestCase {

    // MARK: - Dock structure

    func testDockVisualOrderIsFixed() {
        XCTAssertEqual(DockLayout.leadingTabs, [.home, .search], "Dock 左侧必须是 首页、搜索")
        XCTAssertEqual(DockLayout.trailingTabs, [.help, .profile], "Dock 右侧必须是 帮助、我的")
    }

    func testPublishIsACentreActionNotAFifthPage() {
        XCTAssertEqual(AppTab.allCases.count, 4, "只允许四个持久页面；发布是中央动作")
        XCTAssertEqual(DockLayout.publishAccessibilityName, "发布心愿")
    }

    func testEveryTabKeepsAVoiceOverName() {
        XCTAssertEqual(AppTab.home.accessibilityName, "首页")
        XCTAssertEqual(AppTab.search.accessibilityName, "搜索")
        XCTAssertEqual(AppTab.help.accessibilityName, "帮助")
        XCTAssertEqual(AppTab.profile.accessibilityName, "我的")
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.accessibilityName.isEmpty)
        }
    }

    // MARK: - Preview fixtures stay honest

    func testHomeFixturesAreExactlyTwoFictionalStories() {
        XCTAssertEqual(HomePreviewFixtures.homeStories.count, 2, "任务卡要求首页 Preview 恰好两条虚构故事")
        for story in HomePreviewFixtures.homeStories {
            XCTAssertTrue(story.isFictionalSample, "首页 fixture 必须标记为虚构示例")
            XCTAssertTrue(story.excerpt.contains("虚构示例"), "文案本身必须可见地声明虚构")
        }
    }

    func testSearchFixturesAreAllFictionalAndCityGranularity() {
        XCTAssertFalse(HomePreviewFixtures.searchStories.isEmpty)
        for story in HomePreviewFixtures.searchStories {
            XCTAssertTrue(story.isFictionalSample)
            XCTAssertFalse(story.city.isEmpty)
            XCTAssertFalse(story.landmark.isEmpty)
            // 公开位置最多到城市/公共地标；不允许出现门牌等精确个人位置样式。
            XCTAssertFalse(story.landmark.contains("号楼"))
            XCTAssertFalse(story.landmark.contains("单元"))
            XCTAssertFalse(story.landmark.contains("室"))
        }
    }

    // MARK: - StoryFilter pure logic

    private var stories: [StoryFixture] { HomePreviewFixtures.searchStories }

    func testEmptyFilterKeepsEverything() {
        let filter = StoryFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.apply(to: stories).count, stories.count)
        XCTAssertTrue(filter.activeTags.isEmpty)
    }

    func testCityFilter() {
        var filter = StoryFilter()
        filter.city = "杭州"
        let result = filter.apply(to: stories)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.city == "杭州" })
    }

    func testSceneFilter() {
        var filter = StoryFilter()
        filter.scene = "生日祝福"
        let result = filter.apply(to: stories)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.scene == "生日祝福" })
    }

    func testDeliveryFilter() {
        var filter = StoryFilter()
        filter.delivery = "口播视频"
        let result = filter.apply(to: stories)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.delivery == "口播视频" })
    }

    func testKeywordMatchesTitleExcerptAndLandmarkOnly() {
        var filter = StoryFilter()
        filter.keyword = "断桥"
        let result = filter.apply(to: stories)
        XCTAssertEqual(result.map(\.id), ["fixture-story-001"])

        filter.keyword = "  断桥  "
        XCTAssertEqual(filter.apply(to: stories).map(\.id), ["fixture-story-001"], "关键词应当去除首尾空白")
    }

    func testCombinedFiltersIntersect() {
        var filter = StoryFilter()
        filter.city = "杭州"
        filter.delivery = "口播视频"
        let result = filter.apply(to: stories)
        XCTAssertTrue(result.allSatisfy { $0.city == "杭州" && $0.delivery == "口播视频" })
        XCTAssertEqual(result.count, 2)
    }

    func testActiveTagsAreClearableIndividually() {
        var filter = StoryFilter()
        filter.keyword = "断桥"
        filter.city = "杭州"
        filter.scene = "生日祝福"
        filter.delivery = "口播视频"
        XCTAssertEqual(filter.activeTags.count, 4)

        filter.clear(.city)
        XCTAssertNil(filter.city)
        XCTAssertEqual(filter.activeTags.count, 3)

        filter.clear(.keyword)
        XCTAssertEqual(filter.keyword, "")
        XCTAssertEqual(filter.activeTags.count, 2)
    }

    func testClearAllResetsFilter() {
        var filter = StoryFilter()
        filter.keyword = "断桥"
        filter.city = "杭州"
        filter.clearAll()
        XCTAssertEqual(filter, StoryFilter())
        XCTAssertFalse(filter.isActive)
    }
}
