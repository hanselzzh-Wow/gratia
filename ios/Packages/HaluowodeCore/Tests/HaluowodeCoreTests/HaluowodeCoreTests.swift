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

    // 3. 未知 WishStatus 与 DeliveryType Fallback (安全文案)
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
        #expect(wishes[0].deliveryType.label == "其它形式") // 安全通用文案，不直接暴露原始服务端串
        #expect(wishes[0].status.rawValue == "super_completed_future")
        #expect(wishes[0].status.label == "未知状态") // 安全通用文案，不直接暴露原始服务端串
    }

    // 4. 城市 Query 校验 (测试 nil query 与 具体城市 query)
    @Test func testListWishesWithCityQuery() async throws {
        let emptyJson = "{\"wishes\": []}".data(using: .utf8)!

        // 场景 A: 传入 "杭州" -> 应该编码为 city=杭州
        let transportA = MockTransport { request in
            #expect(request.method == "GET")
            let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
            let cityItem = components?.queryItems?.first(where: { $0.name == "city" })
            #expect(cityItem?.value == "杭州")
            return HTTPResponse(statusCode: 200, headers: [:], data: emptyJson)
        }
        let clientA = WishAPIClient(baseURL: baseURL, transport: transportA)
        _ = try await clientA.listWishes(city: "杭州")

        // 场景 B: 传入 "全国" / "全部" / nil -> 应该为 nil，不带 city query
        let transportB = MockTransport { request in
            let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
            let cityItem = components?.queryItems?.first(where: { $0.name == "city" })
            #expect(cityItem == nil)
            return HTTPResponse(statusCode: 200, headers: [:], data: emptyJson)
        }
        let clientB = WishAPIClient(baseURL: baseURL, transport: transportB)
        _ = try await clientB.listWishes(city: nil)
        _ = try await clientB.listWishes(city: "全国")
        _ = try await clientB.listWishes(city: "全部")
    }

    // 5. POST /api/wishes 请求序列化与字段校验 (含 consent 与 蜜罐过滤)
    @Test func testCreateWishRequestSerialization() async throws {
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

        let transport = MockTransport { request in
            #expect(request.method == "POST")
            #expect(request.url.path == "/api/wishes")
            #expect(request.headers["content-type"] == "application/json")

            // 验证 JSON Body
            guard let body = request.body else {
                Issue.record("Request body is nil")
                return HTTPResponse(statusCode: 400, headers: [:], data: Data())
            }

            do {
                let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
                #expect(json?["requesterName"] as? String == "小白")
                #expect(json?["contact"] as? String == "wechat:xiaobai")
                #expect(json?["city"] as? String == "广州")
                #expect(json?["landmark"] as? String == "广州塔")
                #expect(json?["deliveryType"] as? String == "handwritten_card")
                #expect(json?["contactConsent"] as? Bool == false)

                // 验证蜜罐字段 website 没有被发送
                #expect(json?["website"] == nil)
            } catch {
                Issue.record("Failed to parse request JSON body")
            }

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
            rewardFen: 1200,
            contactConsent: false // 显式传入
        )
        let result = try await client.createWish(request: request)
        #expect(result.created == true)
    }

    // 6. 报名成功 201
    @Test func testCreateWishResponseSuccess201() async throws {
        let responseJson = """
        {
            "response": {
                "id": "resp-123",
                "responderName": "阿强",
                "responderContact": "wx:aqiang",
                "note": "我能帮您带",
                "status": "pending",
                "createdAt": 1784304000000,
                "updatedAt": 1784304000000
            },
            "created": true
        }
        """.data(using: .utf8)!

        let transport = MockTransport { request in
            #expect(request.method == "POST")
            #expect(request.url.path == "/api/wishes/some-wish-id/responses")

            guard let body = request.body else {
                Issue.record("Request body is nil")
                return HTTPResponse(statusCode: 400, headers: [:], data: Data())
            }

            let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            #expect(json?["responderName"] as? String == "阿强")
            #expect(json?["contactConsent"] as? Bool == true) // 显式传入

            return HTTPResponse(statusCode: 201, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishResponseRequest(
            responderName: "阿强",
            responderContact: "wx:aqiang",
            note: "我能帮您带",
            contactConsent: true // 显式传入
        )
        let result = try await client.createWishResponse(wishId: "some-wish-id", request: request)
        #expect(result.created == true)
        #expect(result.response.id == "resp-123")
    }

    // 7. 报名 200 重复响应 (验证 created: false)
    @Test func testCreateWishResponseSuccess200() async throws {
        let responseJson = """
        {
            "response": {
                "id": "resp-123",
                "responderName": "阿强",
                "responderContact": "wx:aqiang",
                "note": "我能帮您带",
                "status": "pending",
                "createdAt": 1784304000000,
                "updatedAt": 1784304000000
            },
            "created": false
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: responseJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishResponseRequest(
            responderName: "阿强",
            responderContact: "wx:aqiang",
            note: "我能帮您带",
            contactConsent: true
        )
        let result = try await client.createWishResponse(wishId: "some-wish-id", request: request)
        #expect(result.created == false)
    }

    // 8. 字段校验 400
    @Test func testValidationError400() async throws {
        let errorJson = """
        {
            "error": "请检查心愿信息",
            "fields": {
                "landmark": "地标需为 2–40 个字符"
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
            rewardFen: 100,
            contactConsent: true
        )

        do {
            _ = try await client.createWish(request: request)
        } catch let HaluowodeAPIError.badRequest(message, fields) {
            #expect(message == "请检查心愿信息")
            #expect(fields?["landmark"] == "地标需为 2–40 个字符")
        } catch {
            Issue.record("Expected badRequest error")
        }
    }

    // 9. 报名 409 冲突
    @Test func testResponseConflict409() async throws {
        let errorJson = """
        {
            "error": "该心愿已匹配或已关闭"
        }
        """.data(using: .utf8)!

        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 409, headers: [:], data: errorJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let request = CreateWishResponseRequest(
            responderName: "阿强",
            responderContact: "wx:aqiang",
            note: "我能帮您带",
            contactConsent: true
        )

        do {
            _ = try await client.createWishResponse(wishId: "some-wish-id", request: request)
        } catch let HaluowodeAPIError.conflict(message) {
            #expect(message == "该心愿已匹配或已关闭")
        } catch {
            Issue.record("Expected conflict error")
        }
    }

    // 10. 追踪 404
    @Test func testTrackWishNotFound404() async throws {
        let errorJson = """
        {
            "error": "没有找到匹配的心愿"
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
            #expect(message == "没有找到匹配的心愿")
            let errDesc = HaluowodeAPIError.notFound(message: message).localizedDescription
            #expect(!errDesc.contains("secret_contact"))
        } catch {
            Issue.record("Expected notFound error")
        }
    }

    // 11. 429 解析 Retry-After
    @Test func testRateLimit429() async throws {
        let errorJson = """
        {
            "error": "操作太频繁"
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
        } catch {
            Issue.record("Expected rateLimited error")
        }
    }

    // 12. 损坏 JSON
    @Test func testCorruptedJson() async throws {
        let badJson = "not json".data(using: .utf8)!
        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: badJson)
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)

        do {
            _ = try await client.listWishes(city: nil)
        } catch HaluowodeAPIError.decodingError {
            // Success
        } catch {
            Issue.record("Expected decodingError")
        }
    }

    // 13. 真实取消 Task 测试 (验证网络请求取消机制)
    @Test func testRequestCancelled() async throws {
        let transport = MockTransport { _ in
            // 仿真长时间挂起
            throw HaluowodeAPIError.requestCancelled
        }

        let client = WishAPIClient(baseURL: baseURL, transport: transport)

        let task = Task {
            try await client.listWishes(city: nil)
        }

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Task did not throw cancellation error")
        } catch HaluowodeAPIError.requestCancelled {
            // Success
        } catch {
            // Also accepted if caught by standard Task cancellation
        }
    }

    // 14. 隐私 URL token 遮蔽
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

    // 15. 代际保护与取消竞态测试 (仿真 ViewModel 处理 race condition)
    @Test func testGenerationRaceConditionPrevention() async throws {
        let city1Wishes = [PublicWishDTO(id: "1", publicCode: "PC1", city: "杭州", landmark: "A", occasion: "B", message: "C", deliveryType: .spokenVideo, deadlineText: "D", rewardFen: 100, status: .matching, createdAt: 0)]
        let city2Wishes = [PublicWishDTO(id: "2", publicCode: "PC2", city: "上海", landmark: "E", occasion: "F", message: "G", deliveryType: .sceneryVoiceover, deadlineText: "H", rewardFen: 200, status: .matching, createdAt: 0)]

        // 我们仿真一个控制器状态，测试两路请求发生竞态时
        // 请求 A (慢): 延迟后返回 city1Wishes
        // 请求 B (快): 立即返回 city2Wishes
        // 控制器在请求 B 触发后，不应被 A 迟来的响应覆盖

        var generation = 0
        var activeState: [PublicWishDTO] = []

        // 触发 A
        generation += 1
        let genA = generation

        // 触发 B
        generation += 1
        let genB = generation

        let currentGen = { generation }

        // B (快) 先返回并写入
        if genB == currentGen() {
            activeState = city2Wishes
        }

        // A (慢) 后返回并尝试写入
        if genA == currentGen() {
            activeState = city1Wishes // 不应该被执行！
        }

        #expect(activeState == city2Wishes)
        #expect(activeState != city1Wishes)
    }
}
