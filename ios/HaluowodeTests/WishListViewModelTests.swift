import XCTest
import HaluowodeCore
@testable import Haluowode

final class WishListViewModelTests: XCTestCase {

    // Test 2a: Request A in waiting, starts B, cancels A in transit, and A late success doesn't overwrite B's success.
    @MainActor
    func testRaceCondition_LateSuccess() async throws {
        let mockAPI = ControllableMockAPI()
        let viewModel = WishListViewModel(apiClient: mockAPI)

        // 1. Trigger Request A (slow request)
        viewModel.selectedCity = "杭州"
        let taskA = Task {
            await viewModel.fetchWishes()
        }

        // Deterministically wait for A to start
        await mockAPI.waitUntilStarted("杭州")
        XCTAssertEqual(viewModel.state, .loading)

        // 2. Trigger Request B (fast request)
        viewModel.selectedCity = "上海"
        let taskB = Task {
            await viewModel.fetchWishes()
        }

        // Deterministically wait for B to start (which will trigger A's cancellation)
        await mockAPI.waitUntilStarted("上海")

        // Wait deterministically for A to be observed as cancelled by the mock API actor
        await mockAPI.waitUntilCancelled("杭州")

        // Verify that A was cancelled!
        let cancelled = await mockAPI.wasCancelled("杭州")
        XCTAssertTrue(cancelled, "Request A for 杭州 should have been cancelled by trigger B")

        // 3. Complete B successfully
        let mockWishesB = [
            PublicWishDTO(id: "2", publicCode: "HW-B", city: "上海", landmark: "E", occasion: "F", message: "G", deliveryType: .spokenVideo, deadlineText: "H", rewardFen: 100, status: .matching, createdAt: 0)
        ]
        await mockAPI.completeRequest("上海", with: .success(mockWishesB))
        await taskB.value

        // Verify state is loaded with B's wishes
        XCTAssertEqual(viewModel.state, .loaded(mockWishesB))

        // 4. A (slow request) now completes with success (late success)
        let mockWishesA = [
            PublicWishDTO(id: "1", publicCode: "HW-A", city: "杭州", landmark: "X", occasion: "Y", message: "Z", deliveryType: .sceneryVoiceover, deadlineText: "W", rewardFen: 200, status: .matching, createdAt: 0)
        ]
        await mockAPI.completeRequest("杭州", with: .success(mockWishesA))
        await taskA.value

        // Verify A's late success does NOT overwrite B's loaded state!
        XCTAssertEqual(viewModel.state, .loaded(mockWishesB))
    }

    // Test 2b: Request A in waiting, starts B, cancels A in transit, and A late failure doesn't overwrite B's success.
    @MainActor
    func testRaceCondition_LateFailure() async throws {
        let mockAPI = ControllableMockAPI()
        let viewModel = WishListViewModel(apiClient: mockAPI)

        // 1. Trigger Request A (slow request)
        viewModel.selectedCity = "杭州"
        let taskA = Task {
            await viewModel.fetchWishes()
        }

        // Deterministically wait for A to start
        await mockAPI.waitUntilStarted("杭州")
        XCTAssertEqual(viewModel.state, .loading)

        // 2. Trigger Request B (fast request)
        viewModel.selectedCity = "上海"
        let taskB = Task {
            await viewModel.fetchWishes()
        }

        // Deterministically wait for B to start (which will trigger A's cancellation)
        await mockAPI.waitUntilStarted("上海")

        // Wait deterministically for A to be observed as cancelled by the mock API actor
        await mockAPI.waitUntilCancelled("杭州")

        // Verify that A was cancelled!
        let cancelled = await mockAPI.wasCancelled("杭州")
        XCTAssertTrue(cancelled, "Request A for 杭州 should have been cancelled by trigger B")

        // 3. Complete B successfully
        let mockWishesB = [
            PublicWishDTO(id: "2", publicCode: "HW-B", city: "上海", landmark: "E", occasion: "F", message: "G", deliveryType: .spokenVideo, deadlineText: "H", rewardFen: 100, status: .matching, createdAt: 0)
        ]
        await mockAPI.completeRequest("上海", with: .success(mockWishesB))
        await taskB.value

        // Verify state is loaded with B's wishes
        XCTAssertEqual(viewModel.state, .loaded(mockWishesB))

        // 4. A (slow request) now completes with error (late failure)
        await mockAPI.completeRequest("杭州", with: .failure(HaluowodeAPIError.requestCancelled))
        await taskA.value

        // Verify A's late failure does NOT overwrite B's loaded state!
        XCTAssertEqual(viewModel.state, .loaded(mockWishesB))
    }

    // Test 3: Cancelling caller task propagates cancellation to API request, and doesn't display failed state.
    @MainActor
    func testCallerTaskCancellationPropagation() async throws {
        let mockAPI = ControllableMockAPI()
        let viewModel = WishListViewModel(apiClient: mockAPI)

        viewModel.selectedCity = "北京"

        // Start caller task
        let callerTask = Task {
            await viewModel.fetchWishes()
        }

        // Deterministically wait for the request to start
        await mockAPI.waitUntilStarted("北京")
        XCTAssertEqual(viewModel.state, .loading)

        // Cancel caller task
        callerTask.cancel()

        // Wait deterministically for Beijing request to be observed as cancelled by the mock API actor
        await mockAPI.waitUntilCancelled("北京")

        // Verify API request was cancelled
        let cancelled = await mockAPI.wasCancelled("北京")
        XCTAssertTrue(cancelled, "Beijing request should have received cancellation signal")

        // Resume the pending request with a cancellation error to let the task resume and terminate
        await mockAPI.completeRequest("北京", with: .failure(HaluowodeAPIError.requestCancelled))

        // Wait for task to finish
        await callerTask.value

        // Assert state is NOT failed using switch
        switch viewModel.state {
        case .failed(let message):
            XCTFail("State should not be failed. Got: .failed(\(message))")
        default:
            // Correct state should be loading (or the previous state)
            XCTAssertEqual(viewModel.state, .loading)
        }
    }
}

// MARK: - Controllable Mock API
actor ControllableMockAPI: WishAPIProtocol {
    private struct PendingRequest: Sendable {
        let continuation: CheckedContinuation<[PublicWishDTO], any Error>
    }

    private var pendingRequests: [String: PendingRequest] = [:]
    private var cancelledRequests = Set<String>()
    private var startContinuations: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var cancelContinuations: [String: [CheckedContinuation<Void, Never>]] = [:]

    func waitUntilStarted(_ city: String) async {
        if pendingRequests[city] != nil {
            return
        }
        await withCheckedContinuation { continuation in
            startContinuations[city, default: []].append(continuation)
        }
    }

    func waitUntilCancelled(_ city: String) async {
        if cancelledRequests.contains(city) {
            return
        }
        await withCheckedContinuation { continuation in
            cancelContinuations[city, default: []].append(continuation)
        }
    }

    func listWishes(city: String?) async throws -> [PublicWishDTO] {
        let key = city ?? "全国"

        if Task.isCancelled {
            cancelledRequests.insert(key)
            throw CancellationError()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[PublicWishDTO], any Error>) in
                Task { [key] in
                    self.registerRequest(key, continuation: continuation)
                }
            }
        } onCancel: {
            Task { [key] in
                await self.cancelRequest(key)
            }
        }
    }

    private func registerRequest(_ key: String, continuation: CheckedContinuation<[PublicWishDTO], any Error>) {
        pendingRequests[key] = PendingRequest(continuation: continuation)

        let waiters = startContinuations.removeValue(forKey: key) ?? []
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func cancelRequest(_ key: String) {
        cancelledRequests.insert(key)

        let waiters = cancelContinuations.removeValue(forKey: key) ?? []
        for waiter in waiters {
            waiter.resume()
        }
    }

    func wasCancelled(_ city: String) -> Bool {
        cancelledRequests.contains(city)
    }

    func completeRequest(_ city: String, with result: Result<[PublicWishDTO], any Error>) {
        if let pending = pendingRequests.removeValue(forKey: city) {
            switch result {
            case .success(let wishes):
                pending.continuation.resume(returning: wishes)
            case .failure(let error):
                pending.continuation.resume(throwing: error)
            }
        }
    }

    func createWish(request: CreateWishRequest) async throws -> CreateWishResult {
        fatalError("Not used in unit tests")
    }

    func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult {
        fatalError("Not used in unit tests")
    }

    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO {
        fatalError("Not used in unit tests")
    }
}
