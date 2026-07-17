import Foundation

public struct HTTPRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var data: Data

    public init(statusCode: Int, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

public protocol HTTPTransport: Sendable {
    func send(request: HTTPRequest) async throws -> HTTPResponse
}

public final class URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (key, val) in request.headers {
            urlRequest.setValue(val, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HaluowodeAPIError.networkError(
                    NSError(domain: "URLSessionTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
                )
            }
            
            var responseHeaders: [String: String] = [:]
            for (key, val) in httpResponse.allHeaderFields {
                if let keyStr = key as? String, let valStr = val as? String {
                    responseHeaders[keyStr.lowercased()] = valStr
                }
            }
            
            return HTTPResponse(statusCode: httpResponse.statusCode, headers: responseHeaders, data: data)
        } catch let error as URLError {
            if error.code == .cancelled {
                throw HaluowodeAPIError.requestCancelled
            }
            throw HaluowodeAPIError.networkError(error)
        } catch {
            throw HaluowodeAPIError.networkError(error)
        }
    }
}
