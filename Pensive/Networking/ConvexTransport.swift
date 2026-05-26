import Foundation

struct HTTPTransportResponse {
    let data: Data
    let statusCode: Int
    let headers: [AnyHashable: Any]
    let durationMs: Int
}

protocol ConvexTransport {
    func perform<B: Encodable>(spec: HTTPRequestSpec, body: B?, timeout: TimeInterval) async throws -> HTTPTransportResponse
}

final class URLSessionConvexTransport: ConvexTransport {
    private let baseURL: URL
    private let session: URLSession
    private let authTokenProvider: () -> String?

    init(baseURL: URL, session: URLSession = .shared, authTokenProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func perform<B: Encodable>(spec: HTTPRequestSpec, body: B?, timeout: TimeInterval) async throws -> HTTPTransportResponse {
        let start = Date()
        var request = URLRequest(url: baseURL.appendingPathComponent(spec.endpoint))
        request.httpMethod = spec.method.rawValue
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authTokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkUnavailable }

        return HTTPTransportResponse(
            data: data,
            statusCode: http.statusCode,
            headers: http.allHeaderFields,
            durationMs: Int(Date().timeIntervalSince(start) * 1000)
        )
    }
}
