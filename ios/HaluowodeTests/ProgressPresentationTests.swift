import SwiftUI
import UIKit
import XCTest
import HaluowodeCore
@testable import Haluowode

final class ProgressPresentationTests: XCTestCase {
    @MainActor
    func testQueryFormScreenshot() {
        let viewModel = TrackWishViewModel(apiClient: PresentationFixtureAPI(result: .success(Self.deliveredWish)))
        attachScreenshot(of: ProgressView(viewModel: viewModel), named: "AG-007-01-query-form")
    }

    @MainActor
    func testNotFoundScreenshot() async {
        let viewModel = TrackWishViewModel(apiClient: PresentationFixtureAPI(result: .failure(HaluowodeAPIError.notFound(message: "fixture"))))
        viewModel.publicCode = "HW260719-A007"
        viewModel.contact = "fixture-contact"
        await viewModel.trackWish()

        XCTAssertEqual(viewModel.state, .failed("请检查编号和联系方式"))
        attachScreenshot(of: ProgressView(viewModel: viewModel), named: "AG-007-02-not-found")
    }

    @MainActor
    func testDeliveredScreenshot() async {
        let viewModel = TrackWishViewModel(apiClient: PresentationFixtureAPI(result: .success(Self.deliveredWish)))
        viewModel.publicCode = "HW260719-A007"
        viewModel.contact = "fixture-contact"
        await viewModel.trackWish()

        XCTAssertEqual(viewModel.contact, "")
        attachScreenshot(of: ProgressView(viewModel: viewModel), named: "AG-007-03-delivered")
    }

    @MainActor
    func testDeliveryFailureScreenshot() {
        let deliverable = WishDeliverableDTO(
            id: "fixture-deliverable",
            kind: DeliveryKind(rawValue: "unsupported_fixture"),
            url: URL(string: "https://fixture.invalid/private-capability")!,
            note: nil,
            createdAt: 1_753_000_000_000
        )

        attachScreenshot(
            of: DeliveryPreviewView(deliverable: deliverable, isPresented: .constant(true)),
            named: "AG-007-04-delivery-failure"
        )
    }

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

        window.isHidden = true
    }

    private static let deliveredWish = TrackedWishDTO(
        id: "fixture-wish",
        publicCode: "HW260719-A007",
        city: "杭州",
        landmark: "西湖断桥",
        occasion: "生日",
        message: "替远方的家人看看今天的西湖，并带回一句现场祝福。",
        deliveryType: .spokenVideo,
        deadlineText: "2026-07-20",
        rewardFen: 12000,
        status: .delivered,
        createdAt: 1_752_900_000_000,
        updatedAt: 1_753_000_000_000,
        assignment: WishAssignmentDTO(providerName: "杭州在场响应者", status: .delivered),
        deliverable: WishDeliverableDTO(
            id: "fixture-deliverable",
            kind: .spokenVideo,
            url: URL(string: "https://fixture.invalid/private-capability")!,
            note: "已经在现场完成并记录。",
            createdAt: 1_753_000_000_000
        ),
        events: [
            WishEventDTO(eventType: "已发布", fromStatus: nil, toStatus: .pendingReview, createdAt: 1_752_900_000_000),
            WishEventDTO(eventType: "已交付", fromStatus: .inProgress, toStatus: .delivered, createdAt: 1_753_000_000_000)
        ]
    )
}

private actor PresentationFixtureAPI: WishAPIProtocol {
    let result: Result<TrackedWishDTO, Error>

    init(result: Result<TrackedWishDTO, Error>) {
        self.result = result
    }

    func listWishes(city: String?) async throws -> [PublicWishDTO] { fatalError("Unused fixture path") }
    func createWish(request: CreateWishRequest) async throws -> CreateWishResult { fatalError("Unused fixture path") }
    func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult { fatalError("Unused fixture path") }
    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO { try result.get() }
}
