import Foundation

struct AppContainer {
    let environment: AppEnvironment
    let sessionStore: SessionStore

    static func bootstrap(bundle: Bundle = .main) -> AppContainer {
        let env = AppEnvironment.load(from: bundle)
        let api = AppContainer.makeAPI(environment: env)
        return AppContainer(environment: env, sessionStore: SessionStore(authAPI: api.auth))
    }

    private static func makeAPI(environment: AppEnvironment) -> ConvexAPI {
        let base = URL(string: environment.convexHTTPActionBaseURL) ?? URL(string: environment.convexBaseURL)!
        let transport = URLSessionConvexTransport(baseURL: base, authTokenProvider: { nil })
        let httpClient = HTTPClient(transport: transport)
        return ConvexService(client: httpClient)
    }
}
