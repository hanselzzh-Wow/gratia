#if canImport(XCTest)
import XCTest
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
final class HaluowodeCoreTests: XCTestCase {
    
    let baseURL = URL(string: "https://test.haluowode.com")!

    // 1. 公开列表成功与空数组
    func testListWishesSuccess() async throws {
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
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.url.path, "/api/wishes")
            return HTTPResponse(statusCode: 200, headers: [:], data: responseJson)
        }
        
        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        let wishes = try await client.listWishes(city: nil)
        
        XCTAssertEqual(wishes.count, 1)
        XCTAssertEqual(wishes[0].publicCode, "HW260717-A102B")
        XCTAssertEqual(wishes[0].rewardYuan, 18.00)
        XCTAssertEqual(wishes[0].deliveryType, .spokenVideo)
        XCTAssertEqual(wishes[0].status, .matching)
    }
    
    func testListWishesEmpty() async throws {
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
        
        XCTAssertTrue(wishes.isEmpty)
    }

    // 2. 未知 WishStatus 仍可解码并展示兼容文案
    func testUnknownStatusAndTypeFallback() async throws {
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
        
        XCTAssertEqual(wishes.count, 1)
        XCTAssertEqual(wishes[0].deliveryType, .unknown)
        XCTAssertEqual(wishes[0].deliveryType.label, "其它形式")
        XCTAssertEqual(wishes[0].status, .unknown)
        XCTAssertEqual(wishes[0].status.label, "未知状态")
    }

    // 3. 发布 201 与重复 200
    func testCreateWish201() async throws {
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
        
        XCTAssertTrue(result.created)
        XCTAssertEqual(result.wish.publicCode, "HW260718-XYZ12")
    }
    
    func testCreateWishDuplicate200() async throws {
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
        
        XCTAssertFalse(result.created)
    }

    // 4. 字段校验 400 保留 fields
    func testValidationError400() async throws {
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
        
        do {
            _ = try await client.createWish(request: request)
            XCTFail("Expected badRequest error but got success")
        } catch let HaluowodeAPIError.badRequest(message, fields) {
            XCTAssertEqual(message, "请检查心愿信息")
            XCTAssertEqual(fields?["landmark"], "地标需为 2–40 个字符")
            XCTAssertEqual(fields?["message"], "想说的话需为 5–120 个字符")
        } catch {
            XCTFail("Expected badRequest error but got \(error)")
        }
    }

    // 5. 报名 409 与重复 200
    func testResponseConflict409() async throws {
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
        
        do {
            _ = try await client.createWishResponse(wishId: "some-uuid", request: request)
            XCTFail("Expected conflict error")
        } catch let HaluowodeAPIError.conflict(message) {
            XCTAssertEqual(message, "该心愿已匹配或已关闭，不能接受响应")
        } catch {
            XCTFail("Expected conflict error but got \(error)")
        }
    }

    // 6. 追踪 404 不泄露联系方式
    func testTrackWishNotFound404() async throws {
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
            XCTFail("Expected notFound error")
        } catch let HaluowodeAPIError.notFound(message) {
            XCTAssertEqual(message, "没有找到匹配的心愿，请检查编号和联系方式")
            // Make sure the secret contact info is not printed in the error description
            let errDesc = HaluowodeAPIError.notFound(message).localizedDescription
            XCTAssertFalse(errDesc.contains("secret_contact"))
        } catch {
            XCTFail("Expected notFound error but got \(error)")
        }
    }

    // 7. 429 解析 Retry-After
    func testRateLimit429() async throws {
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
            XCTFail("Expected rateLimited error")
        } catch let HaluowodeAPIError.rateLimited(retryAfterSeconds) {
            XCTAssertEqual(retryAfterSeconds, 45)
            XCTAssertTrue(HaluowodeAPIError.rateLimited(retryAfterSeconds).localizedDescription.contains("45"))
        } catch {
            XCTFail("Expected rateLimited error but got \(error)")
        }
    }

    // 8. 非 JSON 错误与损坏 JSON 归类明确
    func testCorruptedJson() async throws {
        let badJson = "not json".data(using: .utf8)!
        let transport = MockTransport { _ in
            return HTTPResponse(statusCode: 200, headers: [:], data: badJson)
        }
        
        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        
        do {
            _ = try await client.listWishes(city: nil)
            XCTFail("Expected decodingError")
        } catch HaluowodeAPIError.decodingError {
            // Success
        } catch {
            XCTFail("Expected decodingError but got \(error)")
        }
    }

    // 9. 取消和隐私/URL 不进入错误描述
    func testRequestCancelled() async throws {
        let transport = MockTransport { _ in
            throw HaluowodeAPIError.requestCancelled
        }
        
        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        
        do {
            _ = try await client.listWishes(city: nil)
            XCTFail("Expected requestCancelled")
        } catch HaluowodeAPIError.requestCancelled {
            // Success
        } catch {
            XCTFail("Expected requestCancelled but got \(error)")
        }
    }
    
    func testDeliverableUrlPrivacy() async throws {
        let secretUrl = "https://haluowode.com/api/deliverables/uuid?token=SECRET_TOKEN_123"
        let transport = MockTransport { _ in
            // Simulate network fail
            throw HaluowodeAPIError.networkError(NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: secretUrl)!]))
        }
        
        let client = WishAPIClient(baseURL: baseURL, transport: transport)
        
        do {
            _ = try await client.listWishes(city: nil)
            XCTFail("Expected networkError")
        } catch let HaluowodeAPIError.networkError(underlying) {
            let desc = underlying.localizedDescription
            let apiErrDesc = HaluowodeAPIError.networkError(underlying).localizedDescription
            XCTAssertFalse(desc.contains("SECRET_TOKEN_123"))
            XCTAssertFalse(apiErrDesc.contains("SECRET_TOKEN_123"))
        } catch {
            XCTFail("Expected networkError but got \(error)")
        }
    }
}
#else
import Foundation

// Fallback dummy to allow swift test command to build/succeed in environment without XCTest (e.g. CLI toolchain only)
#endif
