import XCTest
import HaluowodeCore
@testable import Haluowode

final class WishResponseViewModelTests: XCTestCase {

    // Test 1: Invalid input does not call API, and sets validation errors
    @MainActor
    func testInvalidInputValidation() async throws {
        let mockAPI = ResponseMockAPI()
        let viewModel = WishResponseViewModel(wishId: "wish-123", apiClient: mockAPI)

        // Set invalid fields
        viewModel.name = "" // responderName too short
        viewModel.contact = "12" // responderContact too short
        viewModel.note = String(repeating: "A", count: 161) // note too long
        viewModel.agreeContact = false // must be true

        let isValid = viewModel.validate()
        XCTAssertFalse(isValid)

        await viewModel.submitResponse()

        XCTAssertEqual(viewModel.state, .failed("输入校验未通过，请检查提示"))
        let lastId = await mockAPI.lastWishId
        XCTAssertNil(lastId, "API should not have been called for invalid input")

        XCTAssertNotNil(viewModel.validationErrors["responderName"])
        XCTAssertNotNil(viewModel.validationErrors["responderContact"])
        XCTAssertNotNil(viewModel.validationErrors["note"])
        XCTAssertNotNil(viewModel.validationErrors["contactConsent"])
    }

    // Test 2: Correct request mapping, note conversion to nil, and ID mapping
    @MainActor
    func testCorrectRequestMapping() async throws {
        let mockAPI = ResponseMockAPI()
        let viewModel = WishResponseViewModel(wishId: "wish-abc-real-id", apiClient: mockAPI)

        viewModel.name = "张三"
        viewModel.contact = "13800000000"
        viewModel.note = "  " // empty note should become nil
        viewModel.agreeContact = true

        let isValid = viewModel.validate()
        XCTAssertTrue(isValid)

        let task = Task {
            await viewModel.submitResponse()
        }

        await mockAPI.waitUntilStarted()

        let mockResponseDTO = WishResponseDTO(
            id: "response-999",
            responderName: "张三",
            responderContact: "13800000000",
            note: nil,
            status: .pending,
            createdAt: 1718000000000,
            updatedAt: 1718000000000
        )
        let mockResult = CreateWishResponseResult(response: mockResponseDTO, created: true)
        await mockAPI.completeRequest(with: .success(mockResult))
        await task.value

        XCTAssertEqual(viewModel.state, .success)

        let lastId = await mockAPI.lastWishId
        let lastRequest = await mockAPI.lastRequest

        XCTAssertEqual(lastId, "wish-abc-real-id") // Assert correct real id used, not publicCode
        XCTAssertEqual(lastRequest?.responderName, "张三")
        XCTAssertEqual(lastRequest?.responderContact, "13800000000")
        XCTAssertNil(lastRequest?.note) // Empty note mapped to nil
        XCTAssertEqual(lastRequest?.contactConsent, true)
    }

    // Test 3: Duplicate submission 200 response with created == false also succeeds
    @MainActor
    func testDuplicateSubmissionSuccess200() async throws {
        let mockAPI = ResponseMockAPI()
        let viewModel = WishResponseViewModel(wishId: "wish-123", apiClient: mockAPI)

        viewModel.name = "张三"
        viewModel.contact = "13800000000"
        viewModel.note = "  可以帮忙  "
        viewModel.agreeContact = true

        let task = Task {
            await viewModel.submitResponse()
        }

        await mockAPI.waitUntilStarted()

        let mockResponseDTO = WishResponseDTO(
            id: "response-existing",
            responderName: "张三",
            responderContact: "13800000000",
            note: "可以帮忙",
            status: .pending,
            createdAt: 1718000000000,
            updatedAt: 1718000000000
        )
        let mockResult = CreateWishResponseResult(response: mockResponseDTO, created: false)
        await mockAPI.completeRequest(with: .success(mockResult))
        await task.value

        XCTAssertEqual(viewModel.state, .success)
        let lastRequest = await mockAPI.lastRequest
        XCTAssertEqual(lastRequest?.note, "可以帮忙")
    }

    // Test 4: Submission failure preserves form draft values
    @MainActor
    func testFailurePreservesDraft() async throws {
        let mockAPI = ResponseMockAPI()
        let viewModel = WishResponseViewModel(wishId: "wish-123", apiClient: mockAPI)

        viewModel.name = "张三"
        viewModel.contact = "13800000000"
        viewModel.note = "可以帮忙"
        viewModel.agreeContact = true

        let task = Task {
            await viewModel.submitResponse()
        }

        await mockAPI.waitUntilStarted()

        let apiError = HaluowodeAPIError.conflict(message: "心愿不再接受响应")
        await mockAPI.completeRequest(with: .failure(apiError))
        await task.value

        XCTAssertEqual(viewModel.state, .failed("心愿不再接受响应"))

        // Draft values must be preserved
        XCTAssertEqual(viewModel.name, "张三")
        XCTAssertEqual(viewModel.contact, "13800000000")
        XCTAssertEqual(viewModel.note, "可以帮忙")
        XCTAssertTrue(viewModel.agreeContact)
    }

    // Test 5: deduplication during submitting
    @MainActor
    func testSubmissionDeduplication() async throws {
        let mockAPI = ResponseMockAPI()
        let viewModel = WishResponseViewModel(wishId: "wish-123", apiClient: mockAPI)

        viewModel.name = "张三"
        viewModel.contact = "13800000000"
        viewModel.agreeContact = true

        let task1 = Task {
            await viewModel.submitResponse()
        }

        await mockAPI.waitUntilStarted()
        XCTAssertEqual(viewModel.state, .submitting)

        let task2 = Task {
            await viewModel.submitResponse()
        }
        await task2.value // Should return immediately due to deduplication

        let mockResponseDTO = WishResponseDTO(
            id: "response-123",
            responderName: "张三",
            responderContact: "13800000000",
            note: nil,
            status: .pending,
            createdAt: 1718000000000,
            updatedAt: 1718000000000
        )
        let mockResult = CreateWishResponseResult(response: mockResponseDTO, created: true)
        await mockAPI.completeRequest(with: .success(mockResult))
        await task1.value

        XCTAssertEqual(viewModel.state, .success)
    }

    // Test 6: cancellation does not trigger failed state and reverts to .idle, draft remains intact
    @MainActor
    func testCancellationDoesNotSetFailedState() async throws {
        let mockAPI = ResponseMockAPI()
        let viewModel = WishResponseViewModel(wishId: "wish-123", apiClient: mockAPI)

        viewModel.name = "张三"
        viewModel.contact = "13800000000"
        viewModel.agreeContact = true

        let callerTask = Task {
            await viewModel.submitResponse()
        }

        await mockAPI.waitUntilStarted()
        XCTAssertEqual(viewModel.state, .submitting)

        callerTask.cancel()

        await mockAPI.waitUntilCancelled()

        let wasCancelled = await mockAPI.wasCancelled
        XCTAssertTrue(wasCancelled)

        // Complete the pending request with cancellation error to terminate it
        await mockAPI.completeRequest(with: .failure(HaluowodeAPIError.requestCancelled))
        await callerTask.value

        // State must revert to .idle to allow retries
        XCTAssertEqual(viewModel.state, .idle)

        // Draft values must remain intact
        XCTAssertEqual(viewModel.name, "张三")
        XCTAssertEqual(viewModel.contact, "13800000000")
        XCTAssertTrue(viewModel.agreeContact)
    }
}

// MARK: - Response Mock API
actor ResponseMockAPI: WishAPIProtocol {
    private struct PendingRequest: Sendable {
        let continuation: CheckedContinuation<CreateWishResponseResult, any Error>
    }

    private var pendingRequest: PendingRequest? = nil
    private(set) var lastWishId: String? = nil
    private(set) var lastRequest: CreateWishResponseRequest? = nil
    private(set) var wasCancelled = false
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
        lastWishId = wishId
        lastRequest = request

        if Task.isCancelled {
            wasCancelled = true
            throw CancellationError()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CreateWishResponseResult, any Error>) in
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

    func completeRequest(with result: Result<CreateWishResponseResult, any Error>) {
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

    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO {
        fatalError("Not used")
    }
}
