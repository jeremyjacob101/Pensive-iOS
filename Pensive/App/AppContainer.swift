import Foundation

struct AppContainer {
    let environment: AppEnvironment
    let sessionStore: SessionStoring
    let api: ConvexAPI

    static func bootstrap(bundle: Bundle = .main) -> AppContainer {
        let env = AppEnvironment.load(from: bundle)
        #if DEBUG
        print("AppEnvironment[\(env.appEnvName)] base=\(env.convexBaseURL) http=\(env.convexHTTPActionBaseURL)")
        #endif
        if let userId = ProcessInfo.processInfo.environment["UI_TEST_AUTHENTICATED_USER_ID"], !userId.isEmpty {
            let tokenStore = AuthTokenStore()
            let api = AppContainer.makeAPI(environment: env, tokenStore: tokenStore)
            return AppContainer(environment: env, sessionStore: UITestSessionStore(userId: userId), api: api)
        }
        let tokenStore = AuthTokenStore()
        let api = AppContainer.makeAPI(environment: env, tokenStore: tokenStore)
        return AppContainer(environment: env, sessionStore: SessionStore(authAPI: api.auth, tokenStore: tokenStore), api: api)
    }

    private static func makeAPI(environment: AppEnvironment, tokenStore: AuthTokenStoring) -> ConvexAPI {
        let base = URL(string: environment.convexHTTPActionBaseURL) ?? URL(string: environment.convexBaseURL)!
        let transport = URLSessionConvexTransport(baseURL: base, authTokenProvider: { tokenStore.currentToken })
        let httpClient = HTTPClient(transport: transport)
        return ConvexService(client: httpClient)
    }
}

private final class UITestSessionStore: SessionStoring {
    private(set) var state: AuthState
    var onStateChange: ((AuthState) -> Void)?
    private(set) var authMessage: String?

    init(userId: String) {
        self.state = .authenticated(UserSession(userId: userId, establishedAt: Date()))
        self.authMessage = nil
    }

    func bootstrapSession() {}

    func signIn(email: String, password: String) {}

    func signOut() {
        state = .unauthenticated
        onStateChange?(state)
    }

    func handleProtectedRequestFailure(_ error: Error) {}
}
