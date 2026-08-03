import XCTest
import GratiaCore
@testable import Gratia

final class PublishWishViewModelTests: XCTestCase {

    // Test 1: Invalid input does not call API, and sets validation errors
    @MainActor
    func testInvalidInputValidation() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "test-session-token" }
        )

        // Set invalid fields
        viewModel.name = "" // requesterName too short
        viewModel.contact = "12" // contact too short
        viewModel.landmark = "A" // landmark too short
        viewModel.words = "Hi" // message too short
        viewModel.agreeContact = false // must be true

        let isValid = viewModel.validate()
        XCTAssertFalse(isValid)

        await viewModel.submitWish()

        // State should be failed and API must not be called
        XCTAssertEqual(viewModel.state, .failed("输入校验未通过，请检查红字提示"))
        let request = await mockAPI.lastRequest
        XCTAssertNil(request, "API should not have been called for invalid input")

        // Check specific validation error keys
        XCTAssertNotNil(viewModel.validationErrors["requesterName"])
        XCTAssertNotNil(viewModel.validationErrors["contact"])
        XCTAssertNotNil(viewModel.validationErrors["landmark"])
        XCTAssertNotNil(viewModel.validationErrors["message"])
        XCTAssertNotNil(viewModel.validationErrors["contactConsent"])
    }

    // Test 2: Correct request mapping and DTO encoding
    @MainActor
    func testCorrectRequestMapping() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "test-session-token" }
        )

        // Set valid inputs
        viewModel.name = "小白"
        viewModel.contact = "wx_12345"
        viewModel.city = "杭州"
        viewModel.landmark = "西湖断桥"
        viewModel.scene = "生日祝福"
        viewModel.words = "生日快乐，天天开心！"
        viewModel.deliveryType = "景色配音"
        viewModel.reward = 18 // 18 Yuan
        viewModel.agreeContact = true

        let isValid = viewModel.validate()
        XCTAssertTrue(isValid)

        let task = Task {
            await viewModel.submitWish()
        }

        await mockAPI.waitUntilStarted()

        // Complete request with a mock response
        let mockWish = PublicWishDTO(
            id: "wish-123",
            publicCode: "HW20260718-XYZ",
            city: "杭州",
            landmark: "西湖断桥",
            occasion: "生日祝福",
            message: "生日快乐，天天开心！",
            deliveryType: .sceneryVoiceover,
            deadlineText: "2026-07-18",
            rewardFen: 1800,
            status: .pendingReview,
            createdAt: 1718000000000
        )
        let mockResult = CreateWishResult(wish: mockWish, created: true)
        await mockAPI.completeRequest(with: .success(mockResult))
        await task.value

        XCTAssertEqual(viewModel.state, .success(publicCode: "HW20260718-XYZ"))

        // Check last request properties
        let request = await mockAPI.lastRequest
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.requesterName, "小白")
        XCTAssertEqual(request?.contact, "wx_12345")
        XCTAssertEqual(request?.city, "杭州")
        XCTAssertEqual(request?.landmark, "西湖断桥")
        XCTAssertEqual(request?.occasion, "生日祝福")
        XCTAssertEqual(request?.message, "生日快乐，天天开心！")
        XCTAssertEqual(request?.deliveryType, .sceneryVoiceover) // English DTO Enum mapping
        XCTAssertEqual(request?.rewardFen, 1800) // Correct Yuan-to-Fen conversion
        XCTAssertEqual(request?.contactConsent, true)
    }

    // Test 3: Duplicate submission 200 response with created == false also succeeds
    @MainActor
    func testDuplicateSubmissionSuccess200() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "test-session-token" }
        )

        viewModel.name = "小白"
        viewModel.contact = "wx_12345"
        viewModel.city = "杭州"
        viewModel.landmark = "西湖断桥"
        viewModel.scene = "生日祝福"
        viewModel.words = "生日快乐，天天开心！"
        viewModel.deliveryType = "口播视频"
        viewModel.reward = 12
        viewModel.agreeContact = true

        let task = Task {
            await viewModel.submitWish()
        }

        await mockAPI.waitUntilStarted()

        let mockWish = PublicWishDTO(
            id: "wish-existing",
            publicCode: "HW20260718-EXIST",
            city: "杭州",
            landmark: "西湖断桥",
            occasion: "生日祝福",
            message: "生日快乐，天天开心！",
            deliveryType: .spokenVideo,
            deadlineText: "2026-07-18",
            rewardFen: 1200,
            status: .matching,
            createdAt: 1718000000000
        )
        // Simulate HTTP 200 created == false (duplicate submission)
        let mockResult = CreateWishResult(wish: mockWish, created: false)
        await mockAPI.completeRequest(with: .success(mockResult))
        await task.value

        // Should successfully transition to success state with the existing code
        XCTAssertEqual(viewModel.state, .success(publicCode: "HW20260718-EXIST"))
    }

    // Test 4: Submission failure preserves form draft values
    @MainActor
    func testFailurePreservesDraft() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "test-session-token" }
        )

        viewModel.name = "小白"
        viewModel.contact = "wx_12345"
        viewModel.city = "杭州"
        viewModel.landmark = "西湖断桥"
        viewModel.scene = "生日祝福"
        viewModel.words = "生日快乐，天天开心！"
        viewModel.deliveryType = "手写卡片"
        viewModel.reward = 28
        viewModel.agreeContact = true

        let task = Task {
            await viewModel.submitWish()
        }

        await mockAPI.waitUntilStarted()

        // Simulate API error (e.g. rate limit 429)
        let apiError = GratiaAPIError.rateLimited(retryAfterSeconds: 60)
        await mockAPI.completeRequest(with: .failure(apiError))
        await task.value

        // State is failed
        XCTAssertEqual(viewModel.state, .failed("请求过于频繁，请在 60 秒后再试。"))

        // Draft values MUST remain intact!
        XCTAssertEqual(viewModel.name, "小白")
        XCTAssertEqual(viewModel.contact, "wx_12345")
        XCTAssertEqual(viewModel.city, "杭州")
        XCTAssertEqual(viewModel.landmark, "西湖断桥")
        XCTAssertEqual(viewModel.scene, "生日祝福")
        XCTAssertEqual(viewModel.words, "生日快乐，天天开心！")
        XCTAssertEqual(viewModel.deliveryType, "手写卡片")
        XCTAssertEqual(viewModel.reward, 28)
        XCTAssertTrue(viewModel.agreeContact)
    }

    // Test 5: deduplication during submitting
    @MainActor
    func testSubmissionDeduplication() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "test-session-token" }
        )

        viewModel.name = "小白"
        viewModel.contact = "wx_12345"
        viewModel.city = "杭州"
        viewModel.landmark = "西湖断桥"
        viewModel.scene = "生日祝福"
        viewModel.words = "生日快乐，天天开心！"
        viewModel.deliveryType = "口播视频"
        viewModel.reward = 18
        viewModel.agreeContact = true

        let task1 = Task {
            await viewModel.submitWish()
        }

        await mockAPI.waitUntilStarted()
        XCTAssertEqual(viewModel.state, .submitting)

        // Attempt a second submission while task1 is running
        let task2 = Task {
            await viewModel.submitWish()
        }
        await task2.value

        // complete first request
        let mockWish = PublicWishDTO(
            id: "wish-abc",
            publicCode: "HW20260718-ABC",
            city: "杭州",
            landmark: "西湖断桥",
            occasion: "生日祝福",
            message: "生日快乐，天天开心！",
            deliveryType: .spokenVideo,
            deadlineText: "2026-07-18",
            rewardFen: 1800,
            status: .pendingReview,
            createdAt: 1718000000000
        )
        let mockResult = CreateWishResult(wish: mockWish, created: true)
        await mockAPI.completeRequest(with: .success(mockResult))
        await task1.value

        XCTAssertEqual(viewModel.state, .success(publicCode: "HW20260718-ABC"))
    }

    // Test 6: cancellation does not trigger failed state and reverts to .idle, draft remains intact
    @MainActor
    func testCancellationDoesNotSetFailedState() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "test-session-token" }
        )

        viewModel.name = "小白"
        viewModel.contact = "wx_12345"
        viewModel.city = "杭州"
        viewModel.landmark = "西湖断桥"
        viewModel.scene = "生日祝福"
        viewModel.words = "生日快乐，天天开心！"
        viewModel.deliveryType = "口播视频"
        viewModel.reward = 18
        viewModel.agreeContact = true

        let callerTask = Task {
            await viewModel.submitWish()
        }

        await mockAPI.waitUntilStarted()
        XCTAssertEqual(viewModel.state, .submitting)

        callerTask.cancel()

        await mockAPI.waitUntilCancelled()

        let wasCancelled = await mockAPI.wasCancelled
        XCTAssertTrue(wasCancelled)

        // Complete the pending request with cancellation error to terminate it
        await mockAPI.completeRequest(with: .failure(GratiaAPIError.requestCancelled))
        await callerTask.value

        // State must revert to .idle to allow retries
        XCTAssertEqual(viewModel.state, .idle)

        // Draft values MUST remain intact!
        XCTAssertEqual(viewModel.name, "小白")
        XCTAssertEqual(viewModel.contact, "wx_12345")
        XCTAssertEqual(viewModel.landmark, "西湖断桥")
        XCTAssertEqual(viewModel.words, "生日快乐，天天开心！")
    }
}

// MARK: - Publish Mock API
extension PublishWishViewModelTests {

    /// 未登录时不得调用任何 API，草稿必须完整保留，登录后可直接重试。
    @MainActor
    func testValidDraftWithoutSessionRequiresSignIn() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { nil }
        )

        viewModel.name = "小白"
        viewModel.contact = "13800000000"
        viewModel.landmark = "西湖断桥"
        viewModel.words = "请替我在断桥上说一声生日快乐。"
        viewModel.agreeContact = true

        await viewModel.submitWish()

        XCTAssertEqual(viewModel.state, .requiresSignIn)
        let request = await mockAPI.lastRequest
        XCTAssertNil(request, "未登录时不得发出任何请求")
        XCTAssertEqual(viewModel.landmark, "西湖断桥", "草稿必须保留")
        XCTAssertEqual(viewModel.words, "请替我在断桥上说一声生日快乐。", "草稿必须保留")
        XCTAssertTrue(viewModel.validationErrors.isEmpty, "未登录不是字段校验错误")
    }

    /// 已登录时必须把会话 token 传给账户端点。
    @MainActor
    func testSubmitSendsSessionToken() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "session-token-abc" }
        )

        viewModel.name = "小白"
        viewModel.contact = "13800000000"
        viewModel.landmark = "西湖断桥"
        viewModel.words = "请替我在断桥上说一声生日快乐。"
        viewModel.agreeContact = true

        let submission = Task { await viewModel.submitWish() }
        await mockAPI.waitUntilStarted()

        let token = await mockAPI.lastToken
        XCTAssertEqual(token, "session-token-abc")

        await mockAPI.completeRequest(with: .failure(GratiaAPIError.unknown))
        await submission.value
    }

    /// 会话在提交途中失效：回到登录引导而不是通用失败，草稿保留。
    @MainActor
    func testExpiredSessionDuringSubmitRequiresSignIn() async throws {
        let mockAPI = PublishMockAPI()
        let viewModel = PublishWishViewModel(
            accountAPI: mockAPI,
            accessToken: { "stale-token" }
        )

        viewModel.name = "小白"
        viewModel.contact = "13800000000"
        viewModel.landmark = "西湖断桥"
        viewModel.words = "请替我在断桥上说一声生日快乐。"
        viewModel.agreeContact = true

        let submission = Task { await viewModel.submitWish() }
        await mockAPI.waitUntilStarted()
        await mockAPI.completeRequest(with: .failure(GratiaAPIError.unauthorized(message: "登录已失效，请重新登录")))
        await submission.value

        XCTAssertEqual(viewModel.state, .requiresSignIn)
        XCTAssertEqual(viewModel.landmark, "西湖断桥", "草稿必须保留")
    }
}

actor PublishMockAPI: WishAPIProtocol, AccountAPIProtocol {
    private struct PendingRequest: Sendable {
        let continuation: CheckedContinuation<CreateWishResult, any Error>
    }

    private var pendingRequest: PendingRequest? = nil
    private(set) var lastRequest: CreateWishRequest? = nil
    private(set) var lastToken: String? = nil
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
        fatalError("发布必须走已登录的账户端点")
    }

    func createAccountWishResponse(
        wishId: String,
        request: CreateWishResponseRequest,
        token: String
    ) async throws -> CreateWishResponseResult {
        fatalError("Not used")
    }

    func accountActivity(token: String) async throws -> AccountActivityDTO {
        fatalError("Not used")
    }

    func confirmWishCompletion(wishId: String, token: String) async throws -> AccountWishDTO {
        fatalError("Not used")
    }

    func createAccountWish(request: CreateWishRequest, token: String) async throws -> CreateWishResult {
        lastRequest = request
        lastToken = token

        if Task.isCancelled {
            wasCancelled = true
            throw CancellationError()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CreateWishResult, any Error>) in
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

    func completeRequest(with result: Result<CreateWishResult, any Error>) {
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

    func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult {
        fatalError("Not used")
    }

    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO {
        fatalError("Not used")
    }
}
