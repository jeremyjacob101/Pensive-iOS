import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState
    @Published var email: String = ""
    @Published var password: String = ""
    @Published private(set) var inlineError: String?

    private let sessionStore: SessionStoring

    init(sessionStore: SessionStoring) {
        self.sessionStore = sessionStore
        self.state = sessionStore.state
        self.inlineError = sessionStore.authMessage

        sessionStore.onStateChange = { [weak self] next in
            guard let self else { return }
            Task { @MainActor in
                self.state = next
                self.inlineError = self.sessionStore.authMessage
            }
        }
    }

    func bootstrapSessionIfNeeded() {
        guard case .launching = state else { return }
        state = .loadingSession
        sessionStore.bootstrapSession()
    }

    func signIn() {
        inlineError = nil
        sessionStore.signIn(email: email, password: password)
    }

    func signOut() {
        sessionStore.signOut()
    }

    func retrySessionCheck() {
        inlineError = nil
        sessionStore.bootstrapSession()
    }

    var isLoading: Bool {
        switch state {
        case .loadingSession, .authenticating:
            return true
        default:
            return false
        }
    }
}
