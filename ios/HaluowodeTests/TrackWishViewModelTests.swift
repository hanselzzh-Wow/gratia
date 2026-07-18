import XCTest
import HaluowodeCore
@testable import Haluowode

final class TrackWishViewModelTests: XCTestCase {

    // Test 1: Invalid input does not call API, sets validation errors
    @MainActor
    func testInvalidInputValidation() async throws {
        let mockAPI = TrackMockAPI()
        let viewModel = TrackWishViewModel(apiClient: mockAPI)

        // Invalid fields
        viewModel.publicCode = "HW12" // too short
        viewModel.contact = "12" // too short

        let isValid = viewModel.validate()
        XCTAssertFalse(isValid)

        await viewModel.trackWish()

        XCTAssertEqual(viewModel.state, .failed("输入校验未通过，请检查提示"))
        let lastRequest = await mockAPI.lastRequest
        XCTAssertNil(lastRequest, "API should not have been called for invalid input")

        XCTAssertNotNil(viewModel.validationErrors["publicCode"])
        XCTAssertNotNil(viewModel.validationErrors["contact"])
    }

    // Test 2: Correct request mapping, uppercased code, contact clearance upon success
    @MainActor
    func testCorrectRequestMappingAndSuccess() async throws {
        let mockAPI = TrackMockAPI()
        let viewModel = TrackWishViewModel(apiClient: mockAPI)

        viewModel.publicCode = "  hw260718-a001b  " // should trim and uppercase
        viewModel.contact = "  13800000000  " // should trim

        let isValid = viewModel.validate()
        XCTAssertTrue(isValid)

        let task = Task {
            await viewModel.trackWish()
        }

        await mockAPI.waitUntilStarted()

        let mockWish = TrackedWishDTO(
            id: "wish-uuid-123",
            publicCode: "HW260718-A001B",
            city: "杭州",
            landmark: "西湖断桥",
            occasion: "生日",
            message: "祝小白生日快乐",
            deliveryType: .spokenVideo,
            deadlineText: "2026-07-20",
            rewardFen: 15000,
            status: .matching,
            createdAt: 1718000000000,
            updatedAt: 1718000100000,
            assignment: nil,
            deliverable: nil,
            events: []
        )

        await mockAPI.completeRequest(with: .success(mockWish))
        await task.value

        // Check state is loaded
        if case .loaded(let wish) = viewModel.state {
            XCTAssertEqual(wish.id, "wish-uuid-123")
            XCTAssertEqual(wish.publicCode, "HW260718-A001B")
        } else {
            XCTFail("State should be loaded")
        }

        // Verify request payload
        let lastRequest = await mockAPI.lastRequest
        XCTAssertEqual(lastRequest?.publicCode, "HW260718-A001B") // Must be uppercased and trimmed
        XCTAssertEqual(lastRequest?.contact, "13800000000") // Must be trimmed

        // Privacy: contact must be cleared from memory as soon as request succeeds!
        XCTAssertTrue(viewModel.contact.isEmpty)
    }

    // Test 3: 404 error mapping and contact not echoed
    @MainActor
    func testNotFound404ErrorMapping() async throws {
        let mockAPI = TrackMockAPI()
        let viewModel = TrackWishViewModel(apiClient: mockAPI)

        viewModel.publicCode = "HW260718-A001B"
        viewModel.contact = "13800000000"

        let task = Task {
            await viewModel.trackWish()
        }

        await mockAPI.waitUntilStarted()

        let apiError = HaluowodeAPIError.notFound(message: "没有找到匹配的心愿，请检查编号和联系方式")
        await mockAPI.completeRequest(with: .failure(apiError))
        await task.value

        XCTAssertEqual(viewModel.state, .failed("请检查编号和联系方式"))
        // Check contact not cleared (to allow editing and retrying)
        XCTAssertEqual(viewModel.contact, "13800000000")
    }

    // Test 4: 429 rate limit mapping
    @MainActor
    func testRateLimit429ErrorMapping() async throws {
        let mockAPI = TrackMockAPI()
        let viewModel = TrackWishViewModel(apiClient: mockAPI)

        viewModel.publicCode = "HW260718-A001B"
        viewModel.contact = "13800000000"

        let task = Task {
            await viewModel.trackWish()
        }

        await mockAPI.waitUntilStarted()

        let apiError = HaluowodeAPIError.rateLimited(retryAfterSeconds: 30)
        await mockAPI.completeRequest(with: .failure(apiError))
        await task.value

        XCTAssertEqual(viewModel.state, .failed("请求过于频繁，请在 30 秒后再试。"))
    }

    // Test 5: Deduplication of queries
    @MainActor
    func testQueryDeduplication() async throws {
        let mockAPI = TrackMockAPI()
        let viewModel = TrackWishViewModel(apiClient: mockAPI)

        viewModel.publicCode = "HW260718-A001B"
        viewModel.contact = "13800000000"

        let task1 = Task {
            await viewModel.trackWish()
        }

        await mockAPI.waitUntilStarted()
        XCTAssertEqual(viewModel.state, .loading)

        let task2 = Task {
            await viewModel.trackWish()
        }
        await task2.value // Should return immediately due to deduplication

        let mockWish = TrackedWishDTO(
            id: "wish-uuid-123",
            publicCode: "HW260718-A001B",
            city: "杭州",
            landmark: "西湖断桥",
            occasion: "生日",
            message: "祝小白生日快乐",
            deliveryType: .spokenVideo,
            deadlineText: "2026-07-20",
            rewardFen: 15000,
            status: .matching,
            createdAt: 1718000000000,
            updatedAt: 1718000100000,
            assignment: nil,
            deliverable: nil,
            events: []
        )

        await mockAPI.completeRequest(with: .success(mockWish))
        await task1.value

        let callCount = await mockAPI.callCount
        XCTAssertEqual(callCount, 1, "API should only be called once due to deduplication")

        if case .loaded(let wish) = viewModel.state {
            XCTAssertEqual(wish.id, "wish-uuid-123")
        } else {
            XCTFail("State should be loaded")
        }
    }

    // Test 6: Cancellation recovery
    @MainActor
    func testCancellationRecovery() async throws {
        let mockAPI = TrackMockAPI()
        let viewModel = TrackWishViewModel(apiClient: mockAPI)

        viewModel.publicCode = "HW260718-A001B"
        viewModel.contact = "13800000000"

        let callerTask = Task {
            await viewModel.trackWish()
        }

        await mockAPI.waitUntilStarted()
        XCTAssertEqual(viewModel.state, .loading)

        callerTask.cancel()

        await mockAPI.waitUntilCancelled()

        let wasCancelled = await mockAPI.wasCancelled
        XCTAssertTrue(wasCancelled)

        await mockAPI.completeRequest(with: .failure(HaluowodeAPIError.requestCancelled))
        await callerTask.value

        // Reverts to .idle
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.contact, "13800000000") // Form values preserved
    }
}

// MARK: - Track Mock API
actor TrackMockAPI: WishAPIProtocol {
    private struct PendingRequest: Sendable {
        let continuation: CheckedContinuation<TrackedWishDTO, any Error>
    }

    private var pendingRequest: PendingRequest? = nil
    private(set) var lastRequest: TrackWishRequest? = nil
    private(set) var wasCancelled = false
    private(set) var callCount = 0
    private var startContinuation: CheckedContinuation<Void, Never>? = nil
    private var cancelContinuation: CheckedContinuation<Void, Never>? = nil

    func waitUntilStarted() async {
        if pendingRequest != nil { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func waitUntilCancelled() async {
        if wasCancelled { return }
        await withCheckedContinuation { continuation in
            cancelContinuation = continuation
        }
    }

    func listWishes(city: String?) async throws -> [PublicWishDTO] {
        fatalError("Not used")
    }

    func createWish(request: CreateWishRequest) async throws -> CreateWishResult {
        fatalError("Not used")
    }

    func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult {
        fatalError("Not used")
    }

    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO {
        callCount += 1
        lastRequest = request

        if Task.isCancelled {
            wasCancelled = true
            throw CancellationError()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TrackedWishDTO, any Error>) in
                pendingRequest = PendingRequest(continuation: continuation)

                let waiter = startContinuation
                startContinuation = nil
                waiter?.resume()
            }
        } onCancel: {
            Task {
                await self.markCancelled()
            }
        }
    }

    private func markCancelled() {
        wasCancelled = true
        let waiter = cancelContinuation
        cancelContinuation = nil
        waiter?.resume()
    }

    func completeRequest(with result: Result<TrackedWishDTO, any Error>) {
        if let pending = pendingRequest {
            pendingRequest = nil
            switch result {
            case .success(let res):
                pending.continuation.resume(returning: res)
            case .failure(let err):
                pending.continuation.resume(throwing: err)
            }
        }
    }
}
