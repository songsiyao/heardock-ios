import Foundation

/// A failed Heardock request.
///
/// UI layers map `code` to their own copy so the SDK never leaks transport
/// details into user-visible strings.
public struct HeardockError: Error, Sendable, Equatable {
    public enum Code: String, Sendable {
        case notConfigured
        case invalidKey
        case invalidDevice
        case rateLimited
        case payloadTooLarge
        case invalidRequest
        case notFound
        case server
        case network
        case invalidResponse
    }

    public let code: Code
    public let statusCode: Int?
    /// Raw service copy, useful for logging; not meant for users.
    public let serverMessage: String?

    public init(code: Code, statusCode: Int? = nil, serverMessage: String? = nil) {
        self.code = code
        self.statusCode = statusCode
        self.serverMessage = serverMessage
    }

    /// A failure worth retrying later, as opposed to a permanent rejection.
    /// Matches `HeardockException.retryable` in the Flutter SDK.
    public var retryable: Bool {
        switch code {
        case .network, .server, .rateLimited: return true
        default: return false
        }
    }

    static func from(status: Int, data: Data) -> HeardockError {
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let error = payload?["error"] as? [String: Any]
        let serverMessage = error?["message"] as? String
        let code: Code
        switch status {
        case 400: code = .invalidRequest
        case 401: code = .invalidKey
        case 403: code = .invalidDevice
        case 404: code = .notFound
        case 413: code = .payloadTooLarge
        case 429: code = .rateLimited
        case 500...599: code = .server
        default: code = .server
        }
        return HeardockError(code: code, statusCode: status, serverMessage: serverMessage)
    }
}
