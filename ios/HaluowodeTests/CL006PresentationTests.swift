import SwiftUI
import UIKit
import XCTest
import HaluowodeCore
@testable import Haluowode

/// CL-006 evidence: renders each new page and the dock at iPhone 17 Pro size
/// and attaches screenshots, mirroring the AG-007 presentation-test approach.
/// Wish-list fixtures below are test-only DTOs; no production API is touched.
final class CL006PresentationTests: XCTestCase {

    // MARK: - Fixtures

    private static let fixtureWishes: [PublicWishDTO] = [
        PublicWishDTO(
            id: "fixture-wish-001",
            publicCode: "HW260719-C006",
            city: "杭州",
            landmark: "西湖断桥",
            occasion: "生日祝福",
            message: "测试夹具：想请路过断桥的朋友录一段十秒的生日祝福。",
            deliveryType: DeliveryType(rawValue: "spoken_video"),
            deadlineText: "2026-07-31",
            rewardFen: 1800,
            status: .matching,
            createdAt: 1_753_000_000_000
        ),
        PublicWishDTO(
            id: "fixture-wish-002",
            publicCode: "HW260719-C007",
            city: "上海",
            landmark: "和平饭店门口",
            occasion: "加油鼓励",
            message: "测试夹具：希望有人在外滩替我拍一张手写卡片的照片。",
            deliveryType: DeliveryType(rawValue: "handwritten_card"),
            deadlineText: "2026-08-05",
            rewardFen: 2800,
            status: .matching,
            createdAt: 1_753_000_000_000
        ),
    ]

    private final class FixtureListAPI: WishAPIProtocol {
        let wishes: [PublicWishDTO]
        init(wishes: [PublicWishDTO]) { self.wishes = wishes }

        func listWishes(city: String?) async throws -> [PublicWishDTO] { wishes }
        func createWish(request: CreateWishRequest) async throws -> CreateWishResult {
            throw HaluowodeAPIError.notFound(message: "fixture")
        }
        func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult {
            throw HaluowodeAPIError.notFound(message: "fixture")
        }
        func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO {
            throw HaluowodeAPIError.notFound(message: "fixture")
        }
    }

    // MARK: - Screenshots

    @MainActor
    func testHomeHonestEmptyStateScreenshot() {
        attachScreenshot(of: HomeView(), named: "CL-006-01-home-runtime-empty")
    }

    @MainActor
    func testHomeFixtureFeedScreenshot() {
        attachScreenshot(
            of: HomeView(stories: HomePreviewFixtures.homeStories),
            named: "CL-006-02-home-fixture-feed"
        )
    }

    @MainActor
    func testSearchFixtureScreenshot() {
        attachScreenshot(
            of: SearchView(stories: HomePreviewFixtures.searchStories),
            named: "CL-006-03-search-fixture-feed"
        )
    }

    @MainActor
    func testSearchHonestEmptyStateScreenshot() {
        attachScreenshot(of: SearchView(), named: "CL-006-04-search-runtime-empty")
    }

    @MainActor
    func testHelpListScreenshot() async {
        let viewModel = WishListViewModel(apiClient: FixtureListAPI(wishes: Self.fixtureWishes))
        await viewModel.fetchWishes()
        XCTAssertEqual(viewModel.state, .loaded(Self.fixtureWishes))
        attachScreenshot(
            of: NearbyView().environmentObject(viewModel),
            named: "CL-006-05-help-list"
        )
    }

    @MainActor
    func testProfileScreenshot() {
        attachScreenshot(of: ProfileView(), named: "CL-006-06-profile-entries")
    }

    @MainActor
    func testDockScreenshot() {
        let dockHost = VStack(spacing: 0) {
            Spacer()
            DockBar(selectedTab: .constant(.home), onPublish: {})
        }
        .background(Color.white)
        attachScreenshot(of: dockHost, named: "CL-006-07-dock")
    }

    @MainActor
    func testPublishEntryScreenshot() {
        let viewModel = PublishWishViewModel(apiClient: FixtureListAPI(wishes: []))
        attachScreenshot(
            of: PublishView(viewModel: viewModel),
            named: "CL-006-08-publish-entry-step1"
        )
    }

    // MARK: - Helper (same technique as ProgressPresentationTests on main)

    @MainActor
    private func attachScreenshot<V: View>(of view: V, named name: String) {
        let size = CGSize(width: 393, height: 852)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
