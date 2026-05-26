import Foundation

struct UserSession: Equatable {
    let userId: String
    let establishedAt: Date
}

enum AuthError: Error, Equatable {
    case missingCredentials
    case invalidCredentials
    case sessionExpired
    case networkUnavailable
    case server(message: String)
    case unknown

    var userMessage: String {
        switch self {
        case .missingCredentials:
            return "Enter both email and password."
        case .invalidCredentials:
            return "Email or password is incorrect."
        case .sessionExpired:
            return "Your session expired. Please sign in again."
        case .networkUnavailable:
            return "Network appears offline. Check your connection and try again."
        case .server(let message):
            return message.isEmpty ? "Something went wrong. Please try again." : message
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

enum AuthState: Equatable {
    case launching
    case loadingSession
    case unauthenticated
    case authenticating
    case authenticated(UserSession)
    case authError(AuthError)
}
