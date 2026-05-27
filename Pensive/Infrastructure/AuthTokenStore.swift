import Foundation

protocol AuthTokenStoring: AnyObject {
    var currentToken: String? { get }
    var currentRefreshToken: String? { get }
    func setTokens(accessToken: String?, refreshToken: String?)
}

final class AuthTokenStore: AuthTokenStoring {
    private let defaults: UserDefaults
    private let accessKey = "pensive.auth.token"
    private let refreshKey = "pensive.auth.refreshToken"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentToken: String? {
        defaults.string(forKey: accessKey)
    }

    var currentRefreshToken: String? {
        defaults.string(forKey: refreshKey)
    }

    func setTokens(accessToken: String?, refreshToken: String?) {
        if let accessToken, !accessToken.isEmpty {
            defaults.set(accessToken, forKey: accessKey)
        } else {
            defaults.removeObject(forKey: accessKey)
        }

        if let refreshToken, !refreshToken.isEmpty {
            defaults.set(refreshToken, forKey: refreshKey)
        } else {
            defaults.removeObject(forKey: refreshKey)
        }
    }
}
