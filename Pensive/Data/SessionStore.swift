import Foundation

protocol SessionStoring: AnyObject {
    var state: AuthState { get }
    var onStateChange: ((AuthState) -> Void)? { get set }
    var authMessage: String? { get }

    func bootstrapSession()
    func signIn(email: String, password: String)
    func signOut()
    func handleProtectedRequestFailure(_ error: Error)
}

final class SessionStore: SessionStoring {
    private let authAPI: AuthAPI
    private let cookieStorage: HTTPCookieStorage
    private let stateQueue = DispatchQueue(label: "pensive.session-store.state", qos: .userInitiated)

    private(set) var state: AuthState = .launching
    var onStateChange: ((AuthState) -> Void)?
    private(set) var authMessage: String?

    private var bootstrapTask: Task<Void, Never>?
    private var authTask: Task<Void, Never>?

    init(
        authAPI: AuthAPI,
        cookieStorage: HTTPCookieStorage = .shared
    ) {
        self.authAPI = authAPI
        self.cookieStorage = cookieStorage
    }

    func bootstrapSession() {
        stateQueue.sync {
            guard bootstrapTask == nil else { return }
            transition(to: .loadingSession)
            bootstrapTask = Task { [weak self] in
                guard let self else { return }
                defer { self.stateQueue.sync { self.bootstrapTask = nil } }

                do {
                    let response = try await self.authAPI.session()
                    if response.authenticated, let userId = response.userId, !userId.isEmpty {
                        self.authMessage = nil
                        self.transition(to: .authenticated(UserSession(userId: userId, establishedAt: Date())))
                    } else {
                        self.authMessage = nil
                        self.transition(to: .unauthenticated)
                    }
                } catch {
                    let mapped = self.mapAuthError(error)
                    // Keep public route reachable on launch unless this is a hard server issue.
                    if case .server = mapped {
                        self.transition(to: .authError(mapped))
                    } else {
                        self.authMessage = mapped.userMessage
                        self.transition(to: .unauthenticated)
                    }
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            authMessage = AuthError.missingCredentials.userMessage
            transition(to: .unauthenticated)
            return
        }

        stateQueue.sync {
            authTask?.cancel()
            transition(to: .authenticating)

            authTask = Task { [weak self] in
                guard let self else { return }
                defer { self.stateQueue.sync { self.authTask = nil } }

                do {
                    let response = try await self.authAPI.signIn(.init(email: normalizedEmail, password: normalizedPassword))
                    guard response.authenticated, let userId = response.userId, !userId.isEmpty else {
                        let error = AuthError.invalidCredentials
                        self.authMessage = error.userMessage
                        self.transition(to: .unauthenticated)
                        return
                    }

                    self.authMessage = nil
                    self.transition(to: .authenticated(UserSession(userId: userId, establishedAt: Date())))
                } catch {
                    let mapped = self.mapAuthError(error)
                    switch mapped {
                    case .invalidCredentials, .missingCredentials, .networkUnavailable:
                        self.authMessage = mapped.userMessage
                        self.transition(to: .unauthenticated)
                    default:
                        self.transition(to: .authError(mapped))
                    }
                }
            }
        }
    }

    func signOut() {
        stateQueue.sync {
            authTask?.cancel()
            authTask = Task { [weak self] in
                guard let self else { return }
                defer { self.stateQueue.sync { self.authTask = nil } }

                do {
                    try await self.authAPI.signOut()
                } catch {
                    // Sign-out must still clear local auth state even if backend call fails.
                }

                self.clearSessionArtifacts()
                self.authMessage = nil
                self.transition(to: .unauthenticated)
            }
        }
    }

    func handleProtectedRequestFailure(_ error: Error) {
        guard let apiError = error as? APIError, apiError == .unauthorized else { return }

        Task { [weak self] in
            guard let self else { return }

            do {
                let session = try await self.authAPI.session()
                if session.authenticated, let userId = session.userId, !userId.isEmpty {
                    self.authMessage = nil
                    self.transition(to: .authenticated(UserSession(userId: userId, establishedAt: Date())))
                    return
                }
            } catch {
                // Fall through to force sign-out.
            }

            self.clearSessionArtifacts()
            self.authMessage = AuthError.sessionExpired.userMessage
            self.transition(to: .unauthenticated)
        }
    }

    private func clearSessionArtifacts() {
        cookieStorage.cookies?.forEach { cookieStorage.deleteCookie($0) }
    }

    private func transition(to next: AuthState) {
        state = next
        DispatchQueue.main.async { [onStateChange] in
            onStateChange?(next)
        }
    }

    private func mapAuthError(_ error: Error) -> AuthError {
        guard let apiError = error as? APIError else {
            return .unknown
        }

        switch apiError {
        case .unauthorized:
            return .invalidCredentials
        case .networkUnavailable:
            return .networkUnavailable
        case .validation(let message):
            return .server(message: message)
        case .server(let message):
            return .server(message: message)
        case .forbidden, .notFound, .decoding:
            return .unknown
        }
    }
}
