import Testing
import Foundation
@testable import HaluowodeCore

// MARK: - Mock Transport
final class MockTransport: HTTPTransport, Sendable {
    private let handler: @Sendable (HTTPRequest) throws -> HTTPResponse

    init(handler: @escaping @Sendable (HTTPRequest) throws -> HTTPResponse) {
        self.handler = handler
    }

    func send(request: HTTPRequest) async throws -> HTTPResponse {
        try handler(request)
    }
}

// MARK: - Test Cases
struct HaluowodeCoreTests {

    let baseURL = URL(string: "https://test.haluowode.com")!

    // 1. 公开列表成功
    @Test func testListWishesSuccess() async throws {
        let responseJson = """
        {
            "wishes": [
                {
                    "id": "uuid-1",
                    "publicCode": "HW260717-A102B",
                    "city": "杭州",
                    "landmark": "西湖断桥",
                    "occasion": "生日祝福",
                    "message": "祝阿白生日快乐",
                    "deliveryType": "spoken_video",
                    "deadlineText": "2026-07-20",
                    "rewardFen": 1800,
                    "status": "matching",
                    "createdAt": 1784304000000
                }
            ]
        }
        """.data(using: .utf8)!

        let transport = MockTransport { request in
            #expect(request.method == "GET")
            #expect(request.url.path == "/api/wishes")
            return HTTPResponse(statusCode: 200, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let wishes = try await client.listWishes(city: nil)

        #expect(wishes.count == 1)
        #expect(wishes[0].publicCode == "HW260717-A102B")
        #expect(wishes[0].rewardYuan == 18.00)
        #expect(wishes[0].deliveryType == .spokenVideo)
        #expect(wishes[0].status == .matching)
    }

    // 2. 公开列表空数组
    @Test func testListWishesEmpty() async throws {
        let responseJson = """
        {
            "wishes": []
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let wishes = try await client.listWishes(city: "北京")

        #expect(wishes.isEmpty)
    }

    // 3. 未知 WishStatus 与 DeliveryType Fallback
    @Test func testUnknownStatusAndTypeFallback() async throws {
        let responseJson = """
        {
            "wishes": [
                {
                    "id": "uuid-2",
                    "publicCode": "HW260717-C349D",
                    "city": "上海",
                    "landmark": "和平饭店",
                    "occasion": "浪漫表白",
                    "message": "我喜欢你",
                    "deliveryType": "future_3d_hologram",
                    "deadlineText": "明天",
                    "rewardFen": 2800,
                    "status": "super_completed_future",
                    "createdAt": 1784304000000
                }
            ]
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let wishes = try await client.listWishes(city: nil)

        #expect(wishes.count == 1)
        #expect(wishes[0].deliveryType.rawValue == "future_3d_hologram")
        #expect(wishes[0].deliveryType.label == "其它形式 (future_3d_hologram)")
        #expect(wishes[0].status.rawValue == "super_completed_future")
        #expect(wishes[0].status.label == "未知状态 (super_completed_future)")
    }

    // 4. 发布 201 成功
    @Test func testCreateWish201() async throws {
        let responseJson = """
        {
            "wish": {
                "id": "new-uuid",
                "publicCode": "HW260718-XYZ12",
                "city": "广州",
                "landmark": "广州塔",
                "occasion": "节日问候",
                "message": "中秋快乐",
                "deliveryType": "handwritten_card",
                "deadlineText": "2026-09-15",
                "rewardFen": 1200,
                "status": "pending_review",
                "createdAt": 1784304000000
            },
            "created": true
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 201, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishRequest(
            requesterName: "小白",
            contact: "wechat:xiaobai",
            city: "广州",
            landmark: "广州塔",
            occasion: "节日问候",
            message: "中秋快乐",
            deliveryType: .handwrittenCard,
            deadlineText: "2026-09-15",
            rewardFen: 1200
        )
        let result = try await client.createWish(request: request)

        #expect(result.created == true)
        #expect(result.wish.publicCode == "HW260718-XYZ12")
    }

    // 5. 发布 200 重复提交
    @Test func testCreateWishDuplicate200() async throws {
        let responseJson = """
        {
            "wish": {
                "id": "existing-uuid",
                "publicCode": "HW260718-XYZ12",
                "city": "广州",
                "landmark": "广州塔",
                "occasion": "节日问候",
                "message": "中秋快乐",
                "deliveryType": "handwritten_card",
                "deadlineText": "2026-09-15",
                "rewardFen": 1200,
                "status": "pending_review",
                "createdAt": 1784304000000
            },
            "created": false
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishRequest(
            requesterName: "小白",
            contact: "wechat:xiaobai",
            city: "广州",
            landmark: "广州塔",
            occasion: "节日问候",
            message: "中秋快乐",
            deliveryType: .handwrittenCard,
            deadlineText: "2026-09-15",
            rewardFen: 1200
        )
        let result = try await client.createWish(request: request)

        #expect(result.created == false)
    }

    // 6. 字段校验 400 保留 fields
    @Test func testValidationError400() async throws {
        let errorJson = """
        {
            "error": "请检查心愿信息",
            "fields": {
                "landmark": "地标需为 2–40 个字符",
                "message": "想说的话需为 5–120 个字符"
            }
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 400, headers: [:], data: errorJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishRequest(
            requesterName: "小白",
            contact: "123",
            city: "A",
            landmark: "B",
            occasion: "C",
            message: "D",
            deliveryType: .spokenVideo,
            deadlineText: "E",
            rewardFen: 100
        )

        await #expect(throws: HaluowodeAPIError.self) {
            _ = try await client.createWish(request: request)
        }

        do {
            _ = try await client.createWish(request: request)
        } catch let HaluowodeAPIError.badRequest(message, fields) {
            #expect(message == "请检查心愿信息")
            #expect(fields?["landmark"] == "地标需为 2–40 个字符")
            #expect(fields?["message"] == "想说的话需为 5–120 个字符")
        } catch {
            Issue.record("Expected badRequest error but got \(error)")
        }
    }

    // 7. 报名 409 冲突
    @Test func testResponseConflict409() async throws {
        let errorJson = """
        {
            "error": "该心愿已匹配或已关闭，不能接受响应"
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 409, headers: [:], data: errorJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishResponseRequest(
            responderName: "阿强",
            responderContact: "wx:aqiang",
            note: "我就在这"
        )

        await #expect(throws: HaluowodeAPIError.self) {
            _ = try await client.createWishResponse(wishId: "some-uuid", request: request)
        }

        do {
            _ = try await client.createWishResponse(wishId: "some-uuid", request: request)
        } catch let HaluowodeAPIError.conflict(message) {
            #expect(message == "该心愿已匹配或已关闭，不能接受响应")
        } catch {
            Issue.record("Expected conflict error")
        }
    }

    // 8. 追踪 404 不泄露联系方式
    @Test func testTrackWishNotFound404() async throws {
        let errorJson = """
        {
            "error": "没有找到匹配的心愿，请检查编号和联系方式"
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 404, headers: [:], data: errorJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = TrackWishRequest(publicCode: "HW12345-ABCDE", contact: "secret_contact")

        do {
            _ = try await client.trackWish(request: request)
        } catch let HaluowodeAPIError.notFound(message) {
            #expect(message == "没有找到匹配的心愿，请检查编号和联系方式")
            let errDesc = HaluowodeAPIError.notFound(message: message).localizedDescription
            #expect(!errDesc.contains("secret_contact"))
        } catch {
            Issue.record("Expected notFound error")
        }
    }

    // 9. 429 解析 Retry-After
    @Test func testRateLimit429() async throws {
        let errorJson = """
        {
            "error": "操作太频繁，请稍后再试"
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(
                statusCode: 429,
                headers: ["retry-after": "45"],
                data: errorJson
            )
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = TrackWishRequest(publicCode: "HW12345-ABCDE", contact: "abc")

        do {
            _ = try await client.trackWish(request: request)
        } catch let HaluowodeAPIError.rateLimited(retryAfterSeconds) {
            #expect(retryAfterSeconds == 45)
            #expect(HaluowodeAPIError.rateLimited(retryAfterSeconds: retryAfterSeconds).localizedDescription.contains("45"))
        } catch {
            Issue.record("Expected rateLimited error")
        }
    }

    // 10. 非 JSON 错误与损坏 JSON 归类明确
    @Test func testCorruptedJson() async throws {
        let badJson = "not json".data(using: .utf8)!
        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: badJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)

        await #expect(throws: HaluowodeAPIError.self) {
            _ = try await client.listWishes(city: nil)
        }

        do {
            _ = try await client.listWishes(city: nil)
        } catch HaluowodeAPIError.decodingError {
            // Success
        } catch {
            Issue.record("Expected decodingError")
        }
    }

    // 11. 取消请求
    @Test func testRequestCancelled() async throws {
        let transport = MockTransport { _ in
            throw HaluowodeAPIError.requestCancelled
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)

        await #expect(throws: HaluowodeAPIError.self) {
            _ = try await client.listWishes(city: nil)
        }

        do {
            _ = try await client.listWishes(city: nil)
        } catch HaluowodeAPIError.requestCancelled {
            // Success
        } catch {
            Issue.record("Expected requestCancelled")
        }
    }

    // 12. 隐私/URL 不进入错误描述
    @Test func testDeliverableUrlPrivacy() async throws {
        let secretUrl = "https://haluowode.com/api/deliverables/uuid?token=SECRET_TOKEN_123"
        let transport = MockTransport { _ in
            throw HaluowodeAPIError.networkError(NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: secretUrl)!]))
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)

        do {
            _ = try await client.listWishes(city: nil)
        } catch let HaluowodeAPIError.networkError(underlying) {
            let desc = underlying.localizedDescription
            let apiErrDesc = HaluowodeAPIError.networkError(underlying).localizedDescription
            #expect(!desc.contains("SECRET_TOKEN_123"))
            #expect(!apiErrDesc.contains("SECRET_TOKEN_123"))
        } catch {
            Issue.record("Expected networkError")
        }
    }
}
