import Foundation

enum APIError: Error, Equatable {
    case networkUnavailable
    case unauthorized
    case forbidden
    case notFound
    case validation(message: String)
    case server(message: String)
    case decoding(message: String)
}

struct APIErrorEnvelope: Decodable {
    let code: String
    let message: String
}

struct APIEnvelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIErrorEnvelope?
    let correlationId: String?
}

struct HTTPRequestSpec {
    enum Method: String { case get = "GET", post = "POST" }
    let endpoint: String
    let method: Method
    let isIdempotent: Bool
    let isMutation: Bool
}

protocol HTTPClientObserver {
    func requestCompleted(endpoint: String, statusCode: Int, durationMs: Int, correlationId: String?)
}

protocol HTTPClientProtocol {
    func send<T: Decodable, B: Encodable>(_ spec: HTTPRequestSpec, body: B?) async throws -> T
}

final class HTTPClient: HTTPClientProtocol {
    private let transport: ConvexTransport
    private let decoder = JSONDecoder()
    private let observer: HTTPClientObserver?

    init(transport: ConvexTransport, observer: HTTPClientObserver? = nil) {
        self.transport = transport
        self.observer = observer
    }

    func send<T: Decodable, B: Encodable>(_ spec: HTTPRequestSpec, body: B?) async throws -> T {
        let timeout: TimeInterval = spec.isMutation ? 30 : 20
        let retries = spec.isIdempotent ? 2 : 0
        var lastError: Error?

        for attempt in 0...retries {
            do {
                let response = try await transport.perform(spec: spec, body: body, timeout: timeout)
                let correlation = correlationID(from: response.headers)

                do {
                    let envelope = try decoder.decode(APIEnvelope<T>.self, from: response.data)
                    observer?.requestCompleted(endpoint: spec.endpoint, statusCode: response.statusCode, durationMs: response.durationMs, correlationId: correlation ?? envelope.correlationId)

                    if envelope.ok, let data = envelope.data { return data }
                    throw mapEnvelopeOrStatusError(envelope.error, statusCode: response.statusCode)
                } catch let decodeError as DecodingError {
                    observer?.requestCompleted(endpoint: spec.endpoint, statusCode: response.statusCode, durationMs: response.durationMs, correlationId: correlation)
                    throw APIError.decoding(message: "Failed decoding response: \(decodeError.localizedDescription)")
                }
            } catch let error as APIError {
                throw error
            } catch {
                lastError = error
                if attempt == retries { break }
                try await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.1...0.35) * 1_000_000_000))
            }
        }

        throw mapRawError(lastError)
    }

    private func mapEnvelopeOrStatusError(_ envelopeError: APIErrorEnvelope?, statusCode: Int) -> APIError {
        if let envelopeError {
            return mapCodeToAPIError(code: envelopeError.code, message: envelopeError.message)
        }

        switch statusCode {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 422: return .validation(message: "Validation error")
        case 500...599: return .server(message: "Server error")
        default: return .server(message: "Unexpected HTTP status \(statusCode)")
        }
    }

    private func mapCodeToAPIError(code: String, message: String) -> APIError {
        switch code {
        case "unauthorized": return .unauthorized
        case "forbidden": return .forbidden
        case "not_found": return .notFound
        case "validation": return .validation(message: message)
        default: return .server(message: message)
        }
    }

    private func mapRawError(_ error: Error?) -> APIError {
        if let apiError = error as? APIError { return apiError }
        return .networkUnavailable
    }

    private func correlationID(from headers: [AnyHashable: Any]) -> String? {
        for candidate in ["x-correlation-id", "x-request-id", "X-Correlation-ID", "X-Request-ID"] {
            if let value = headers[candidate] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
